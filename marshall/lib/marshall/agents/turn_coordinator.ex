defmodule Marshall.Agents.TurnCoordinator do
  @moduledoc "Durable per-thread turn claims and ordered terminal events."
  alias Marshall.Agents.{AuditEvent, Event, Root, Thread, Turn}
  alias Marshall.Compute.{Ledger, VirtualMachine}
  require Marshall.Events

  # @cc [owner:ghuntley,label:concurrency;recovery] agent-one-active-turn
  # Claims MUST serialize on the thread row and recheck active_turn_id after
  # locking it. A queued turn MUST wait for a physically running VM. Independent
  # child threads may claim concurrently; no process-local queue is authority.
  @spec claim_next() :: {:ok, Turn.t() | nil} | {:error, term()}
  def claim_next do
    Ledger.transaction(fn ->
      %{rows: rows} =
        Ecto.Adapters.SQL.query!(
          Marshall.Repo,
          """
          SELECT t.id
          FROM agent_turns AS t
          JOIN agent_threads AS th ON th.id = t.thread_id
          JOIN agent_roots AS r ON r.id = th.root_id
          JOIN compute_virtual_machines AS vm ON vm.id = r.vm_id
          WHERE t.status = 'queued' AND th.active_turn_id IS NULL
            AND vm.desired_state = 'running' AND vm.observed_state = 'running'
            AND vm.archived_at IS NULL
          ORDER BY CASE WHEN t.maintenance_kind = 'skill_operation' THEN 0 ELSE 1 END,
            t.inserted_at, t.id
          LIMIT 1 FOR UPDATE OF t SKIP LOCKED
          """,
          [],
          log: false
        )

      case rows do
        [[raw_id]] -> claim_locked!(Ecto.UUID.load!(raw_id))
        [] -> nil
      end
    end)
  end

  defp claim_locked!(turn_id) do
    turn = Ledger.lock!(Turn, turn_id)
    thread = Ledger.lock!(Thread, turn.thread_id)

    if turn.status == :queued and thread.active_turn_id == nil do
      [root] = Ledger.read!(Root, id: thread.root_id)
      [vm] = Ledger.read!(VirtualMachine, id: root.vm_id)
      actor = Marshall.Accounts.Security.current(turn.actor_id)

      if match?(%Marshall.Accounts.User{deleted_at: nil, active: true}, actor) and
           Marshall.Access.Authorization.allowed?(vm, actor, "write") do
        start_locked!(turn, thread, root)
      else
        reject_revoked!(turn, thread, root)
        nil
      end
    end
  end

  defp start_locked!(turn, thread, root) do
    now = Ledger.now()
    turn = Ledger.update!(turn, :transition, %{status: :running, started_at: now})

    Ledger.update!(thread, :advance, %{
      active_turn_id: turn.id,
      next_event_sequence: thread.next_event_sequence + 1
    })

    Ledger.create!(Event, :append, %{
      thread_id: thread.id,
      turn_id: turn.id,
      sequence: thread.next_event_sequence,
      kind: :turn_started,
      body: %{}
    })

    Ledger.create!(AuditEvent, :record, %{
      vm_id: root.vm_id,
      thread_id: thread.id,
      turn_id: turn.id,
      kind: :turn_started,
      target_id: turn.id,
      outcome: :accepted
    })

    Ledger.after_commit(fn ->
      Marshall.Events.emit("agent.turn_started",
        vm_id: root.vm_id,
        thread_id: thread.id,
        turn_id: turn.id
      )
    end)

    turn
  end

  defp reject_revoked!(turn, thread, root) do
    fail_queued!(turn, thread, root, :access_revoked)
  end

  # @cc [owner:ghuntley,label:recovery] agent-queued-machine-unavailable
  # A prompt queued before physical VM deletion MUST become terminal with an
  # explicit unavailable event. Retained thread history remains readable.
  @spec reap_unavailable() :: :ok
  def reap_unavailable do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        Marshall.Repo,
        """
        SELECT t.id FROM agent_turns AS t
        JOIN agent_threads AS th ON th.id = t.thread_id
        JOIN agent_roots AS r ON r.id = th.root_id
        LEFT JOIN compute_virtual_machines AS vm ON vm.id = r.vm_id
        WHERE t.status = 'queued' AND
          (vm.id IS NULL OR vm.archived_at IS NOT NULL OR vm.desired_state = 'deleted')
        ORDER BY t.inserted_at, t.id LIMIT 128
        """,
        [],
        log: false
      )

    Enum.each(rows, fn [raw_id] -> reap_one(Ecto.UUID.load!(raw_id)) end)
    :ok
  end

  defp reap_one(id) do
    Ledger.transaction(fn ->
      turn = Ledger.lock!(Turn, id)

      if turn && turn.status == :queued do
        thread = Ledger.lock!(Thread, turn.thread_id)
        [root] = Ledger.read!(Root, id: thread.root_id)

        case Ledger.read!(VirtualMachine, id: root.vm_id) do
          [vm] when vm.archived_at == nil and vm.desired_state != :deleted -> :ok
          _ -> fail_queued!(turn, thread, root, :machine_unavailable)
        end
      end
    end)
  end

  defp fail_queued!(turn, thread, root, reason) do
    Ledger.update!(turn, :transition, %{
      status: :failed,
      finished_at: Ledger.now(),
      failure_reason: reason
    })

    Ledger.create!(Event, :append, %{
      thread_id: thread.id,
      turn_id: turn.id,
      sequence: thread.next_event_sequence,
      kind: :turn_failed,
      body: %{"reason" => Atom.to_string(reason)}
    })

    Ledger.update!(thread, :advance, %{next_event_sequence: thread.next_event_sequence + 1})

    Ledger.create!(AuditEvent, :record, %{
      vm_id: root.vm_id,
      thread_id: thread.id,
      turn_id: turn.id,
      kind: :turn_finished,
      target_id: turn.id,
      outcome: :failed
    })

    Marshall.Threads.FeedAppendJob.enqueue!(thread, turn)

    Ledger.after_commit(fn ->
      Marshall.Events.emit("agent.turn_finished",
        vm_id: root.vm_id,
        thread_id: thread.id,
        turn_id: turn.id,
        outcome: :failed
      )
    end)
  end

  # @cc [owner:ghuntley,label:concurrency;security] agent-terminal-turn-once
  # Only a running turn that still owns its thread may append a terminal result.
  # Completion and its audit receipt MUST commit together; result text MUST
  # remain in the authorized event table, never diagnostic metadata.
  @spec finish(String.t(), :completed | :failed, String.t() | atom()) ::
          {:ok, Turn.t()} | {:error, term()}
  def finish(turn_id, :completed, text) when is_binary(text) and byte_size(text) <= 1_048_576 do
    terminate(turn_id, :completed, %{"text" => text}, nil)
  end

  def finish(turn_id, :failed, reason)
      when reason in [
             :machine_unavailable,
             :wake_failed,
             :executor_lost,
             :provider_failed,
             :capability_denied,
             :tool_uncertain,
             :access_revoked,
             :context_too_large,
             :context_changed,
             :context_unavailable,
             :context_limit_exceeded,
             :compaction_no_progress,
             :nothing_to_compact,
             :invalid_compaction_response,
             :native_compaction_unavailable,
             :invalid_context,
             :skill_failed,
             :skill_ambiguous,
             :skill_unavailable
           ] do
    terminate(turn_id, :failed, %{"reason" => Atom.to_string(reason)}, reason)
  end

  def finish(_, _, _), do: {:error, :invalid_result}

  defp terminate(turn_id, status, body, reason) do
    Ledger.transaction(fn ->
      turn = Ledger.lock!(Turn, turn_id) || Ledger.rollback(:not_found)
      thread = Ledger.lock!(Thread, turn.thread_id) || Ledger.rollback(:not_found)

      unless turn.status == :running and thread.active_turn_id == turn.id,
        do: Ledger.rollback(:stale_turn)

      cancellation =
        if reason in [:access_revoked, :machine_unavailable], do: reason, else: :turn_finished

      Marshall.Agents.Planning.cancel_pending_locked!(thread.id, cancellation)
      thread = Ledger.lock!(Thread, thread.id)

      [root] = Ledger.read!(Root, id: thread.root_id)
      now = Ledger.now()

      turn =
        Ledger.update!(turn, :transition, %{
          status: status,
          finished_at: now,
          failure_reason: reason
        })

      event_kind =
        cond do
          status != :completed -> :turn_failed
          turn.maintenance_kind not in [nil, :subscription_notification] -> :maintenance_finished
          true -> :assistant
        end

      Ledger.create!(Event, :append, %{
        thread_id: thread.id,
        turn_id: turn.id,
        sequence: thread.next_event_sequence,
        kind: event_kind,
        body: body
      })

      thread =
        Ledger.update!(thread, :advance, %{
          active_turn_id: nil,
          next_event_sequence: thread.next_event_sequence + 1
        })

      if status == :completed and turn.maintenance_kind == nil do
        Marshall.Agents.Planning.record_proposal_locked!(thread, turn, body["text"])
      end

      Ledger.create!(AuditEvent, :record, %{
        vm_id: root.vm_id,
        thread_id: thread.id,
        turn_id: turn.id,
        kind: :turn_finished,
        target_id: turn.id,
        outcome: status
      })

      Marshall.Threads.FeedAppendJob.enqueue!(thread, turn)

      Ledger.after_commit(fn ->
        Marshall.Events.emit("agent.turn_finished",
          vm_id: root.vm_id,
          thread_id: thread.id,
          turn_id: turn.id,
          outcome: status
        )
      end)

      turn
    end)
  end
end
