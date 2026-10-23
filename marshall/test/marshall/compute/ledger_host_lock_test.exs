defmodule Marshall.Compute.LedgerHostLockTest do
  @moduledoc "Host row locks leave foreign-key KEY SHARE checks unblocked."
  use Marshall.DataCase, async: false
  import Marshall.ComputeFixtures
  alias Marshall.Compute.{Host, Ledger, VirtualMachine}

  @spec capture_queries((-> term())) :: [String.t()]
  defp capture_queries(fun) do
    receiver = self()
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(
        handler,
        [:marshall, :repo, :query],
        fn _event, _measurements, %{query: query}, _config -> send(receiver, {:query, query}) end,
        nil
      )

    try do
      fun.()
    after
      :telemetry.detach(handler)
    end

    collect([])
  end

  @spec collect([String.t()]) :: [String.t()]
  defp collect(queries) do
    receive do
      {:query, query} -> collect([query | queries])
    after
      0 -> Enum.reverse(queries)
    end
  end

  test "host rows lock FOR NO KEY UPDATE; other resources keep FOR UPDATE" do
    assert Ledger.lock_mode(Host) == "FOR NO KEY UPDATE"
    assert Ledger.lock_mode(VirtualMachine) == :for_update
  end

  test "lock!/2 issues the no-key lock for hosts" do
    %{host: host} = host_fixture()

    queries =
      capture_queries(fn ->
        assert {:ok, _} =
                 Ledger.transaction(fn ->
                   assert %Host{} = Ledger.lock!(Host, host.id)
                 end)
      end)

    locks = Enum.filter(queries, &(&1 =~ ~s(FROM "compute_hosts") and &1 =~ "FOR "))
    assert length(locks) == 1
    assert Enum.all?(locks, &(&1 =~ "FOR NO KEY UPDATE"))
  end

  test "guest-credential readers share the host row and fences exclude them" do
    %{host: host} = host_fixture()

    queries =
      capture_queries(fn ->
        assert {:ok, _} =
                 Ledger.transaction(fn ->
                   assert %Host{} = Ledger.share_host!(host.id)
                   assert %Host{} = Ledger.fence_host!(host.id)
                 end)
      end)

    locks = Enum.filter(queries, &(&1 =~ ~s(FROM "compute_hosts") and &1 =~ "FOR "))
    assert [share, fence] = locks
    assert share =~ "FOR KEY SHARE"
    assert fence =~ "FOR UPDATE" and not (fence =~ "NO KEY")
  end
end
