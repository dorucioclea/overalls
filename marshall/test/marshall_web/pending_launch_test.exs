defmodule MarshallWeb.PendingLaunchTest do
  use ExUnit.Case, async: true
  import Hegel
  import Hegel.Gen
  alias MarshallWeb.PendingLaunch

  @url "https://github.com/antithesishq/weaver"
  @visit String.duplicate("a", 32)

  test "capture is canonical bounded input with server-issued expiry" do
    assert {:ok, pending} =
             PendingLaunch.new(@url <> ".git?secret=discarded#fragment", @visit, 100)

    assert pending == %{source: @url, visit: @visit, expires_at: 1_900}
    assert %{source: source, visit: @visit} = PendingLaunch.validate(pending, 101)
    assert OverallsProtocol.WorkspaceSource.to_url(source) == @url
    assert is_nil(PendingLaunch.validate(pending, 1_900))
    assert is_nil(PendingLaunch.validate(pending, 99))
    assert is_nil(PendingLaunch.validate(Map.put(pending, :return_to, "/admin/users"), 100))
    assert is_nil(PendingLaunch.validate(%{pending | source: @url <> ".git"}, 100))
  end

  property "arbitrary staged values never bypass the exact validated shape", test_cases: 100 do
    value = draw("value", term())
    assert is_nil(PendingLaunch.validate(value, 100))
  end

  test "nonces reject oversized malformed and missing input" do
    for visit <- [nil, "ABCDEF", String.duplicate("a", 33), String.duplicate("a", 10_000)] do
      assert {:error, :invalid_visit} = PendingLaunch.new(@url, visit, 100)
    end
  end

  test "completion receipts bind actor machine source and visit and refuse tampering" do
    user_id = Ash.UUID.generate()
    vm_id = Ash.UUID.generate()
    {:ok, source} = OverallsProtocol.WorkspaceSource.parse_url(@url)
    receipt = PendingLaunch.receipt(user_id, vm_id, source, @visit)
    assert {:ok, completion} = PendingLaunch.verify_receipt(receipt)
    assert completion == %{user_id: user_id, vm_id: vm_id, source: @url, visit: @visit}
    assert :error = PendingLaunch.verify_receipt(receipt <> "x")
    assert :error = PendingLaunch.verify_receipt(nil)
    assert {:ok, pending} = PendingLaunch.new(@url, @visit)
    assert PendingLaunch.matches?(%{PendingLaunch.key() => pending}, completion)

    refute PendingLaunch.matches?(
             %{PendingLaunch.key() => %{pending | visit: String.duplicate("b", 32)}},
             completion
           )
  end

  # @cc [owner:ghuntley,label:security;verification] deployment-receipt-integrity
  # A completion receipt is a signed session approval.  Every generated
  # non-empty suffix must invalidate it, so a replay or transport mutation can
  # never authorize a different deployment completion.
  property "generated deployment receipt mutations always refuse", test_cases: 100 do
    user_id = Ash.UUID.generate()
    vm_id = Ash.UUID.generate()
    {:ok, source} = OverallsProtocol.WorkspaceSource.parse_url(@url)
    receipt = PendingLaunch.receipt(user_id, vm_id, source, @visit)
    suffix = draw("suffix", string(:alphanumeric, min_length: 1, max_length: 32))

    assert :error = PendingLaunch.verify_receipt(receipt <> suffix)
    assert :error = PendingLaunch.verify_receipt(suffix <> receipt)
  end
end
