defmodule Marshall.Agents.ThreadDelivery do
  @moduledoc "Durable, permission-checked notification delivery to agent turn queues."
  use GenServer
  require Ash.Query
  require Marshall.Events

  alias Marshall.Agents.{
    Command,
    Root,
    Thread,
    ThreadNotification,
    ThreadReceiver,
    ThreadSubscription
  }

  alias Marshall.Compute.{Ledger, VirtualMachine}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options), do: GenServer.start_link(__MODULE__, options, name: __MODULE__)
  @impl true
  def init(_options) do
    send(self(), :poll)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    try do
      deliver_one()
    rescue
      _ -> Marshall.Events.emit("agent.notification_poll_failed", reason: :exception)
    end

    Process.send_after(self(), :poll, 1000)
    {:noreply, state}
  end

  # @cc [owner:ghuntley,label:security] subscription-receiver-derived-source
  # Only the currently authorized command supplies a destination. Root agents
  # follow their durable user thread; children and ordinary machines retain
  # their exact agent thread. One receiver's unsubscribe MUST NOT disable peers.
  @spec register(Command.t(), String.t(), String.t(), boolean()) ::
          {:ok, map()} | {:error, atom()}
  def register(command, actor_id, target_id, active) when is_boolean(active) do
    with true <- OverallsProtocol.uuid?(target_id) and OverallsProtocol.uuid?(actor_id),
         existing <-
           Ledger.read!(ThreadSubscription, owner_id: actor_id, user_thread_id: target_id),
         parent_active <- active or Enum.any?(existing, &(&1.state == :active)),
         {:ok, _} <- Marshall.Agents.ThreadTool.subscribe(actor_id, target_id, parent_active),
         [subscription] <-
           Ledger.read!(ThreadSubscription, owner_id: actor_id, user_thread_id: target_id),
         [source] <- Ledger.read!(Thread, id: command.thread_id) do
      target = Marshall.Agents.MessageBoardTool.target(command)

      {kind, id} =
        if target && is_nil(source.parent_thread_id),
          do: {:user_thread, target.id},
          else: {:agent_thread, source.id}

      case Ledger.read!(ThreadReceiver,
             subscription_id: subscription.id,
             destination_kind: kind,
             destination_id: id
           ) do
        [] ->
          Ledger.create!(ThreadReceiver, :register, %{
            subscription_id: subscription.id,
            destination_kind: kind,
            destination_id: id,
            state: if(active, do: :active, else: :inactive)
          })

        [receiver] ->
          Ledger.update!(receiver, if(active, do: :activate, else: :deactivate), %{})
      end

      {:ok, %{thread_id: target_id, active: active}}
    else
      _ -> {:error, :forbidden}
    end
  end

  def register(_, _, _, _), do: {:error, :invalid_arguments}

  @spec replay(Command.t(), String.t(), map()) :: {:ok, [map()]} | {:error, atom()}
  def replay(command, actor_id, args) do
    with true <- OverallsProtocol.uuid?(args["thread_id"]),
         [source] <- Ledger.read!(Thread, id: command.thread_id),
         [subscription] <-
           Ledger.read!(ThreadSubscription, owner_id: actor_id, user_thread_id: args["thread_id"]) do
      target = Marshall.Agents.MessageBoardTool.target(command)

      {kind, id} =
        if target && is_nil(source.parent_thread_id),
          do: {:user_thread, target.id},
          else: {:agent_thread, source.id}

      case Ledger.read!(ThreadReceiver,
             subscription_id: subscription.id,
             destination_kind: kind,
             destination_id: id,
             state: :active
           ) do
        [_] ->
          Marshall.Agents.ThreadTool.replay(
            actor_id,
            args["thread_id"],
            Map.get(args, "cursor", 0),
            Map.get(args, "limit", 100)
          )

        [] ->
          {:error, :not_subscribed}
      end
    else
      _ -> {:error, :not_subscribed}
    end
  end

  # @cc [owner:ghuntley,label:security;durability] subscription-delivery-atomic
  # Delivery MUST recheck target read and destination write authority, and commit
  # one notification turn with its cursor acknowledgement. Stopped destinations
  # MUST defer without waking. Permission loss MUST deactivate delivery.
  @spec deliver_one() :: {:ok, term()} | {:error, term()}
  def deliver_one do
    Ledger.transaction(fn ->
      %{rows: rows} =
        Ecto.Adapters.SQL.query!(
          Marshall.Repo,
          """
          SELECT r.id FROM agent_thread_receivers r
          JOIN agent_thread_tool_subscriptions s ON s.id = r.subscription_id
          WHERE r.state = 'active' AND s.state = 'active'
            AND (r.next_attempt_at IS NULL OR r.next_attempt_at <= now())
            AND EXISTS (SELECT 1 FROM agent_thread_tool_events e
                        WHERE e.user_thread_id = s.user_thread_id AND e.sequence > r.cursor)
          ORDER BY r.next_attempt_at NULLS FIRST, r.inserted_at, r.id LIMIT 1
          """,
          [],
          log: false
        )

      case rows do
        [[id]] -> deliver_locked(Ecto.UUID.load!(id))
        [] -> :idle
      end
    end)
  end

  @spec deliver_locked(String.t()) :: term()
  defp deliver_locked(id) do
    [candidate] = Ledger.read!(ThreadReceiver, id: id)
    [subscription] = Ledger.read!(ThreadSubscription, id: candidate.subscription_id)
    source_id = source_user_id(candidate)

    [subscription.user_thread_id, source_id]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.each(&Ledger.lock_history!(Marshall.Threads.Thread, &1))

    [subscription] = Ledger.read!(ThreadSubscription, id: subscription.id)
    actor = Marshall.Accounts.Security.current(subscription.owner_id)
    target = Ledger.lock_history!(Marshall.Threads.Thread, subscription.user_thread_id)
    source_user = if source_id, do: Ledger.lock_history!(Marshall.Threads.Thread, source_id)
    source = destination(candidate)
    root = if source, do: List.first(Ledger.read!(Root, id: source.root_id))
    vm = if root, do: Ledger.lock!(VirtualMachine, root.vm_id)
    receiver = Ledger.lock!(ThreadReceiver, id)

    cond do
      receiver.state != :active or subscription.state != :active ->
        :inactive

      not match?(%Marshall.Accounts.User{active: true, deleted_at: nil}, actor) or
        is_nil(target) or not Marshall.Threads.Authorization.allowed?(target, actor, "read") ->
        Ledger.update!(receiver, :deactivate, %{})

      is_nil(source) or is_nil(vm) ->
        defer(receiver)

      source_user && not Marshall.Threads.Authorization.allowed?(source_user, actor, "write") ->
        Ledger.update!(receiver, :deactivate, %{})

      not Marshall.Access.Authorization.allowed?(vm, actor, "write") ->
        Ledger.update!(receiver, :deactivate, %{})

      vm.desired_state != :running or vm.observed_state != :running ->
        defer(receiver)

      true ->
        admit(receiver, subscription, source, actor)
    end
  end

  @spec source_user_id(ThreadReceiver.t()) :: String.t() | nil
  defp source_user_id(%{destination_kind: :user_thread, destination_id: id}), do: id

  defp source_user_id(%{destination_kind: :agent_thread, destination_id: id}) do
    with [agent] <- Ledger.read!(Thread, id: id),
         [thread] <- Ledger.read!(Marshall.Threads.Thread, agent_root_id: agent.root_id) do
      thread.id
    else
      _ -> nil
    end
  end

  @spec destination(ThreadReceiver.t()) :: Thread.t() | nil
  defp destination(%{destination_kind: :agent_thread, destination_id: id}),
    do: Ledger.lock!(Thread, id)

  defp destination(%{destination_kind: :user_thread, destination_id: id}) do
    case Ledger.lock_history!(Marshall.Threads.Thread, id) do
      %{agent_thread_id: agent_id} when is_binary(agent_id) -> Ledger.lock!(Thread, agent_id)
      _ -> nil
    end
  end

  @spec defer(ThreadReceiver.t()) :: ThreadReceiver.t()
  defp defer(receiver),
    do:
      Ledger.update!(receiver, :defer, %{next_attempt_at: DateTime.add(Ledger.now(), 5, :second)})

  @spec admit(ThreadReceiver.t(), ThreadSubscription.t(), Thread.t(), Marshall.Accounts.User.t()) ::
          term()
  defp admit(receiver, subscription, source, actor) do
    events =
      ThreadNotification
      |> Ash.Query.filter(
        user_thread_id == ^subscription.user_thread_id and sequence > ^receiver.cursor
      )
      |> Ash.Query.sort(sequence: :asc)
      |> Ash.Query.limit(1)
      |> Ash.read!(actor: Marshall.Authorization.SystemActor.compute())

    case events do
      [] ->
        :idle

      [event] ->
        metadata = %{
          "thread_id" => subscription.user_thread_id,
          "notification_id" => event.id,
          "sequence" => event.sequence,
          "kind" => Atom.to_string(event.kind)
        }

        key = "subscription:" <> receiver.id <> ":" <> Integer.to_string(event.sequence)

        case Marshall.Agents.Prompt.maintenance(source.id, :subscription_notification, metadata,
               actor: actor,
               request_key: key
             ) do
          {:ok, _} ->
            Ledger.update!(receiver, :acknowledge, %{cursor: event.sequence, next_attempt_at: nil})

          {:error, _} ->
            defer(receiver)
        end
    end
  end
end
