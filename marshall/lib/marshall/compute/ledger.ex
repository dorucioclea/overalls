defmodule Marshall.Compute.Ledger do
  @moduledoc "Trusted coordinator database primitives; never expose these as remote actions."
  require Ash.Query
  alias Marshall.Authorization.SystemActor
  alias Marshall.Repo

  @type audit_actor_kind :: :user | :system | :provisioner | :operator
  @type audit_actor ::
          Marshall.Accounts.User.t()
          | {audit_actor_kind(), Ash.UUID.t() | nil}
          | audit_actor_kind()
          | :inherit

  # @cc [owner:ghuntley,label:security;observability] ledger-audit-actor-propagation
  # PaperTrail writes MUST retain the initiating actor classification and safe
  # identifier independently of the SystemActor used for internal authorization.
  # Nested transactions inherit the outer attribution unless explicitly replaced;
  # historical versions remain nullable and MUST NOT be assigned guessed actors.
  @spec transaction((-> term()), audit_actor()) ::
          {:ok, term()} | {:error, term()}
  def transaction(fun, actor \\ :inherit) do
    previous = Process.get({__MODULE__, :audit_actor})
    Process.put({__MODULE__, :audit_actor}, normalize_actor(actor, previous))

    try do
      commit_scope(fn -> transact(fun) end)
    after
      if previous,
        do: Process.put({__MODULE__, :audit_actor}, previous),
        else: Process.delete({__MODULE__, :audit_actor})
    end
  end

  @doc "Run a public mutation and flush its callbacks only after the outer successful commit."
  @spec commit_scope((-> result)) :: result when result: term()
  def commit_scope(fun) when is_function(fun, 0) do
    depth = Process.get({__MODULE__, :transaction_depth}, 0)
    outer? = depth == 0
    previous_callbacks = Process.get({__MODULE__, :after_commit}, [])

    if outer?, do: Process.put({__MODULE__, :after_commit}, [])
    Process.put({__MODULE__, :transaction_depth}, depth + 1)

    try do
      result = fun.()

      if outer? and match?({:ok, _}, result) and not Repo.in_transaction?() do
        {__MODULE__, :after_commit}
        |> Process.get([])
        |> Enum.reverse()
        |> Enum.each(& &1.())
      end

      if not outer? and not match?({:ok, _}, result),
        do: Process.put({__MODULE__, :after_commit}, previous_callbacks)

      result
    catch
      kind, reason ->
        if not outer?, do: Process.put({__MODULE__, :after_commit}, previous_callbacks)
        :erlang.raise(kind, reason, __STACKTRACE__)
    after
      if outer?,
        do: Process.delete({__MODULE__, :after_commit}),
        else: Process.put({__MODULE__, :transaction_depth}, depth)

      if outer?, do: Process.delete({__MODULE__, :transaction_depth})
    end
  end

  # @cc [owner:ghuntley,label:observability;recovery] ledger-after-outer-commit
  # Transactional outcome callbacks MUST run once only after the outermost
  # Ledger commit scope succeeds outside a database transaction. Nested success
  # followed by outer rollback, and nested rollback followed by outer recovery,
  # MUST discard callbacks belonging to the rolled-back work.
  # Deferred callbacks MUST retain their registering local span without copying
  # baggage, and restore the committing process's previous context afterward.
  @spec after_commit((-> term())) :: :ok
  def after_commit(callback) when is_function(callback, 0) do
    callback = Overalls.Diagnostics.Context.wrap(callback)

    case Process.get({__MODULE__, :transaction_depth}, 0) do
      depth when depth > 0 ->
        Process.put(
          {__MODULE__, :after_commit},
          [callback | Process.get({__MODULE__, :after_commit}, [])]
        )

        :ok

      _ ->
        raise ArgumentError, "after_commit callback requires a Ledger commit scope"
    end
  end

  defp transact(fun) do
    case Ash.transact(Marshall.Compute.Host, fun) do
      {:error, %Marshall.Compute.Error{reason: reason}} ->
        {:error, reason}

      {:error, %Ash.Error.Invalid{errors: [%Marshall.Compute.Error{reason: reason}]}} ->
        {:error, reason}

      result ->
        result
    end
  end

  @spec rollback(atom()) :: no_return()
  def rollback(reason), do: Repo.rollback(Marshall.Compute.Error.exception(reason: reason))

  @spec read!(module(), keyword()) :: [Ash.Resource.Record.t()]
  def read!(resource, filter \\ []) do
    resource |> Ash.Query.filter(^filter) |> Ash.read!(actor: SystemActor.compute())
  end

  @spec history!(module(), keyword()) :: [Ash.Resource.Record.t()]
  def history!(resource, filter) do
    resource
    |> Ash.Query.for_read(:history, %{}, actor: SystemActor.compute())
    |> Ash.Query.filter(^filter)
    |> Ash.read!()
  end

  @spec archive!(Ash.Resource.Record.t(), atom()) :: :ok
  def archive!(record, action) do
    record
    |> Ash.Changeset.for_destroy(action, %{},
      actor: SystemActor.compute(),
      context: audit_context()
    )
    |> Ash.destroy!()

    :ok
  end

  # @cc [owner:ghuntley,label:concurrency] ledger-lock-transaction-lifetime
  # Callers using lock! for serialization MUST keep the surrounding transaction
  # open through every dependent read and mutation; a returned record alone does
  # not preserve a lock after that transaction ends.
  @spec lock!(module(), String.t()) :: Ash.Resource.Record.t() | nil
  def lock!(resource, id) do
    resource
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(lock_mode(resource))
    |> Ash.read_one!(actor: SystemActor.compute())
  end

  # @cc [owner:ghuntley,label:concurrency;reliability] ledger-host-lock-no-key
  # Host rows MUST be locked FOR NO KEY UPDATE, never FOR UPDATE. Every model
  # call, operation and placement row references compute_hosts, and their
  # foreign-key FOR KEY SHARE checks MUST NOT queue behind (or deadlock with) the
  # host lock that serializes exchanges, rotation and placement. Host keys are
  # immutable, so the weaker mode still serializes every host mutation.
  # @cc [owner:ghuntley,label:concurrency;security] ledger-host-guest-fence
  # Guest-credential authentication (inference, Galileo, Peach) MUST take
  # share_host!/1 (FOR KEY SHARE), which never queues behind host exchanges.
  # Every change those readers depend on (host enabled or maintenance state and
  # their credential issue, rotation or revocation) MUST take fence_host!/1
  # (FOR UPDATE), which waits for and excludes every in-flight reader.
  @doc "Locks a host row for guest-credential authentication."
  @spec share_host!(String.t()) :: Ash.Resource.Record.t() | nil
  def share_host!(id), do: lock_host!(id, "FOR KEY SHARE")

  @doc "Locks a host row exclusively, excluding share_host!/1 readers."
  @spec fence_host!(String.t()) :: Ash.Resource.Record.t() | nil
  def fence_host!(id), do: lock_host!(id, :for_update)

  @spec lock_host!(String.t(), :for_update | String.t()) :: Ash.Resource.Record.t() | nil
  defp lock_host!(id, mode) do
    Marshall.Compute.Host
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(mode)
    |> Ash.read_one!(actor: SystemActor.compute())
  end

  @doc "The row lock mode `lock!/2` and `lock_history!/2` take for a resource."
  @spec lock_mode(module()) :: :for_update | String.t()
  def lock_mode(Marshall.Compute.Host), do: "FOR NO KEY UPDATE"
  def lock_mode(_resource), do: :for_update

  # @cc [owner:ghuntley,label:concurrency;recovery] retained-receipts-lock-archived-rows
  # lock_history!/2 requires the affected host lock and an enclosing transaction.
  # It MUST lock the retained row even after archival, so late physical receipts
  # serialize with other endpoint facts. The resource must expose :history.
  # Finding an archived row MUST NOT authorize new lifecycle or transfer commands;
  # active command selection retains its ordinary read and authority checks.
  @spec lock_history!(module(), String.t()) :: Ash.Resource.Record.t() | nil
  def lock_history!(resource, id) do
    resource
    |> Ash.Query.for_read(:history, %{}, actor: SystemActor.compute())
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(lock_mode(resource))
    |> Ash.read_one!(actor: SystemActor.compute())
  end

  @spec create!(module(), atom(), map()) :: Ash.Resource.Record.t()
  def create!(resource, action, attributes) do
    resource
    |> Ash.Changeset.for_create(action, attributes,
      actor: SystemActor.compute(),
      context: audit_context()
    )
    |> Ash.create!()
  end

  @spec update!(Ash.Resource.Record.t(), atom(), map()) :: Ash.Resource.Record.t()
  def update!(record, action, attributes) do
    record
    |> Ash.Changeset.for_update(action, attributes,
      actor: SystemActor.compute(),
      context: audit_context()
    )
    |> Ash.update!()
  end

  defp audit_context do
    %{kind: kind, id: id} = Process.get({__MODULE__, :audit_actor}, %{kind: :system, id: nil})

    %{
      lifecycle_requester_id: if(kind == :user, do: id),
      paper_trail_metadata: %{actor_kind: kind, actor_id: id}
    }
  end

  defp normalize_actor(:inherit, nil), do: %{kind: :system, id: nil}
  defp normalize_actor(:inherit, previous), do: previous
  defp normalize_actor(%Marshall.Accounts.User{id: id}, _previous), do: %{kind: :user, id: id}

  defp normalize_actor({kind, nil}, _previous)
       when kind in [:user, :system, :provisioner, :operator],
       do: %{kind: kind, id: nil}

  defp normalize_actor({kind, id}, _previous)
       when kind in [:user, :system, :provisioner, :operator] and is_binary(id) do
    if OverallsProtocol.uuid?(id),
      do: %{kind: kind, id: id},
      else: raise(ArgumentError, "invalid audit actor identifier")
  end

  defp normalize_actor(kind, _previous)
       when kind in [:user, :system, :provisioner, :operator],
       do: %{kind: kind, id: nil}

  defp normalize_actor(actor, _previous),
    do: raise(ArgumentError, "invalid audit actor: #{inspect(actor)}")

  # @cc [owner:ghuntley,label:recovery] ledger-intent-named-action
  # Intent dispatch MUST use the resource's named transition; deleted intent has
  # no start/stop path. Callers retain host/VM locks and generation validation.
  @spec intent!(Marshall.Compute.VirtualMachine.t(), map()) :: Marshall.Compute.VirtualMachine.t()
  def intent!(vm, attributes) do
    {state, attributes} = Map.pop(attributes, :desired_state, vm.desired_state)

    action =
      case state do
        :running -> :request_start
        :stopped -> :request_stop
        :paused -> :request_pause
        :deleted -> :request_delete
      end

    update!(vm, action, attributes)
  end

  # @cc [owner:ghuntley,label:concurrency] ledger-shared-clock
  # Coordination deadlines MUST use the current database clock, not a node-local
  # clock or the transaction-start timestamp retained while waiting for locks.
  @spec now() :: DateTime.t()
  def now do
    %{rows: [[now]]} = Ecto.Adapters.SQL.query!(Repo, "SELECT clock_timestamp()", [], log: false)
    now
  end
end
