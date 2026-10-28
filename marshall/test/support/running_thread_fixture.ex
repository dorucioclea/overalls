defmodule Marshall.RunningThreadFixture do
  @moduledoc "A running agent VM whose root thread is bound to a ready user thread."
  import Marshall.ComputeFixtures
  alias Marshall.Compute
  alias Marshall.Compute.{Host, Ledger, Operation, Outcomes}
  alias Marshall.Threads.Thread

  @type fixture :: %{
          actor: Marshall.Accounts.User.t(),
          vm: Marshall.Compute.VirtualMachine.t(),
          agent: Marshall.Agents.Thread.t(),
          thread: Thread.t()
        }

  @doc "Provisions and reports a running VM for `actor`, then binds a ready user thread."
  @spec setup(Marshall.Accounts.User.t(), String.t() | nil) :: fixture()
  def setup(actor, team_id \\ nil) do
    host_fixture()
    {:ok, vm} = Compute.provision(Map.put(request(), :team_id, team_id), actor: actor)
    [operation] = Ledger.read!(Operation, vm_id: vm.id)

    event = %{
      id: Ash.UUID.generate(),
      vm_id: vm.id,
      placement_id: operation.placement_id,
      execution_epoch: operation.execution_epoch,
      operation_id: operation.id,
      generation: operation.generation,
      sequence: 1,
      state: :running,
      compute_empty: false,
      disk_present: true,
      cleanup_complete: false,
      reason: :none
    }

    {:ok, parsed} =
      OverallsProtocol.Execution.outcome(OverallsProtocol.Execution.encode_outcome(event))

    {:ok, _} =
      Ledger.transaction(fn ->
        Ledger.lock!(Host, vm.host_id)
        Outcomes.ingest_locked!(vm.host_id, [parsed])
      end)

    [root] = Ledger.read!(Marshall.Agents.Root, vm_id: vm.id)
    [agent] = Ledger.read!(Marshall.Agents.Thread, root_id: root.id)

    thread =
      Ledger.create!(Thread, :open, %{
        creator_id: actor.id,
        team_id: team_id,
        objective: "Running thread",
        mode: :medium,
        machine_spec: Map.put(request(), :team_id, team_id),
        idempotency_key: Ash.UUID.generate(),
        machine_key: vm.idempotency_key
      })
      |> Marshall.ThreadStateFixture.ready!(%{
        machine_id: vm.id,
        agent_root_id: root.id,
        agent_thread_id: agent.id
      })

    %{actor: actor, vm: vm, agent: agent, thread: thread}
  end
end
