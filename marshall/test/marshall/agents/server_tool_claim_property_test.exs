defmodule Marshall.Agents.ServerToolClaimPropertyTest do
  # @cc [owner:ghuntley,label:verification;security;concurrency] server-tool-claim-model
  # For generated server-tool calls and generated interleavings of guest
  # executor claims, sequential and concurrent job runs and reconciler passes,
  # the executor MUST never receive the command, the command MUST end in one
  # terminal state with one stable result, and exactly one finish audit row
  # MUST exist however many workers raced for it.
  use MarshallWeb.ConnCase, async: false
  import Hegel
  import Hegel.Gen

  alias Marshall.Agents.{AuditEvent, Command, ServerToolJob, ServerToolReconciler}
  alias Marshall.Compute.Ledger
  alias Marshall.ServerToolFixture, as: Fixture

  @moduletag capture_log: true

  @calls [
    {"artifact", %{"operation" => "publish", "base_version" => 0, "content" => "<p>x</p>"}},
    {"artifact", %{"operation" => "list"}},
    {"thread", %{"operation" => "search"}}
  ]

  @tag :hegel_case_sandbox
  @tag timeout: 900_000
  property "server-tool commands are claimed once and never by the executor", test_cases: 6 do
    Marshall.DataCase.isolate_property_case()
    fixture = Fixture.setup()
    {tool, arguments} = draw("call", member_of(@calls))

    steps =
      draw(
        "steps",
        list_of(
          tuple([member_of([:executor, :job, :race, :reconcile]), integer(2, 4)]),
          min_length: 1,
          max_length: 8
        )
      )

    command = Fixture.queue!(fixture, tool, arguments, fixture.member)
    assert command.status == :queued

    Enum.each(steps ++ [{:job, 1}], fn
      {:executor, _} ->
        assert Fixture.executor_claim(fixture) == nil

      {:job, _} ->
        Fixture.run!(command)

      {:race, workers} ->
        1..workers
        |> Enum.map(fn _ -> Task.async(fn -> Fixture.run!(command) end) end)
        |> Task.await_many(60_000)

      {:reconcile, _} ->
        assert :ok = ServerToolReconciler.perform(%Oban.Job{args: %{}})
    end)

    assert [%Command{status: status, result: result}] = Ledger.read!(Command, id: command.id)
    assert status in [:completed, :failed]
    assert Fixture.run!(command).result == result
    assert Fixture.executor_claim(fixture) == nil

    assert [_] = Ledger.read!(AuditEvent, target_id: command.id, kind: :tool_finished)

    assert Oban.Testing.all_enqueued(repo: Marshall.Repo, worker: ServerToolJob)
           |> Enum.map(& &1.args["command_id"])
           |> Enum.count(&(&1 == command.id)) <= 1
  end
end
