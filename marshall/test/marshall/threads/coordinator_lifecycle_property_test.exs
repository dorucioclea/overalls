defmodule Marshall.Threads.CoordinatorLifecyclePropertyTest do
  # @cc [owner:ghuntley,label:verification;durability] thread-coordinator-lifecycle-model
  # Generated archive, reopen, retry and provisioning-failure histories driven
  # through the public thread interfaces MUST match the pre-state-machine
  # coordinator model: archiving is idempotent for archived threads, reopen is
  # accepted only from archived and opens the next generation, retry is
  # accepted only from failed or pending, refusals change nothing, and every
  # accepted reopen enqueues one provisioning job for its fresh machine key
  # while a retry reuses the unique pending job for the current key.
  use Marshall.DataCase, async: false
  import Hegel
  import Hegel.Gen
  import Marshall.ComputeFixtures, only: [user: 0, request: 0]

  alias Marshall.Compute.Ledger
  alias Marshall.Threads
  alias Marshall.Threads.{Generation, ProvisionWorker, Thread}

  @tag :hegel_case_sandbox
  @tag timeout: 900_000
  property "public lifecycle operations follow the coordinator model", test_cases: 25 do
    Marshall.DataCase.isolate_property_case()
    actor = user()

    {:ok, thread} =
      Threads.create_thread(
        %{
          objective: "Lifecycle property",
          mode: :medium,
          machine_spec: request(),
          idempotency_key: Ash.UUID.generate()
        },
        actor: actor
      )

    steps =
      draw(
        "steps",
        list_of(member_of([:archive, :reopen, :retry, :fail]), min_length: 1, max_length: 12)
      )

    initial = %{status: :pending, generations: 1, jobs: 1}
    assert snapshot(thread) == initial

    Enum.reduce(steps, initial, fn op, model ->
      expected = apply_model(op, model)
      result = run(op, thread, actor)

      assert match?({:ok, _}, result) == (expected != :refused),
             "#{op} from #{model.status}: #{inspect(result)}"

      model = if expected == :refused, do: model, else: expected
      assert snapshot(thread) == model
      model
    end)
  end

  defp apply_model(:archive, %{status: :archived} = model), do: model
  defp apply_model(:archive, model), do: %{model | status: :archived}

  defp apply_model(:reopen, %{status: :archived} = model),
    do: %{model | status: :pending, generations: model.generations + 1, jobs: model.jobs + 1}

  defp apply_model(:reopen, _model), do: :refused

  defp apply_model(:retry, %{status: status} = model) when status in [:failed, :pending],
    do: %{model | status: :pending}

  defp apply_model(:retry, _model), do: :refused

  defp apply_model(:fail, %{status: status} = model) when status in [:pending, :failed],
    do: %{model | status: :failed}

  defp apply_model(:fail, _model), do: :refused

  defp run(:archive, thread, actor),
    do: Threads.archive_thread(%{thread_id: thread.id}, actor: actor)

  defp run(:reopen, thread, actor),
    do: Threads.reopen_thread(%{thread_id: thread.id}, actor: actor)

  defp run(:retry, thread, actor),
    do: Threads.retry_provisioning(%{thread_id: thread.id}, actor: actor)

  defp run(:fail, thread, _actor) do
    Ledger.transaction(fn ->
      current = Ledger.lock_history!(Thread, thread.id)

      try do
        Ledger.update!(current, :mark_failed, %{failure_reason: :provision_failed})
      rescue
        _ -> Ledger.rollback(:refused)
      end
    end)
  end

  defp snapshot(thread) do
    [current] = Ledger.history!(Thread, id: thread.id)

    jobs =
      [repo: Marshall.Repo, worker: ProvisionWorker]
      |> Oban.Testing.all_enqueued()
      |> Enum.count(&(&1.args["thread_id"] == thread.id))

    %{
      status: current.status,
      generations: length(Ledger.read!(Generation, thread_id: thread.id)),
      jobs: jobs
    }
  end
end
