defmodule Marshall.Threads.FeedAppendJob do
  @moduledoc "Appends a turn's `turn_finished` notification to its user thread's feed."
  use Oban.Worker,
    queue: :default,
    max_attempts: 10,
    unique: [period: :infinity, keys: [:agent_thread_id, :turn_id]]

  require Ash.Query
  require Marshall.Events
  alias Marshall.Agents.{ThreadFeed, ThreadNotification, Turn}
  alias Marshall.Authorization.SystemActor
  alias Marshall.Compute.Ledger
  alias Marshall.Threads.Thread

  @doc """
  Enqueues the feed append for a finished turn inside the caller's transaction.

  Only ordinary turns of a top-level agent thread are announced: child threads
  have no user thread, and maintenance turns (including subscription
  notifications) are skipped so mutually subscribed threads cannot wake each
  other indefinitely.
  """
  @spec enqueue!(Marshall.Agents.Thread.t(), Turn.t()) :: :ok
  def enqueue!(%{parent_thread_id: nil, id: thread_id}, %Turn{maintenance_kind: nil, id: turn_id}) do
    %{"agent_thread_id" => thread_id, "turn_id" => turn_id} |> new() |> Oban.insert!()
    :ok
  end

  def enqueue!(_thread, _turn), do: :ok

  # @cc [owner:ghuntley,label:durability;recovery] thread-feed-turn-finished-once
  # A committed terminal turn of a user-thread-bound agent MUST yield exactly one
  # `turn_finished` notification. The job is enqueued in the turn-finish
  # transaction and re-checks under the feed lock, so retries and duplicate
  # jobs append nothing more. Metadata MUST be the turn ID and closed outcome.
  @impl true
  @spec perform(Oban.Job.t()) :: :ok | {:cancel, :invalid_job}
  def perform(%Oban.Job{args: %{"agent_thread_id" => thread_id, "turn_id" => turn_id}})
      when is_binary(thread_id) and is_binary(turn_id) do
    if OverallsProtocol.uuid?(thread_id) and OverallsProtocol.uuid?(turn_id) do
      {:ok, outcome} = Ledger.transaction(fn -> append!(thread_id, turn_id) end, {:system, nil})

      if outcome == :appended,
        do: Marshall.Events.emit("thread.feed_appended", thread_id: thread_id, turn_id: turn_id)

      :ok
    else
      {:cancel, :invalid_job}
    end
  end

  def perform(%Oban.Job{}), do: {:cancel, :invalid_job}

  @spec append!(String.t(), String.t()) :: :appended | :duplicate | :unbound | :not_finished
  defp append!(thread_id, turn_id) do
    with [%Turn{thread_id: ^thread_id, status: status}] when status in [:completed, :failed] <-
           Ledger.read!(Turn, id: turn_id),
         [%Thread{} = user_thread] <- Ledger.history!(Thread, agent_thread_id: thread_id) do
      ThreadFeed.lock!(user_thread.id)

      if recorded?(user_thread.id, turn_id) do
        :duplicate
      else
        ThreadFeed.append_locked!(
          user_thread.id,
          thread_id,
          user_thread.creator_id,
          :turn_finished,
          %{
            "turn_id" => turn_id,
            "outcome" => Atom.to_string(status)
          }
        )

        :appended
      end
    else
      [%Turn{}] -> :not_finished
      _ -> :unbound
    end
  end

  @spec recorded?(String.t(), String.t()) :: boolean()
  defp recorded?(user_thread_id, turn_id) do
    ThreadNotification
    |> Ash.Query.filter(
      user_thread_id == ^user_thread_id and kind == :turn_finished and
        fragment("?->>'turn_id' = ?", metadata, ^turn_id)
    )
    |> Ash.Query.limit(1)
    |> Ash.read!(actor: SystemActor.compute())
    |> Kernel.!=([])
  end
end
