# @cc [owner:ghuntley,label:verification] inception-inner-real-control-plane
# This fixture MUST use a regular user actor and the running inner control plane's
# production actions and dispatcher. It MUST wait for real Lilly outcomes, not
# inject reports or mark its own operations complete. It creates no live mail.
defmodule InceptionInnerFixture do
  @moduledoc false
  alias Marshall.Compute.{Ledger, Operation, VirtualMachine}
  @state "/root/inception-native-state.json"

  def run do
    Application.put_env(:marshall, :operator_mode, true)
    {:ok, _} = Application.ensure_all_started(:marshall)
    action = System.fetch_env!("INCEPTION_NATIVE_ACTION")
    {actor, vm_id} = if action == "create" do
      actor = Ash.Seed.seed!(Marshall.Accounts.User, %{email: "native-inception@example.test"})
      # Enrollment selects the immutable seed registered by the inner
      # production enrollment. The instance's private root is delivered at
      # child boot through Lilly's authenticated trust receiver; no private
      # key or per-instance image rebuild enters the enrolled image.
      manifest = "/var/lib/inception/guest-image/manifest.json" |> File.read!() |> JSON.decode!()
      {:ok, image} = OverallsProtocol.ImageManifest.validate(manifest)
      {:ok, vm} = Marshall.Compute.provision(%{
        name: "inner-native", idempotency_key: "native-inception-guest", architecture: :x86_64,
        image_id: image.id, profile: :customer, vcpu: 1,
        memory_bytes: 536_870_912, disk_bytes: 3_221_225_472
      }, actor: actor)
      File.write!(@state, JSON.encode!(%{user_id: actor.id, vm_id: vm.id}))
      File.chmod!(@state, 0o600)
      {actor, vm.id}
    else
      %{"user_id" => user, "vm_id" => vm} = @state |> File.read!() |> JSON.decode!()
      {Ash.get!(Marshall.Accounts.User, user, authorize?: false), vm}
    end

    if action != "create" do
      kind = Map.fetch!(%{"stop" => :stop, "start" => :start, "delete" => :delete}, action)
      {:ok, _} = Marshall.Compute.lifecycle(%{vm_id: vm_id, kind: kind, idempotency_key: "native-" <> action}, actor: actor)
    end
    expected = Map.fetch!(%{"create" => :running, "start" => :running, "stop" => :stopped, "delete" => :deleted}, action)
    vm = await(vm_id, expected, System.monotonic_time(:millisecond) + 180_000)
    [operation] = Ledger.read!(Operation, vm_id: vm.id, generation: vm.generation)
    File.write!("/root/inception-native-command.json", JSON.encode!(operation.command_snapshot))
    File.chmod!("/root/inception-native-command.json", 0o600)
    :ok
  end

  defp await(id, expected, deadline) do
    [vm] = Ledger.history!(VirtualMachine, id: id)
    cond do
      vm.observed_state == expected -> vm
      System.monotonic_time(:millisecond) >= deadline -> raise "Inner lifecycle outcome timed out"
      true -> Process.sleep(200); await(id, expected, deadline)
    end
  end
end

InceptionInnerFixture.run()
