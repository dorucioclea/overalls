defmodule Marshall.Threads.SubscriptionRevokeJob do
  @moduledoc "Re-evaluates thread subscriptions after an authority change and revokes lost ones."
  use Oban.Worker,
    queue: :default,
    max_attempts: 10,
    unique: [
      period: :infinity,
      keys: [:thread_id, :owner_id],
      states: [:available, :scheduled, :retryable]
    ]

  import Ecto.Query
  require Marshall.Events
  alias Marshall.Accounts.{Security, User}
  alias Marshall.Agents.{AuditEvent, Root, ThreadReceiver, ThreadSubscription}
  alias Marshall.Compute.Ledger
  alias Marshall.Threads.{Authorization, Thread}

  @batch 200

  @doc "Enqueues a review of every subscription to `thread_id` inside the caller's transaction."
  @spec enqueue_thread!(String.t()) :: :ok
  def enqueue_thread!(thread_id) do
    %{"thread_id" => thread_id} |> new() |> Oban.insert!()
    :ok
  end

  @doc "Enqueues a review of every subscription owned by `user_id` inside the caller's transaction."
  @spec enqueue_owner!(String.t()) :: :ok
  def enqueue_owner!(user_id) do
    %{"owner_id" => user_id} |> new() |> Oban.insert!()
    :ok
  end

  # @cc [owner:ghuntley,label:security;recovery] thread-subscription-revocation
  # Every grant, team-membership or account change that can remove thread read
  # authority MUST enqueue this review in its own transaction. The review MUST
  # recheck current Cedar read under the user-thread lock, revoke only lost
  # subscriptions, deactivate their receivers and commit one audit row each.
  # Re-running is harmless; jobs carry IDs only.
  @impl true
  @spec perform(Oban.Job.t()) :: :ok | {:cancel, :invalid_job}
  def perform(%Oban.Job{args: args}) do
    case scope(args) do
      {:ok, column, id} ->
        {checked, revoked} = review_pages(column, id, nil, 0, 0)

        Marshall.Events.emit("thread.subscriptions_reviewed", checked: checked, revoked: revoked)
        :ok

      :error ->
        {:cancel, :invalid_job}
    end
  end

  @spec scope(map()) :: {:ok, :user_thread_id | :owner_id, String.t()} | :error
  defp scope(%{"thread_id" => id} = args) when map_size(args) == 1 and is_binary(id),
    do: if(OverallsProtocol.uuid?(id), do: {:ok, :user_thread_id, id}, else: :error)

  defp scope(%{"owner_id" => id} = args) when map_size(args) == 1 and is_binary(id),
    do: if(OverallsProtocol.uuid?(id), do: {:ok, :owner_id, id}, else: :error)

  defp scope(_), do: :error

  @spec review_pages(atom(), String.t(), String.t() | nil, non_neg_integer(), non_neg_integer()) ::
          {non_neg_integer(), non_neg_integer()}
  defp review_pages(column, id, cursor, checked, revoked) do
    case page(column, id, cursor) do
      [] ->
        {checked, revoked}

      ids ->
        revoked =
          revoked +
            Enum.count(ids, fn subscription_id ->
              {:ok, outcome} =
                Ledger.transaction(fn -> review!(subscription_id) end, {:system, nil})

              outcome == :revoked
            end)

        review_pages(column, id, List.last(ids), checked + length(ids), revoked)
    end
  end

  @spec page(atom(), String.t(), String.t() | nil) :: [String.t()]
  defp page(column, id, cursor) do
    uuid = Ecto.UUID.dump!(id)

    query =
      from(s in "agent_thread_tool_subscriptions",
        where: field(s, ^column) == ^uuid and s.state in ["active", "inactive"],
        order_by: [asc: s.id],
        limit: @batch,
        select: type(s.id, :binary_id)
      )

    query = if cursor, do: where(query, [s], s.id > type(^cursor, :binary_id)), else: query
    Marshall.Repo.all(query)
  end

  @spec review!(String.t()) :: :revoked | :kept
  defp review!(subscription_id) do
    with [subscription] <- Ledger.read!(ThreadSubscription, id: subscription_id),
         target = Ledger.lock_history!(Thread, subscription.user_thread_id),
         %ThreadSubscription{state: state} = subscription when state != :revoked <-
           Ledger.lock!(ThreadSubscription, subscription_id) do
      if authorized?(target, subscription.owner_id) do
        :kept
      else
        revoke!(subscription)
      end
    else
      _ -> :kept
    end
  end

  @spec authorized?(Thread.t() | nil, String.t()) :: boolean()
  defp authorized?(nil, _owner_id), do: false

  defp authorized?(target, owner_id) do
    case Security.current(owner_id) do
      %User{active: true, deleted_at: nil} = actor ->
        Authorization.allowed?(target, actor, "read")

      _ ->
        false
    end
  end

  @spec revoke!(ThreadSubscription.t()) :: :revoked
  defp revoke!(subscription) do
    Ledger.update!(subscription, :revoke, %{})

    ThreadReceiver
    |> Ledger.read!(subscription_id: subscription.id)
    |> Enum.filter(&(&1.state == :active))
    |> Enum.each(&Ledger.update!(&1, :deactivate, %{}))

    with [agent] <- Ledger.read!(Marshall.Agents.Thread, id: subscription.thread_id),
         [root] <- Ledger.read!(Root, id: agent.root_id) do
      Ledger.create!(AuditEvent, :record, %{
        vm_id: root.vm_id,
        thread_id: agent.id,
        actor_id: subscription.owner_id,
        kind: :thread_subscription_revoked,
        target_id: subscription.id,
        outcome: :completed
      })
    end

    Ledger.after_commit(fn ->
      Marshall.Events.emit("thread.subscription_revoked",
        subscription_id: subscription.id,
        thread_id: subscription.user_thread_id,
        user_id: subscription.owner_id
      )
    end)

    :revoked
  end
end
