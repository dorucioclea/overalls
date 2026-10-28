defmodule Marshall.Agents.ThreadToolPropertyTest do
  # @cc [owner:ghuntley,label:verification;security] thread-tool-visibility-replay-model
  # For generated sets of owned threads, shares and feed appends, a reader's
  # search MUST return exactly the threads Cedar lets them read; replay from any
  # cursor MUST return the dense ascending sequences after it, bounded by the
  # limit; subscribing again MUST be idempotent; and unshared threads MUST
  # refuse subscribe and replay.
  use Marshall.DataCase, async: false
  import Marshall.ComputeFixtures
  import Hegel
  import Hegel.Gen

  alias Marshall.Agents.{ThreadFeed, ThreadSubscription, ThreadTool}
  alias Marshall.Compute.Ledger
  alias Marshall.Threads.Thread

  @tag :hegel_case_sandbox
  @tag timeout: 900_000
  property "search, subscribe and replay follow current thread authority", test_cases: 5 do
    Marshall.DataCase.isolate_property_case()
    host_fixture()
    owner = user()
    reader = user()

    shared = draw("shared", list_of(member_of([true, false]), min_length: 1, max_length: 2))
    threads = Enum.map(shared, fn share? -> {thread!(owner, reader, share?), share?} end)

    appends =
      draw(
        "appends",
        list_of(integer(0, length(threads) - 1), min_length: 0, max_length: 10)
      )

    counts =
      Enum.reduce(appends, %{}, fn index, counts ->
        {thread, _} = Enum.at(threads, index)

        {:ok, _} =
          Ledger.transaction(fn ->
            ThreadFeed.append_locked!(
              thread.id,
              thread.agent_thread_id,
              owner.id,
              :machine_purged,
              %{
                "state" => "stopped"
              }
            )
          end)

        Map.update(counts, thread.id, 1, &(&1 + 1))
      end)

    visible = for {thread, true} <- threads, into: MapSet.new(), do: thread.id
    assert {:ok, found} = ThreadTool.search(reader.id)
    assert MapSet.new(found, & &1.id) == visible
    assert Enum.all?(found, &(&1.url == "/threads/" <> &1.id))

    for {thread, share?} <- threads do
      total = Map.get(counts, thread.id, 0)
      cursor = draw("cursor", integer(0, total + 1))
      limit = draw("limit", integer(1, 4))

      if share? do
        assert {:ok, %{active: true}} = ThreadTool.subscribe(reader.id, thread.id)
        assert {:ok, %{active: true}} = ThreadTool.subscribe(reader.id, thread.id)

        assert [%{state: :active}] =
                 Ledger.read!(ThreadSubscription, owner_id: reader.id, user_thread_id: thread.id)

        expected = Enum.take(Enum.to_list((cursor + 1)..total//1), limit)
        assert {:ok, events} = ThreadTool.replay(reader.id, thread.id, cursor, limit)
        assert Enum.map(events, & &1.sequence) == expected
      else
        assert {:error, :forbidden} = ThreadTool.subscribe(reader.id, thread.id)
        assert {:error, :forbidden} = ThreadTool.replay(reader.id, thread.id, cursor, limit)
      end
    end
  end

  defp thread!(owner, reader, share?) do
    {:ok, vm} = Marshall.Compute.provision(request(), actor: owner)
    [root] = Ledger.read!(Marshall.Agents.Root, vm_id: vm.id)
    [agent] = Ledger.read!(Marshall.Agents.Thread, root_id: root.id)

    thread =
      Ledger.create!(Thread, :open, %{
        creator_id: owner.id,
        objective: "Property thread",
        mode: :medium,
        machine_spec: request(),
        idempotency_key: Ash.UUID.generate(),
        machine_key: vm.idempotency_key
      })
      |> Marshall.ThreadStateFixture.ready!(%{
        machine_id: vm.id,
        agent_root_id: root.id,
        agent_thread_id: agent.id
      })

    if share? do
      {:ok, _} =
        Marshall.Threads.set_access(
          %{
            thread_id: thread.id,
            email: to_string(reader.email),
            role: :viewer,
            idempotency_key: Ash.UUID.generate()
          },
          actor: owner
        )
    end

    thread
  end
end
