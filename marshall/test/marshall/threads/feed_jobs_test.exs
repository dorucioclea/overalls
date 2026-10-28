defmodule Marshall.Threads.FeedJobsTest do
  # @cc [owner:ghuntley,label:verification;durability;security] thread-feed-jobs-model
  # A finished ordinary root turn MUST enqueue exactly one feed append in its
  # own transaction and produce exactly one dense `turn_finished` notification
  # however often the job runs; maintenance and child turns produce none.
  # Generated grant, team and subscribe histories MUST leave a subscription
  # revoked exactly when its owner lost current read authority, with one audit
  # row per revocation and no replay afterwards.
  use Marshall.DataCase, async: false
  import Marshall.ComputeFixtures
  import Hegel
  import Hegel.Gen

  alias Marshall.Agents

  alias Marshall.Agents.{
    AuditEvent,
    ThreadNotification,
    ThreadSubscription,
    TurnCoordinator
  }

  alias Marshall.Compute.Ledger
  alias Marshall.Threads.{FeedAppendJob, SubscriptionRevokeJob}

  test "a finished root turn appends one turn_finished notification" do
    %{actor: actor, agent: agent, thread: thread} = running_thread()

    {:ok, %{turn_id: turn_id}} =
      Agents.submit_prompt(
        %{thread_id: agent.id, prompt: "work", request_key: Ash.UUID.generate()},
        actor: actor
      )

    assert {:ok, %{id: ^turn_id}} = TurnCoordinator.claim_next()
    assert {:ok, %{status: :completed}} = TurnCoordinator.finish(turn_id, :completed, "done")

    assert [job] = Oban.Testing.all_enqueued(repo: Marshall.Repo, worker: FeedAppendJob)
    assert job.args == %{"agent_thread_id" => agent.id, "turn_id" => turn_id}

    assert :ok = Oban.Testing.perform_job(FeedAppendJob, job.args, repo: Marshall.Repo)
    assert :ok = Oban.Testing.perform_job(FeedAppendJob, job.args, repo: Marshall.Repo)

    assert [notification] = Ledger.read!(ThreadNotification, user_thread_id: thread.id)
    assert notification.kind == :turn_finished
    assert notification.sequence == 1
    assert notification.thread_id == agent.id
    assert notification.metadata == %{"turn_id" => turn_id, "outcome" => "completed"}

    assert {:ok, %{active: true}} = Agents.ThreadTool.subscribe(actor.id, thread.id)

    assert {:ok, [%{sequence: 1, kind: :turn_finished}]} =
             Agents.ThreadTool.replay(actor.id, thread.id, 0)
  end

  test "child and maintenance turns are not announced and invalid jobs cancel" do
    %{actor: actor, agent: agent} = running_thread()
    assert {:ok, child} = Agents.Conversation.spawn_child(agent.id, "Investigate", actor)

    {:ok, %{turn_id: child_turn}} =
      Agents.submit_prompt(
        %{thread_id: child.id, prompt: "child", request_key: Ash.UUID.generate()},
        actor: actor
      )

    assert {:ok, %{id: ^child_turn}} = TurnCoordinator.claim_next()
    assert {:ok, _} = TurnCoordinator.finish(child_turn, :failed, :provider_failed)
    assert [] = Oban.Testing.all_enqueued(repo: Marshall.Repo, worker: FeedAppendJob)

    assert {:cancel, :invalid_job} =
             Oban.Testing.perform_job(
               FeedAppendJob,
               %{"agent_thread_id" => "x", "turn_id" => "y"},
               repo: Marshall.Repo
             )

    assert {:cancel, :invalid_job} =
             Oban.Testing.perform_job(SubscriptionRevokeJob, %{"thread_id" => "nope"},
               repo: Marshall.Repo
             )
  end

  test "revoking a share revokes the subscription and its receivers" do
    %{actor: owner, thread: thread} = running_thread()
    reader = user()
    share!(owner, thread, reader, :viewer)
    assert {:ok, %{active: true}} = Agents.ThreadTool.subscribe(reader.id, thread.id)
    drain_reviews()
    assert [%{state: :active}] = subscriptions(reader, thread)

    share!(owner, thread, reader, :revoked)

    assert [%{args: %{"thread_id" => thread_id}}] =
             Oban.Testing.all_enqueued(repo: Marshall.Repo, worker: SubscriptionRevokeJob)

    assert thread_id == thread.id
    drain_reviews()
    drain_reviews()

    assert [%{state: :revoked} = subscription] = subscriptions(reader, thread)

    assert [%{actor_id: actor_id, outcome: :completed}] =
             Ledger.read!(AuditEvent,
               kind: :thread_subscription_revoked,
               target_id: subscription.id
             )

    assert actor_id == reader.id
    assert {:error, :forbidden} = Agents.ThreadTool.replay(reader.id, thread.id, 0)

    share!(owner, thread, reader, :viewer)
    assert {:ok, %{active: true}} = Agents.ThreadTool.subscribe(reader.id, thread.id)
    drain_reviews()
    assert [%{state: :active}] = subscriptions(reader, thread)
  end

  @tag :hegel_case_sandbox
  @tag timeout: 900_000
  property "subscription reviews match the current read authority model", test_cases: 10 do
    Marshall.DataCase.isolate_property_case()
    host_fixture()
    owner = user()
    reader = user()

    {:ok, team} =
      Marshall.Teams.create_team(
        %{name: "feed-team-#{Ash.UUID.generate()}", idempotency_key: Ash.UUID.generate()},
        actor: owner
      )

    %{thread: thread} = running_thread(owner, team.id)

    steps =
      draw(
        "steps",
        list_of(member_of([:share, :unshare, :join, :leave, :subscribe, :review]),
          min_length: 1,
          max_length: 12
        )
      )

    final =
      Enum.reduce(steps, %{grant: false, member: false, state: nil, audits: 0}, fn step, model ->
        model = apply_step(step, model, owner, reader, team, thread)
        assert current_state(reader, thread) == model.state

        assert length(Ledger.read!(AuditEvent, kind: :thread_subscription_revoked)) ==
                 model.audits

        model
      end)

    drain_reviews()
    final = review(final)
    assert current_state(reader, thread) == final.state
  end

  defp apply_step(:share, model, owner, reader, _team, thread) do
    share!(owner, thread, reader, :viewer)
    %{model | grant: true}
  end

  defp apply_step(:unshare, model, owner, reader, _team, thread) do
    if model.grant, do: share!(owner, thread, reader, :revoked)
    %{model | grant: false}
  end

  defp apply_step(:join, model, owner, reader, team, _thread) do
    member!(owner, team, reader, :member)
    %{model | member: true}
  end

  defp apply_step(:leave, model, owner, reader, team, _thread) do
    if model.member, do: member!(owner, team, reader, :removed)
    %{model | member: false}
  end

  defp apply_step(:subscribe, model, _owner, reader, _team, thread) do
    case Agents.ThreadTool.subscribe(reader.id, thread.id) do
      {:ok, %{active: true}} ->
        assert allowed?(model)
        %{model | state: :active}

      {:error, :forbidden} ->
        refute allowed?(model)
        model
    end
  end

  defp apply_step(:review, model, _owner, _reader, _team, _thread) do
    drain_reviews()
    review(model)
  end

  defp review(%{state: state} = model) when state in [:active, :inactive] do
    if allowed?(model), do: model, else: %{model | state: :revoked, audits: model.audits + 1}
  end

  defp review(model), do: model

  defp allowed?(model), do: model.grant or model.member

  defp current_state(reader, thread) do
    case subscriptions(reader, thread) do
      [] -> nil
      [subscription] -> subscription.state
    end
  end

  defp subscriptions(reader, thread),
    do: Ledger.read!(ThreadSubscription, owner_id: reader.id, user_thread_id: thread.id)

  defp drain_reviews do
    [repo: Marshall.Repo, worker: SubscriptionRevokeJob]
    |> Oban.Testing.all_enqueued()
    |> Enum.each(fn job ->
      assert :ok = Oban.Testing.perform_job(SubscriptionRevokeJob, job.args, repo: Marshall.Repo)
      Marshall.Repo.delete_all(Ecto.Query.from(j in Oban.Job, where: j.id == ^job.id))
    end)
  end

  defp share!(owner, thread, reader, role) do
    assert {:ok, _} =
             Marshall.Threads.set_access(
               %{
                 thread_id: thread.id,
                 email: to_string(reader.email),
                 role: role,
                 idempotency_key: Ash.UUID.generate()
               },
               actor: owner
             )
  end

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

  defp running_thread(actor \\ nil, team_id \\ nil),
    do: Marshall.RunningThreadFixture.setup(actor || user(), team_id)
end
