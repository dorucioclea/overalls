defmodule Marshall.Scim.TeamCleanup do
  @moduledoc """
  Revokes durable team-owned authority for SCIM team retirement (ADR-0229).

  Both entry points must run inside a Ledger transaction: every revocation and
  the final archive commit together or not at all, and failures raise so the
  calling request or Oban job surfaces and retries them.
  """

  alias Marshall.Access.Grant
  alias Marshall.Compute.{Ledger, VirtualMachine}
  alias Marshall.Galileo.Integration
  alias Marshall.Teams.{Team, TeamMember, Transfer}
  alias Marshall.Terminal.Session
  require Marshall.Events

  # @cc [owner:ghuntley,label:security;recovery] scim-team-authority-revocation
  # Revocation MUST cancel and archive the team's transfers, archive its
  # integrations, remove every non-owner membership and revoke machine grants
  # and terminal sessions on every team machine, including deleted ones. Any
  # failure MUST raise and roll back the enclosing transaction; nothing is
  # swallowed.
  @doc "Revoke all team authority except the owner membership that keeps the row valid."
  @spec revoke_authority!(Team.t()) :: :ok
  def revoke_authority!(%Team{} = team) do
    Transfer
    |> Ledger.read!(team_id: team.id, state: :pending)
    |> Enum.each(&Ledger.update!(&1, :cancel, %{}))

    Transfer |> Ledger.read!(team_id: team.id) |> Enum.each(&Ledger.archive!(&1, :archive))
    Integration |> Ledger.read!(team_id: team.id) |> Enum.each(&Ledger.archive!(&1, :archive))

    TeamMember
    |> Ledger.read!(team_id: team.id)
    |> Enum.reject(&(&1.role == :owner))
    |> Enum.each(fn membership ->
      Ledger.archive!(membership, :remove)
      Marshall.Threads.SubscriptionRevokeJob.enqueue_owner!(membership.user_id)
    end)

    # Archived (deleted) team machines included: their grants and sessions are
    # retired with the team rather than left as live rows.
    VirtualMachine
    |> Ledger.history!(team_id: team.id)
    |> Enum.each(fn vm ->
      Grant |> Ledger.read!(vm_id: vm.id) |> Enum.each(&Ledger.archive!(&1, :revoke))
      Session |> Ledger.read!(vm_id: vm.id) |> Enum.each(&Ledger.archive!(&1, :close))
    end)

    Ledger.after_commit(fn ->
      Marshall.Events.emit("scim.team_authority_revoked", team_id: team.id)
    end)

    :ok
  end

  # @cc [owner:ghuntley,label:persistence;recovery] scim-team-final-archive
  # Finalization MUST revoke remaining authority, remove the owner membership and
  # archive the team in one transaction so the exactly-one-owner invariant holds
  # at commit. Callers MUST first ensure no live team machine remains.
  @doc "Revoke everything and archive `team`; call inside a Ledger transaction."
  @spec archive!(Team.t()) :: :ok
  def archive!(%Team{} = team) do
    :ok = revoke_authority!(team)

    TeamMember
    |> Ledger.read!(team_id: team.id)
    |> Enum.each(fn membership ->
      Ledger.archive!(membership, :remove)
      Marshall.Threads.SubscriptionRevokeJob.enqueue_owner!(membership.user_id)
    end)

    Ledger.archive!(team, :archive)
  end
end
