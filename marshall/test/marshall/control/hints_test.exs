defmodule Marshall.Control.HintsTest do
  use ExUnit.Case, async: true
  import Hegel
  import Hegel.Gen

  alias Marshall.Control.Hints

  # @cc [owner:ghuntley,label:verification;security] control-hint-catalog-coverage
  # Every catalogued authority-reducing action MUST carry a Hints.Change of the
  # stated kind, so a new action cannot silently skip invalidation.
  @catalog [
    {Marshall.Access.Grant, :user, [:mark_revoked, :revoke]},
    {Marshall.Access.Grant, :vm, [:mark_revoked, :revoke]},
    {Marshall.Threads.Grant, :user, [:mark_revoked, :revoke]},
    {Marshall.Threads.Grant, :vm, [:mark_revoked, :revoke]},
    {Marshall.Teams.TeamMember, :user, [:replace_role, :remove]},
    {Marshall.Terminal.Grant, :user, [:revoke]},
    {Marshall.Terminal.Session, :vm, [:request_kill, :confirm_kill, :retire_kill, :close]},
    {Marshall.SSH.Key, :user, [:revoke]},
    {Marshall.Accounts.Passkey, :user, [:destroy]},
    {Marshall.Accounts.User, :user, [:security_state, :assign_administrator]},
    {Marshall.Accounts.Token, :user,
     [:revoke_token, :revoke_jti, :revoke_all_stored_for_subject]},
    {Marshall.Ingress.Endpoint, :vm, [:change_policy]},
    {Marshall.Ingress.EnvironmentPublication, :vm, [:advance]},
    {Marshall.Ingress.EnvironmentPublication, :dns_snapshot, [:advance]},
    {Marshall.Ingress.Service, :service, [:rotate]},
    {Marshall.Compute.Host, :host, [:configure, :maintenance, :connect, :disconnect]},
    {Marshall.Compute.VirtualMachine, :vm,
     [:handoff, :restore_source, :request_start, :request_stop, :request_delete, :apply_resize]}
  ]

  test "every catalogued authority-reducing action emits a hint of its kind" do
    for {resource, kind, actions} <- @catalog, action <- actions do
      assert Ash.Resource.Info.action(resource, action), "#{inspect(resource)}.#{action} missing"

      covered =
        Enum.any?(Ash.Resource.Info.changes(resource), fn
          %{change: {Marshall.Control.Hints.Change, options}, where: where} ->
            options[:kind] == kind and
              Enum.any?(where, fn
                {Ash.Resource.Validation.ActionIs, opts} -> action in List.wrap(opts[:action])
                _ -> false
              end)

          _ ->
            false
        end)

      assert covered, "#{inspect(resource)}.#{action} emits no #{kind} hint"
    end
  end

  property "only closed kinds and canonical UUIDs are delivered" do
    kind =
      draw(
        "kind",
        one_of([member_of(Enum.map(Hints.kinds(), &Atom.to_string/1)), string(:alphanumeric)])
      )

    id =
      draw(
        "id",
        one_of([map(constant(nil), fn _ -> Ecto.UUID.generate() end), string(:printable)])
      )

    valid? =
      kind in Enum.map(Hints.kinds(), &Atom.to_string/1) and
        match?({:ok, ^id}, Ecto.UUID.cast(id))

    if valid? do
      atom = String.to_existing_atom(kind)
      :ok = Hints.subscribe(atom, id)
      assert Hints.deliver(%{"kind" => kind, "id" => id}) == :ok
      assert_receive {:control_hint, ^atom, ^id}
    else
      assert Hints.deliver(%{"kind" => kind, "id" => id}) == :ignored
    end
  end

  test "kind-wide subscribers receive every hint of that kind only" do
    id = Ecto.UUID.generate()
    :ok = Hints.subscribe(:vm, :all)
    assert Hints.deliver(%{"kind" => "vm", "id" => id}) == :ok
    assert_receive {:control_hint, :vm, ^id}
    assert Hints.deliver(%{"kind" => "user", "id" => id}) == :ok
    refute_receive {:control_hint, :user, _}, 50
  end

  test "malformed payloads and token subjects are ignored" do
    assert Hints.deliver(%{"kind" => "user"}) == :ignored
    assert Hints.deliver("user") == :ignored
    id = Ecto.UUID.generate()
    assert Hints.token_user(%{subject: "user?id=" <> id}) == id
    assert Hints.token_user(%{subject: "other"}) == nil
    assert Hints.notify(:user, "not-a-uuid") == :ok
    assert Hints.notify(:user, nil) == :ok
  end

  test "the relay delivers hints and resyncs subscribers after notifier recovery" do
    relay = Process.whereis(Hints.Relay)
    assert is_pid(relay)
    id = Ecto.UUID.generate()
    :ok = Hints.subscribe(:vm, id)
    :ok = Hints.subscribe_resync()
    send(relay, {:notification, Hints.channel(), %{"kind" => "vm", "id" => id}})
    assert_receive {:control_hint, :vm, ^id}, 1_000
    send(relay, {:notifier_status, :isolated})
    refute_receive :control_resync, 100
    assert :sys.get_state(relay).notifier == :isolated
    send(relay, {:notifier_status, :clustered})
    assert_receive :control_resync, 1_000
    assert :sys.get_state(relay).notifier == :clustered
  end
end
