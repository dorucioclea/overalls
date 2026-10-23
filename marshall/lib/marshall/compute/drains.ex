defmodule Marshall.Compute.Drains do
  @moduledoc "Operator maintenance coordinated with admission, lifecycle and physical outcomes."
  alias Marshall.Authorization.SystemActor
  alias Marshall.Operations.Privacy

  alias Marshall.Compute.{
    Credentials,
    Host,
    HostDrain,
    Ledger,
    Lifecycle,
    Operation,
    RelocationGuard,
    Reservation,
    StoragePool,
    VirtualMachine
  }

  require Ash.Query
  require Marshall.Events
  @batch_size 20

  # @cc [owner:ghuntley,label:concurrency] drains-request-atomicity
  # A new drain MUST atomically disable admission, record its host/operator-bound
  # request and queue advancement under the host lock. An identical request ID
  # retry MUST reuse its result; changed meaning MUST fail without side effects.
  # An unfinished relocation touching either endpoint MUST reject a new drain.

  # @cc [owner:ghuntley,label:observability] drains-log-after-outer-commit
  # Drain transition diagnostics MUST be deferred until the owning transaction
  # commits; a rollback MUST NOT report a requested, confirmed or closed drain.
  @spec request(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def request(host_id, id, operator_reference) do
    Privacy.run(fn ->
      result =
        Ledger.transaction(fn ->
          unless OverallsProtocol.uuid?(host_id) and OverallsProtocol.uuid?(id) and
                   is_binary(operator_reference) and
                   Regex.match?(~r/\A[a-zA-Z0-9][a-zA-Z0-9_.:@\/-]{0,127}\z/, operator_reference),
                 do: Ledger.rollback(:invalid_arguments)

          Ecto.Adapters.SQL.query!(
            Marshall.Repo,
            "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
            ["drain:" <> id],
            log: false
          )

          # Draining disables the host for guest-credential readers; fence them out.
          host = Ledger.fence_host!(host_id) || Ledger.rollback(:unknown_host)

          {drain, pending} =
            case Ledger.read!(HostDrain, id: id) do
              [drain] ->
                unless drain.host_id == host_id and drain.operator_reference == operator_reference,
                  do: Ledger.rollback(:idempotency_conflict)

                {drain, []}

              [] ->
                if RelocationGuard.host_busy?(host.id),
                  do: Ledger.rollback(:relocation_in_progress)

                unless host.maintenance_mode == :normal, do: Ledger.rollback(:host_in_maintenance)
                Ledger.update!(host, :maintenance, %{maintenance_mode: :draining, enabled: false})

                drain =
                  Ledger.create!(HostDrain, :request, %{
                    id: id,
                    host_id: host_id,
                    operator_reference: operator_reference
                  })

                {drain, [{:requested, drain}]}
            end

          {snapshot(drain, Ledger.lock!(Host, host_id)), pending}
        end)

      case result do
        {:ok, {snapshot, pending}} ->
          emit_pending(pending)
          {:ok, snapshot}

        error ->
          error
      end
    end)
  end

  # @cc [owner:ghuntley,label:recovery] drains-bounded-durable-batches
  # Each advancement transaction MUST stop at most twenty running VM intents,
  # preserve existing stop/delete intent and commit any required continuation with
  # the batch. Duplicate workers MUST reread under the host lock before advancing.
  @spec advance(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def advance(id) do
    result =
      Ledger.transaction(fn ->
        {host, drain} = lock!(id)

        if drain.status == :draining and host.maintenance_mode == :draining do
          vms =
            VirtualMachine
            |> Ash.Query.filter(host_id == ^host.id and desired_state == :running)
            |> Ash.Query.sort(:id)
            |> Ash.Query.limit(@batch_size)
            |> Ash.Query.lock(:for_update)
            |> Ash.read!(actor: SystemActor.compute())

          Enum.each(vms, &Lifecycle.stop_for_drain_locked!(&1, drain))
          confirmed = confirm_locked!(host)

          if length(vms) == @batch_size do
            AshOban.run_trigger(drain, :advance,
              action_arguments: %{continuation: Ash.UUID.generate()},
              actor: SystemActor.compute()
            )
          end

          {length(vms), confirmed}
        else
          {0, []}
        end
      end)

    case result do
      {:ok, {count, confirmed}} ->
        emit_confirmed(confirmed)
        {:ok, count}

      error ->
        error
    end
  end

  # @cc [owner:ghuntley,label:capacity] drains-physical-quiescence
  # Drain confirmation MUST require a fresh v4 execution-ready host, every live VM
  # both desired and observed stopped, and no compute-held reservation. Requests,
  # disconnection or elapsed time MUST NOT establish quiescence. Unfinished
  # relocation, even after stream-slot release, MUST prevent confirmation.
  @doc "Caller holds the host lock; refresh the host after ingesting a new report."
  @spec confirm_locked!(Host.t()) :: [HostDrain.t()]
  def confirm_locked!(%{maintenance_mode: :draining} = host) do
    open =
      HostDrain
      |> Ash.Query.filter(host_id == ^host.id and is_nil(closed_at))
      |> Ash.read!(actor: SystemActor.compute())

    case open do
      [%{status: :draining} = drain] ->
        if quiescent?(host) do
          [Ledger.update!(drain, :confirm, %{quiesced_at: Ledger.now()})]
        else
          []
        end

      _ ->
        []
    end
  end

  def confirm_locked!(_), do: []

  @doc "Emit confirmation diagnostics for drains confirmed by a committed caller transaction."
  @spec emit_confirmed([HostDrain.t()]) :: :ok
  def emit_confirmed(drains) do
    unless Marshall.Repo.in_transaction?() do
      Enum.each(drains, fn drain ->
        Marshall.Events.emit("host.drain_confirmed",
          host_id: drain.host_id,
          drain_id: drain.id,
          operation_status: drain.status
        )
      end)
    end

    :ok
  end

  @spec status(String.t()) :: {:ok, map()} | {:error, term()}
  def status(id) do
    Privacy.run(fn ->
      Ledger.transaction(fn ->
        {host, drain} = lock!(id)
        snapshot(drain, host)
      end)
    end)
  end

  # @cc [owner:ghuntley,label:product] drains-resume-is-admission-only
  # Resume MUST revalidate current quiescence before restoring admission; an old
  # confirmation timestamp is insufficient. It MUST NOT restart retained guests.
  @spec resume(String.t()) :: {:ok, map()} | {:error, term()}
  def resume(id), do: close(id, :resumed)

  # @cc [owner:ghuntley,label:recovery] drains-empty-permanent-retirement
  # Retirement MUST require current quiescence, no live VM/held allocation/active
  # address, and fresh empty physical pool allocations. It MUST revoke authority
  # and permanently disable admission while retaining host identity/history.
  @spec retire(String.t()) :: {:ok, map()} | {:error, term()}
  def retire(id), do: close(id, :retired)

  defp close(id, target) do
    Privacy.run(fn ->
      result =
        Ledger.transaction(fn ->
          {host, drain} = lock!(id)

          if drain.status == target do
            {snapshot(drain, host), []}
          else
            unless drain.status == :drained and host.maintenance_mode == :draining and
                     quiescent?(host),
                   do: Ledger.rollback(:host_not_quiescent)

            host =
              case target do
                :resumed ->
                  Ledger.update!(host, :maintenance, %{maintenance_mode: :normal, enabled: true})

                :retired ->
                  unless empty_for_retirement?(host),
                    do: Ledger.rollback(:retained_host_resources)

                  {:ok, :ok} = Credentials.revoke(host.id)

                  Ledger.update!(host, :maintenance, %{maintenance_mode: :retired, enabled: false})
              end

            action = if target == :resumed, do: :resume, else: :retire
            drain = Ledger.update!(drain, action, %{closed_at: Ledger.now()})
            {snapshot(drain, host), [{:closed, drain}]}
          end
        end)

      case result do
        {:ok, {snapshot, pending}} ->
          emit_pending(pending)
          {:ok, snapshot}

        error ->
          error
      end
    end)
  end

  defp lock!(id) do
    unless OverallsProtocol.uuid?(id), do: Ledger.rollback(:invalid_arguments)

    drain =
      case Ledger.read!(HostDrain, id: id) do
        [drain] -> drain
        [] -> Ledger.rollback(:unknown_drain)
      end

    # Retirement disables the host for guest-credential readers; fence them out.
    host = Ledger.fence_host!(drain.host_id)
    {host, Ledger.lock!(HostDrain, id)}
  end

  defp quiescent?(host) do
    ready?(host) and not RelocationGuard.host_busy?(host.id) and
      not present?(
        VirtualMachine
        |> Ash.Query.filter(
          host_id == ^host.id and
            (desired_state != :stopped or observed_state != :stopped)
        )
      ) and
      not present?(Reservation |> Ash.Query.filter(host_id == ^host.id and compute_held == true))
  end

  defp ready?(host),
    do:
      host.inventory["execution_ready"] == true and
        Marshall.Compute.HostLiveness.capacity_fresh?(host.reported_at, Ledger.now())

  defp empty_for_retirement?(host) do
    not present?(VirtualMachine |> Ash.Query.filter(host_id == ^host.id)) and
      not present?(
        Reservation
        |> Ash.Query.filter(
          host_id == ^host.id and
            (compute_held == true or disk_held == true)
        )
      ) and
      no_active_addresses?(host.id) and
      Enum.all?(Ledger.read!(StoragePool, host_id: host.id), fn pool ->
        Marshall.Compute.HostLiveness.capacity_fresh?(pool.reported_at, Ledger.now()) and
          pool.allocations == %{}
      end)
  end

  defp no_active_addresses?(host_id) do
    {:ok, binary_id} = Ecto.UUID.dump(host_id)

    %{rows: [[present]]} =
      Ecto.Adapters.SQL.query!(
        Marshall.Repo,
        """
        SELECT EXISTS(SELECT 1 FROM compute_network_addresses a
        JOIN compute_virtual_machines v ON v.id = a.vm_id
        JOIN compute_workload_placements p ON p.id = v.current_placement_id
        WHERE p.host_id = $1 AND a.archived_at IS NULL)
        """,
        [binary_id],
        log: false
      )

    not present
  end

  defp present?(query),
    do: query |> Ash.Query.limit(1) |> Ash.read!(actor: SystemActor.compute()) != []

  defp count(resource, filter),
    do: resource |> Ash.Query.filter(^filter) |> Ash.count!(actor: SystemActor.compute())

  defp snapshot(drain, host) do
    %{
      id: drain.id,
      host_id: host.id,
      status: to_string(drain.status),
      operator_reference: drain.operator_reference,
      host_mode: to_string(host.maintenance_mode),
      enabled: host.enabled,
      report_fresh: Marshall.Compute.HostLiveness.capacity_fresh?(host.reported_at, Ledger.now()),
      currently_quiescent: is_nil(drain.closed_at) and quiescent?(host),
      quiesced_at: timestamp(drain.quiesced_at),
      closed_at: timestamp(drain.closed_at),
      live_vms: count(VirtualMachine, host_id: host.id),
      compute_allocations: count(Reservation, host_id: host.id, compute_held: true),
      retained_disks: count(Reservation, host_id: host.id, disk_held: true),
      stop_requests: count(Operation, host_drain_id: drain.id)
    }
  end

  defp timestamp(nil), do: nil
  defp timestamp(value), do: DateTime.to_iso8601(value)

  defp emit_pending(events) do
    unless Marshall.Repo.in_transaction?() do
      Enum.each(events, fn
        {:requested, drain} ->
          Marshall.Events.emit("host.drain_requested",
            host_id: drain.host_id,
            drain_id: drain.id,
            operation_status: drain.status
          )

        {:closed, drain} ->
          Marshall.Events.emit("host.drain_closed",
            host_id: drain.host_id,
            drain_id: drain.id,
            operation_status: drain.status
          )
      end)
    end

    :ok
  end
end
