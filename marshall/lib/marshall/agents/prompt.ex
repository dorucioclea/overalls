defmodule Marshall.Agents.Prompt do
  @moduledoc "Authorized idempotent prompt admission and narrow automatic VM wake."
  use Ash.Resource.Actions.Implementation
  alias Marshall.Agents.{AuditEvent, Event, Root, Thread, Turn}
  alias Marshall.Compute.{Ledger, Lifecycle, VirtualMachine}
  alias Marshall.Authorization.SystemActor
  require Ash.Query
  require Marshall.Events

  # @cc [owner:ghuntley,label:security;concurrency] agent-prompt-wake-transaction
  # A prompt MUST check current VM write access under the VM lock and retain
  # durable wake demand. Capacity admission later takes host-before-VM locks.
  # One request key MUST create at most one turn and one durable wake identity.
  # Failure to append its audit receipt MUST roll back prompt admission.
  @impl true
  @spec run(Ash.ActionInput.t(), keyword(), map()) :: {:ok, map()} | {:error, term()}
  def run(input, _options, %{actor: %Marshall.Accounts.User{} = actor}) do
    %{thread_id: thread_id, prompt: prompt, request_key: key} = input.arguments

    with %Thread{} = thread <- get(Thread, thread_id),
         %Root{} = root <- get(Root, thread.root_id) do
      Ledger.transaction(
        fn -> admit!(root, thread, actor, prompt, key, input.arguments) end,
        actor
      )
    else
      _ -> {:error, :machine_unavailable}
    end
  end

  def run(_, _, _), do: {:error, :forbidden}

  # @cc [owner:ghuntley,label:product;concurrency] agent-maintenance-no-fake-prompt
  # Maintenance MUST use the same durable authorized turn queue as conversation
  # work, with its own request identity and no fabricated user prompt event.
  @spec maintenance(String.t(), atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def maintenance(thread_id, kind, metadata, options)
      when kind in [
             :compact_context,
             :reload_context,
             :skill_operation,
             :subscription_notification
           ] and is_map(metadata) do
    with true <- valid_maintenance_metadata?(kind, metadata),
         %Marshall.Accounts.User{} = actor <- Keyword.get(options, :actor),
         key when is_binary(key) and byte_size(key) in 1..128 <-
           Keyword.get(options, :request_key),
         %Thread{} = thread <- get(Thread, thread_id),
         %Root{} = root <- get(Root, thread.root_id) do
      Ledger.transaction(
        fn ->
          admit!(root, thread, actor, nil, key, %{
            maintenance_kind: kind,
            maintenance_metadata:
              Map.new(metadata, fn {key, value} -> {to_string(key), value} end)
          })
        end,
        actor
      )
    else
      _ -> {:error, :invalid_request}
    end
  end

  def maintenance(_, _, _, _), do: {:error, :invalid_request}

  @spec valid_maintenance_metadata?(atom(), map()) :: boolean()
  defp valid_maintenance_metadata?(:subscription_notification, metadata) do
    Enum.sort(Map.keys(metadata)) == ~w(kind notification_id sequence thread_id) and
      metadata["kind"] in ["machine_purged", "turn_finished"] and
      OverallsProtocol.uuid?(metadata["notification_id"]) and
      OverallsProtocol.uuid?(metadata["thread_id"]) and
      is_integer(metadata["sequence"]) and metadata["sequence"] > 0
  end

  defp valid_maintenance_metadata?(_, _), do: true

  defp admit!(root, thread, actor, prompt, key, options) do
    {prompt, prompt_findings} =
      case prompt do
        value when is_binary(value) ->
          result = Marshall.Redaction.Scanner.redact(value)
          {result.value, result.findings}

        nil ->
          {nil, []}
      end

    vm =
      case Ledger.read!(VirtualMachine, id: root.vm_id) do
        [vm] -> vm
        _ -> Ledger.rollback(:machine_unavailable)
      end

    Marshall.Access.Authorization.require!(vm, actor, "write")
    require_thread_access!(root, actor)
    if vm.desired_state == :deleted, do: Ledger.rollback(:machine_unavailable)

    existing =
      Ledger.read!(Turn, thread_id: thread.id, actor_id: actor.id, request_key: key)

    if existing != [] do
      [%Turn{} = turn] = existing

      if turn.prompt == prompt and turn.maintenance_kind == Map.get(options, :maintenance_kind) and
           turn.maintenance_metadata == Map.get(options, :maintenance_metadata, %{}) and
           same_requested_context?(turn, options),
         do: %{turn_id: turn.id, status: turn.status},
         else: Ledger.rollback(:idempotency_conflict)
    else
      # Wake retains the VM lock until this outer transaction commits.
      wake =
        case Lifecycle.wake_for_prompt(root.vm_id, actor, "agent:" <> key) do
          {:ok, result} ->
            result

          {:error, %Marshall.Compute.Error{reason: :vm_deleted}} ->
            Ledger.rollback(:machine_unavailable)

          {:error, %Marshall.Compute.Error{reason: reason}} ->
            Ledger.rollback(reason)

          _ ->
            Ledger.rollback(:wake_failed)
        end

      locked = Ledger.lock!(Thread, thread.id) || Ledger.rollback(:machine_unavailable)
      # Admission snapshots remain immutable even when later queued prompts use
      # another selection. A collaborator never supplies the configuration owner.
      collaboration_mode = Map.get(options, :collaboration_mode) || locked.collaboration_mode
      skills = Map.get(options, :selected_skill_ids) || locked.selected_skills
      directory = Map.get(options, :working_directory) || locked.working_directory

      if collaboration_mode != locked.collaboration_mode and
           (locked.active_turn_id != nil or
              Ledger.read!(Turn, thread_id: locked.id, status: :queued) != []),
         do: Ledger.rollback(:thread_busy)

      unless collaboration_mode in [:work, :plan] and is_list(skills) and length(skills) <= 32 and
               Enum.all?(skills, &(is_binary(&1) and byte_size(&1) in 1..4096)),
             do: Ledger.rollback(:invalid_request)

      Ledger.update!(locked, :set_context, %{
        collaboration_mode: collaboration_mode,
        selected_skills: skills,
        working_directory: directory
      })

      next = next_ordinal!(locked.id)

      turn =
        Ledger.create!(Turn, :enqueue, %{
          thread_id: locked.id,
          actor_id: actor.id,
          request_key: key,
          ordinal: next,
          prompt: prompt,
          mode: locked.mode,
          collaboration_mode: collaboration_mode,
          selected_skills: skills,
          working_directory: directory,
          configuration_owner_id: root.owner_id,
          maintenance_kind: Map.get(options, :maintenance_kind),
          maintenance_metadata: Map.get(options, :maintenance_metadata, %{}),
          redaction_profile: Marshall.Redaction.Scanner.profile_digest()
        })

      if prompt do
        Ledger.create!(Event, :append, %{
          thread_id: locked.id,
          turn_id: turn.id,
          sequence: locked.next_event_sequence,
          kind: :prompt,
          body: %{
            "prompt" => prompt,
            "redaction_findings" => prompt_findings,
            "redaction_profile" => Marshall.Redaction.Scanner.profile_digest()
          }
        })

        Ledger.update!(locked, :advance, %{next_event_sequence: locked.next_event_sequence + 1})
      end

      if turn.maintenance_kind == :subscription_notification do
        Ledger.create!(Event, :append, %{
          thread_id: locked.id,
          turn_id: turn.id,
          sequence: locked.next_event_sequence,
          kind: :subscription_notification,
          body: turn.maintenance_metadata
        })

        Ledger.update!(locked, :advance, %{next_event_sequence: locked.next_event_sequence + 1})
      end

      Ledger.create!(AuditEvent, :record, %{
        vm_id: root.vm_id,
        thread_id: locked.id,
        turn_id: turn.id,
        actor_id: actor.id,
        kind: if(prompt, do: :prompt_admitted, else: :maintenance_admitted),
        target_id: turn.id,
        outcome: :accepted
      })

      if match?(%Marshall.Compute.WakeRequest{}, wake) do
        Ledger.create!(AuditEvent, :record, %{
          vm_id: root.vm_id,
          thread_id: locked.id,
          turn_id: turn.id,
          actor_id: actor.id,
          kind: :wake_requested,
          target_id: wake.id,
          outcome: :accepted
        })
      end

      Ledger.after_commit(fn ->
        Marshall.Events.emit("agent.prompt_admitted",
          vm_id: root.vm_id,
          thread_id: locked.id,
          turn_id: turn.id
        )
      end)

      %{turn_id: turn.id, status: :queued}
    end
  end

  @spec same_requested_context?(Turn.t(), map()) :: boolean()
  defp same_requested_context?(turn, options) do
    Enum.all?(
      [
        {:collaboration_mode, :collaboration_mode},
        {:selected_skill_ids, :selected_skills},
        {:working_directory, :working_directory}
      ],
      fn {key, field} ->
        is_nil(Map.get(options, key)) or Map.get(options, key) == Map.get(turn, field)
      end
    )
  end

  @spec require_thread_access!(Root.t(), Marshall.Accounts.User.t()) :: :ok
  defp require_thread_access!(root, actor) do
    case Ledger.read!(Marshall.Threads.Thread, agent_root_id: root.id) do
      [] -> :ok
      [task] -> Marshall.Threads.Authorization.require!(task, actor, "write")
      _ -> Ledger.rollback(:forbidden)
    end
  end

  defp get(resource, id) do
    resource
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one(actor: SystemActor.compute())
    |> case do
      {:ok, value} -> value
      _ -> nil
    end
  end

  defp next_ordinal!(thread_id) do
    %{rows: [[ordinal]]} =
      Ecto.Adapters.SQL.query!(
        Marshall.Repo,
        "SELECT COALESCE(MAX(ordinal), 0) + 1 FROM agent_turns WHERE thread_id = $1",
        [Ecto.UUID.dump!(thread_id)],
        log: false
      )

    ordinal
  end
end
