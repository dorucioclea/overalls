defmodule Marshall.Agents.ServerToolReconciler do
  @moduledoc "Re-enqueues server-tool commands whose job was lost and expires stuck claims."
  use Oban.Worker, queue: :maintenance, max_attempts: 1, unique: [period: 50]

  import Ecto.Query
  require Marshall.Events
  alias Marshall.Agents.{AuditEvent, Command, Root, ServerTool, ServerToolJob, Turn}
  alias Marshall.Compute.{Ledger, VirtualMachine}

  @batch 200
  @stale_claim_seconds 600

  # @cc [owner:ghuntley,label:recovery] server-tool-reconcile
  # Every queued server-tool command MUST eventually have a job; the unique job
  # key makes re-enqueueing idempotent. A server-held claim older than the stale
  # bound with no live job MUST end `uncertain` with one finish audit row,
  # because its effect may or may not have committed.
  @impl true
  @spec perform(Oban.Job.t()) :: :ok
  def perform(%Oban.Job{}) do
    tools = Enum.map(ServerTool.tools(), &Atom.to_string/1)

    settled = DateTime.add(DateTime.utc_now(), -30, :second)

    queued =
      Marshall.Repo.all(
        from(c in "agent_commands",
          where: c.status == "queued" and c.tool in ^tools and c.inserted_at < ^settled,
          order_by: [asc: c.inserted_at],
          limit: @batch,
          select: type(c.id, :binary_id)
        )
      )

    Enum.each(queued, &(%{"command_id" => &1} |> ServerToolJob.new() |> Oban.insert!()))

    cutoff = DateTime.add(DateTime.utc_now(), -@stale_claim_seconds, :second)

    stale =
      Marshall.Repo.all(
        from(c in "agent_commands",
          as: :command,
          where:
            c.status == "claimed" and c.tool in ^tools and is_nil(c.executor_id) and
              c.claimed_at < ^cutoff,
          where:
            not exists(
              from(r in "artifact_publish_requests",
                where: r.command_id == parent_as(:command).id and r.state == "staging",
                select: 1
              )
            ),
          where:
            not exists(
              from(j in "oban_jobs",
                where:
                  j.worker == "Marshall.Agents.ServerToolJob" and
                    j.state in ["available", "scheduled", "executing", "retryable"] and
                    fragment("?->>'command_id' = ?::text", j.args, parent_as(:command).id),
                select: 1
              )
            ),
          limit: @batch,
          select: type(c.id, :binary_id)
        )
      )

    uncertain = Enum.count(stale, &expire/1)

    if queued != [] or uncertain > 0,
      do:
        Marshall.Events.emit("agent.server_tool_reconciled",
          requeued: length(queued),
          uncertain: uncertain
        )

    :ok
  end

  @spec expire(String.t()) :: boolean()
  defp expire(id) do
    {:ok, expired?} =
      Ledger.transaction(
        fn ->
          with %Command{status: :claimed, executor_id: nil} = command <- Ledger.lock!(Command, id),
               [%Root{} = root] <- Ledger.read!(Root, id: command.root_id),
               %VirtualMachine{} = vm <- Ledger.lock!(VirtualMachine, root.vm_id),
               [%Turn{} = turn] <- Ledger.read!(Turn, id: command.turn_id) do
            Ledger.update!(command, :transition, %{
              status: :uncertain,
              result: %{"reason" => "claim_expired"}
            })

            Ledger.create!(AuditEvent, :record, %{
              vm_id: vm.id,
              thread_id: command.thread_id,
              turn_id: command.turn_id,
              actor_id: turn.actor_id,
              kind: :tool_finished,
              target_id: command.id,
              outcome: :uncertain
            })

            true
          else
            _ -> false
          end
        end,
        {:system, nil}
      )

    expired?
  end
end
