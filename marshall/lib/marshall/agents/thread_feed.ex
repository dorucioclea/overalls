defmodule Marshall.Agents.ThreadFeed do
  @moduledoc "Dense per-user-thread sequencing for content-free thread notifications."
  require Ash.Query
  alias Marshall.Agents.ThreadNotification
  alias Marshall.Authorization.SystemActor
  alias Marshall.Compute.Ledger

  @type kind :: :machine_purged | :turn_finished

  # @cc [owner:ghuntley,label:durability;concurrency] thread-feed-dense-sequence
  # Appends MUST run inside the caller's transaction, serialize on the user
  # thread's advisory lock and take the next dense sequence, so replay cursors
  # never skip or reuse a position. Metadata MUST stay content-free.
  @spec append_locked!(String.t(), String.t(), String.t(), kind(), map()) ::
          ThreadNotification.t()
  def append_locked!(user_thread_id, agent_thread_id, owner_id, kind, metadata) do
    lock!(user_thread_id)

    sequence =
      case latest(user_thread_id) do
        nil -> 1
        event -> event.sequence + 1
      end

    Ledger.create!(ThreadNotification, :append, %{
      thread_id: agent_thread_id,
      user_thread_id: user_thread_id,
      owner_id: owner_id,
      sequence: sequence,
      kind: kind,
      metadata: metadata
    })
  end

  @doc "Takes the user thread's feed lock for the rest of the current transaction."
  @spec lock!(String.t()) :: :ok
  def lock!(user_thread_id) do
    Ecto.Adapters.SQL.query!(
      Marshall.Repo,
      "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
      ["thread-notification:#{user_thread_id}"],
      log: false
    )

    :ok
  end

  @spec latest(String.t()) :: ThreadNotification.t() | nil
  defp latest(user_thread_id) do
    ThreadNotification
    |> Ash.Query.filter(user_thread_id == ^user_thread_id)
    |> Ash.Query.sort(sequence: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read!(actor: SystemActor.compute())
    |> List.first()
  end
end
