defmodule Marshall.ObanIdempotencyPropertyTest do
  # @cc [owner:ghuntley,label:verification;durability;recovery] oban-job-idempotency
  # For generated histories of job runs, crashes before commit (the job's
  # transaction rolls back) and duplicate enqueues, artifact purges and thread
  # feed appends MUST each end in exactly one terminal outcome: a purged
  # artifact with no content rows and exactly one `purged` audit row, and
  # exactly one `turn_finished` notification for the finished turn. Duplicate
  # enqueues MUST collapse onto at most one pending job per key.
  use Marshall.DataCase, async: false
  import Marshall.ComputeFixtures
  import Hegel
  import Hegel.Gen

  alias Marshall.Agents
  alias Marshall.Agents.{ThreadNotification, TurnCoordinator}
  alias Marshall.Artifacts.{Artifact, AuditEvent, Library, Publisher, PurgeJob}
  alias Marshall.Compute.Ledger
  alias Marshall.Threads.FeedAppendJob

  @content ~w(artifact_storage_entries artifact_storage_usage artifact_view_tickets
              artifact_version_files artifact_versions)

  @tag :hegel_case_sandbox
  @tag timeout: 900_000
  property "job reruns, crashes and duplicates commit one outcome", test_cases: 8 do
    Marshall.DataCase.isolate_property_case()
    owner = user()
    artifact = artifact!(owner, draw("versions", integer(1, 3)))
    assert {:ok, %{state: :deleting}} = Library.delete(owner, artifact.id, :web)
    feed = finished_turn!(owner)

    jobs = %{
      purge: {PurgeJob, %{"artifact_id" => artifact.id}},
      feed: {FeedAppendJob, feed}
    }

    steps =
      draw(
        "steps",
        list_of(tuple([member_of([:purge, :feed]), member_of([:run, :crash, :duplicate])]),
          max_length: 12
        )
      )

    Enum.each(steps, fn {key, mode} ->
      {worker, args} = jobs[key]
      step!(mode, worker, args)
      assert pending(worker, args) <= 1
      assert length(notifications(feed)) <= 1
      assert length(Ledger.read!(AuditEvent, artifact_id: artifact.id, kind: :purged)) <= 1
    end)

    drain!(PurgeJob, jobs.purge |> elem(1), 4)
    assert :ok = Oban.Testing.perform_job(FeedAppendJob, feed, repo: Marshall.Repo)

    assert [%Artifact{state: :deleted}] = Ledger.read!(Artifact, id: artifact.id)
    assert [_] = Ledger.read!(AuditEvent, artifact_id: artifact.id, kind: :purged)
    assert [_] = Ledger.read!(AuditEvent, artifact_id: artifact.id, kind: :deleted)
    assert Enum.all?(@content, &(rows(&1, artifact.id) == 0))
    assert [%{kind: :turn_finished}] = notifications(feed)
  end

  defp step!(:run, worker, args),
    do: assert(:ok = Oban.Testing.perform_job(worker, args, repo: Marshall.Repo))

  defp step!(:crash, worker, args) do
    assert {:error, :crashed} =
             Ledger.transaction(fn ->
               :ok = Oban.Testing.perform_job(worker, args, repo: Marshall.Repo)
               Ledger.rollback(:crashed)
             end)
  end

  defp step!(:duplicate, worker, args), do: args |> worker.new() |> Oban.insert!()

  defp drain!(_worker, _args, 0), do: :ok

  defp drain!(worker, args, remaining) do
    assert :ok = Oban.Testing.perform_job(worker, args, repo: Marshall.Repo)
    drain!(worker, args, remaining - 1)
  end

  defp pending(worker, args) do
    [repo: Marshall.Repo, worker: worker]
    |> Oban.Testing.all_enqueued()
    |> Enum.count(&(&1.args == args and &1.state in ["available", "scheduled", "retryable"]))
  end

  defp notifications(%{"agent_thread_id" => agent_id, "turn_id" => turn_id}) do
    Ledger.read!(ThreadNotification, thread_id: agent_id)
    |> Enum.filter(&(&1.metadata["turn_id"] == turn_id))
  end

  defp rows(table, artifact_id) do
    %{rows: [[count]]} =
      Ecto.Adapters.SQL.query!(
        Marshall.Repo,
        "SELECT count(*) FROM #{table} WHERE artifact_id = $1",
        [Ecto.UUID.dump!(artifact_id)],
        log: false
      )

    count
  end

  defp artifact!(owner, versions) do
    {:ok, %{artifact: artifact}} =
      Publisher.publish(owner, %{
        artifact_id: nil,
        base_version: 0,
        page: {:content, "v1"},
        via: :web
      })

    for n <- 2..versions//1 do
      {:ok, _} =
        Publisher.publish(owner, %{
          artifact_id: artifact.id,
          base_version: n - 1,
          page: {:content, "v#{n}"},
          via: :web
        })
    end

    artifact
  end

  defp finished_turn!(owner) do
    %{agent: agent} = Marshall.RunningThreadFixture.setup(owner)

    {:ok, %{turn_id: turn_id}} =
      Agents.submit_prompt(
        %{thread_id: agent.id, prompt: "work", request_key: Ash.UUID.generate()},
        actor: owner
      )

    {:ok, %{id: ^turn_id}} = TurnCoordinator.claim_next()
    {:ok, _} = TurnCoordinator.finish(turn_id, :completed, "done")
    %{"agent_thread_id" => agent.id, "turn_id" => turn_id}
  end
end
