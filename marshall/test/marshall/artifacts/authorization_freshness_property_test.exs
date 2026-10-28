defmodule Marshall.Artifacts.AuthorizationFreshnessPropertyTest do
  # @cc [owner:ghuntley,label:verification;security] artifact-authorization-freshness
  # Generated direct-grant, team-grant and team-membership histories MUST keep
  # every artifact decision equal to a pure model of the reader's current
  # effective role. A view ticket MUST redeem exactly while it was not revoked
  # by a later access change and the reader still holds read; membership loss
  # MUST take effect on the next redemption without any ticket revocation.
  use Marshall.DataCase, async: false
  import Hegel
  import Hegel.Gen

  alias Marshall.Artifacts.{Authorization, Library, Publisher, Sharing, Tickets}
  alias Marshall.Compute.Ledger
  alias Marshall.PasskeyFixture

  @host "content.example.test"
  @rank %{nil => 0, viewer: 1, writer: 2, owner: 3}

  @type model :: %{
          direct: :owner | :writer | :viewer | nil,
          team: :writer | :viewer | nil,
          member: boolean(),
          tickets: [{String.t(), boolean()}]
        }

  @tag :hegel_case_sandbox
  @tag timeout: 900_000
  property "decisions and tickets follow the current effective role", test_cases: 12 do
    Marshall.DataCase.isolate_property_case()
    owner = PasskeyFixture.user(false)
    reader = PasskeyFixture.user(false)

    {:ok, team} =
      Marshall.Teams.create_team(
        %{name: "artifact-team-#{Ash.UUID.generate()}", idempotency_key: Ash.UUID.generate()},
        actor: owner
      )

    {:ok, %{artifact: artifact}} =
      Publisher.publish(owner, %{
        artifact_id: nil,
        base_version: 0,
        page: {:content, "fresh"},
        via: :web
      })

    steps =
      draw(
        "steps",
        list_of(
          tuple([
            member_of([:direct, :team, :join, :leave, :ticket]),
            member_of([:owner, :writer, :viewer, :revoked])
          ]),
          min_length: 1,
          max_length: 14
        )
      )

    Enum.reduce(steps, %{direct: nil, team: nil, member: false, tickets: []}, fn step, model ->
      model = apply_step(step, model, owner, reader, team, artifact)
      check!(model, reader, artifact)
      model
    end)
  end

  @spec apply_step({atom(), atom()}, model(), term(), term(), term(), term()) :: model()
  defp apply_step({:direct, role}, model, owner, reader, _team, artifact) do
    assert {:ok, _} =
             Sharing.set_access(
               owner,
               artifact.id,
               {:email, to_string(reader.email)},
               role,
               Ash.UUID.generate()
             )

    %{model | direct: unless(role == :revoked, do: role), tickets: revoke_all(model.tickets)}
  end

  defp apply_step({:team, :owner}, model, owner, _reader, team, artifact) do
    assert {:error, _} =
             Sharing.set_access(owner, artifact.id, {:team, team.id}, :owner, Ash.UUID.generate())

    model
  end

  defp apply_step({:team, role}, model, owner, _reader, team, artifact) do
    assert {:ok, _} =
             Sharing.set_access(owner, artifact.id, {:team, team.id}, role, Ash.UUID.generate())

    %{model | team: unless(role == :revoked, do: role), tickets: revoke_all(model.tickets)}
  end

  defp apply_step({:join, _}, model, owner, reader, team, _artifact) do
    member!(owner, team, reader, :member)
    %{model | member: true}
  end

  defp apply_step({:leave, _}, model, owner, reader, team, _artifact) do
    if model.member, do: member!(owner, team, reader, :removed)
    %{model | member: false}
  end

  defp apply_step({:ticket, _}, model, _owner, reader, _team, artifact) do
    [current] = Ledger.read!(Marshall.Artifacts.Artifact, id: artifact.id)
    {:ok, version} = Library.version(current, nil)

    case Tickets.issue(reader, current, version, @host) do
      {:ok, token} ->
        assert readable?(model)
        %{model | tickets: [{token, true} | model.tickets]}

      {:error, :not_found} ->
        refute readable?(model)
        model
    end
  end

  @spec check!(model(), term(), term()) :: :ok
  defp check!(model, reader, artifact) do
    [current] = Ledger.read!(Marshall.Artifacts.Artifact, id: artifact.id)
    role = effective(model)

    assert Authorization.role(current, reader) == role
    assert Authorization.allowed?(current, reader, :read) == readable?(model)
    assert Authorization.allowed?(current, reader, :publish) == @rank[role] >= 2
    assert Authorization.allowed?(current, reader, :share) == (role == :owner)
    assert Authorization.allowed?(current, reader, :storage_shared_write) == @rank[role] >= 2

    for {token, live} <- model.tickets do
      expected = live and readable?(model)
      assert match?({:ok, _}, Tickets.redeem(token, @host)) == expected
    end

    :ok
  end

  @spec effective(model()) :: :owner | :writer | :viewer | nil
  defp effective(model) do
    team = if model.member, do: model.team
    Enum.max_by([model.direct, team], &@rank[&1])
  end

  defp readable?(model), do: effective(model) != nil

  defp revoke_all(tickets), do: Enum.map(tickets, fn {token, _} -> {token, false} end)

  defp member!(owner, team, reader, role) do
    assert {:ok, _} =
             Marshall.Teams.set_team_member(
               %{
                 team_id: team.id,
                 email: to_string(reader.email),
                 role: role,
                 idempotency_key: Ash.UUID.generate()
               },
               actor: owner
             )
  end
end
