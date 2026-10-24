defmodule Marshall.ServerToolFixture do
  @moduledoc """
  Queues real server-tool commands through a model response on a provisioned
  agent VM (via `AgentRevocationFixture`) and runs their Oban job directly.
  """
  alias Marshall.AgentRevocationFixture, as: Fixture
  alias Marshall.Agents.{Command, Executor, ExecutorSession, ModelCall, ModelCalls, Turn}
  alias Marshall.Compute.Ledger

  @type fixture :: Fixture.fixture()

  @spec setup() :: fixture()
  defdelegate setup(), to: Fixture

  @doc "Submits a turn as `actor` and completes its model call with one tool call."
  @spec queue!(fixture(), String.t(), map(), Marshall.Accounts.User.t()) :: Command.t()
  def queue!(fixture, tool, arguments, actor) do
    finish_active_turn!(fixture)
    {:ok, result} = Fixture.prompt(fixture, Ash.UUID.generate(), actor)
    [turn] = Ledger.read!(Turn, id: result.turn_id)
    Fixture.settle_context!(fixture, turn, fixture.owner)
    :ok = Fixture.tick()
    Fixture.settle_pending_context!(fixture, turn)
    {:ok, %{call: %{} = work}} = ModelCalls.claim(fixture.token)
    [%ModelCall{turn_id: turn_id}] = Ledger.read!(ModelCall, id: work.id)
    ^turn_id = turn.id
    call_id = "server-tool-" <> String.slice(Ash.UUID.generate(), 0, 8)

    {:ok, _} =
      ModelCalls.complete(fixture.token, work.id, work.claim_id, %{
        "status" => "completed",
        "output" => [
          %{
            "type" => "function_call",
            "call_id" => call_id,
            "name" => tool,
            "arguments" => Jason.encode!(arguments)
          }
        ]
      })

    [command] = Ledger.read!(Command, turn_id: turn.id, call_id: call_id)
    command
  end

  # A thread admits one turn at a time: answer the model call that follows a
  # finished tool so the previous turn completes before the next prompt.
  @spec finish_active_turn!(fixture()) :: :ok
  def finish_active_turn!(fixture) do
    case Ledger.read!(Marshall.Agents.Thread, id: fixture.thread.id) do
      [%{active_turn_id: nil}] ->
        :ok

      [%{active_turn_id: _}] ->
        :ok = Fixture.tick()
        {:ok, %{call: %{} = work}} = ModelCalls.claim(fixture.token)

        {:ok, _} =
          ModelCalls.complete(fixture.token, work.id, work.claim_id, %{
            "choices" => [%{"message" => %{"content" => "done"}}]
          })

        :ok = Fixture.tick()
        :ok
    end
  end

  @spec executor!(fixture()) :: Executor.t()
  def executor!(fixture) do
    case Ledger.read!(Executor, vm_id: fixture.vm.id) |> Enum.find(&is_nil(&1.invalidated_at)) do
      %Executor{} = executor -> executor
      nil -> Fixture.register!(fixture)
    end
  end

  @spec run!(Command.t()) :: Command.t()
  def run!(%Command{id: id}) do
    now = DateTime.utc_now()

    # A complete executing job: Oban.Job.t() requires its identity, worker,
    # priority and timestamps, which a bare struct literal leaves nil.
    job = %Oban.Job{
      id: 1,
      state: "executing",
      queue: "agent_tools",
      worker: inspect(Marshall.Agents.ServerToolJob),
      args: %{"command_id" => id},
      attempt: 1,
      max_attempts: 5,
      priority: 0,
      inserted_at: now,
      scheduled_at: now,
      attempted_at: now
    }

    :ok = Marshall.Agents.ServerToolJob.perform(job)
    [command] = Ledger.read!(Command, id: id)
    command
  end

  @doc "The guest executor's claim for this VM; server tools must never be returned."
  @spec executor_claim(fixture()) :: Command.t() | nil
  def executor_claim(fixture) do
    executor = executor!(fixture)
    {:ok, command} = ExecutorSession.claim(fixture.binding, executor.id, executor.fence_epoch)
    command
  end
end
