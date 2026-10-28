defmodule Marshall.Threads.Sharing do
  @moduledoc "Audited thread sharing with the existing machine access role semantics."
  use Ash.Resource.Actions.Implementation
  alias Marshall.Accounts.User
  alias Marshall.Authorization.SystemActor
  alias Marshall.Compute.{Ledger, VirtualMachine}
  alias Marshall.Threads.{AccessChange, Authorization, Grant, Thread}
  require Ash.Query
  require Marshall.Events

  @impl true
  @spec run(Ash.ActionInput.t(), keyword(), map()) :: {:ok, term()} | {:error, term()}
  def run(input, options, %{actor: %User{} = actor}) do
    result =
      Ledger.transaction(
        fn ->
          thread = lock_thread!(input.arguments.thread_id)
          Authorization.require!(thread, actor, "manage")

          if options[:operation] == :list do
            list(thread, input.arguments)
          else
            lock_machine!(thread)
            Authorization.require!(thread, actor, "manage")
            change(thread, actor, input.arguments)
          end
        end,
        actor
      )

    case result do
      {:error, reason} when is_atom(reason) ->
        {:error, Marshall.Compute.Error.exception(reason: reason)}

      other ->
        other
    end
  end

  def run(_, _, _), do: {:error, :forbidden}

  # @cc [owner:ghuntley,label:security;recovery] thread-sharing-immutable-result
  # Sharing MUST resolve an existing nondeleted account by exact email only after
  # current manage authorization, preserve the creator's ownership, and serialize
  # on thread then bound VM. Replaying a matching receipt MUST return it without
  # restoring revoked grants; changed recipient or role MUST conflict.
  @spec change(Thread.t(), User.t(), map()) :: AccessChange.t()
  defp change(thread, actor, request) do
    if request.role != :revoked and not Authorization.shareable?(thread),
      do: Ledger.rollback(:sharing_not_allowed)

    user =
      User
      |> Ash.Query.for_read(:internal_lookup)
      |> Ash.Query.filter(email == ^request.email and is_nil(deleted_at) and active == true)
      |> Ash.read_one!(actor: SystemActor.compute())

    if is_nil(user), do: Ledger.rollback(:recipient_not_registered)
    if user.id == thread.creator_id, do: Ledger.rollback(:owner_protected)

    case Ledger.read!(AccessChange,
           thread_id: thread.id,
           requested_by_id: actor.id,
           request_key: request.idempotency_key
         ) do
      [existing] ->
        if existing.user_id == user.id and existing.role == request.role,
          do: existing,
          else: Ledger.rollback(:idempotency_conflict)

      [] ->
        grant = replace(thread.id, user.id, actor.id, request.role)
        Marshall.Threads.SubscriptionRevokeJob.enqueue_thread!(thread.id)

        receipt =
          Ledger.create!(AccessChange, :record, %{
            thread_id: thread.id,
            user_id: user.id,
            requested_by_id: actor.id,
            role: request.role,
            request_key: request.idempotency_key,
            grant_id: if(grant, do: grant.id)
          })

        Ledger.after_commit(fn ->
          Marshall.Events.emit("thread.access_changed", thread_id: thread.id, user_id: user.id)
        end)

        receipt
    end
  end

  @spec replace(String.t(), String.t(), String.t(), atom()) :: Grant.t() | nil
  defp replace(thread_id, user_id, actor_id, role) do
    current = List.first(Ledger.read!(Grant, thread_id: thread_id, user_id: user_id))

    if current && current.role == role do
      current
    else
      if current do
        current
        |> Ledger.update!(:mark_revoked, %{revoked_by_id: actor_id})
        |> Ledger.archive!(:revoke)
      end

      if role != :revoked do
        Ledger.create!(Grant, :grant, %{
          thread_id: thread_id,
          user_id: user_id,
          role: role,
          granted_by_id: actor_id
        })
      end
    end
  end

  @spec list(Thread.t(), map()) :: map()
  defp list(thread, request) do
    query =
      Grant
      |> Ash.Query.filter(thread_id == ^thread.id)
      |> Ash.Query.sort(:id)
      |> Ash.Query.limit(request.limit + 1)

    query =
      if Map.get(request, :after), do: Ash.Query.filter(query, id > ^request.after), else: query

    rows = Ash.read!(query, actor: SystemActor.compute())
    grants = Enum.take(rows, request.limit)
    ids = [thread.creator_id | Enum.map(grants, & &1.user_id)]

    users =
      User
      |> Ash.Query.for_read(:internal_lookup)
      |> Ash.Query.filter(id in ^ids)
      |> Ash.read!(actor: SystemActor.compute())
      |> Map.new(&{&1.id, &1})

    %{
      owner: person(thread.creator_id, users) |> Map.put(:role, :owner),
      items: Enum.map(grants, &Map.merge(person(&1.user_id, users), %{id: &1.id, role: &1.role})),
      next_cursor: if(length(rows) > request.limit, do: List.last(grants).id)
    }
  end

  # Participants carry their saved zone (ADR-0195) for the sharing panel's
  # local-time line; nil means nothing is shown for that person.
  @spec person(String.t(), %{String.t() => User.t()}) :: %{
          user_id: String.t(),
          email: String.t() | nil,
          time_zone: String.t() | nil
        }
  defp person(user_id, users) do
    user = users[user_id]
    %{user_id: user_id, email: user && to_string(user.email), time_zone: user && user.time_zone}
  end

  @spec lock_machine!(Thread.t()) :: :ok
  defp lock_machine!(%Thread{machine_id: nil}), do: :ok

  # @cc [owner:ghuntley,label:concurrency] thread-share-lock-order
  # Sharing MUST lock the retained thread before its current VM. It MUST NOT
  # acquire host locks afterward or require a running VM to change retained ACLs.
  defp lock_machine!(thread) do
    vm =
      VirtualMachine
      |> Ash.Query.for_read(:history, %{}, actor: SystemActor.compute())
      |> Ash.Query.filter(id == ^thread.machine_id)
      |> Ash.Query.lock(:for_update)
      |> Ash.read_one!()

    unless vm && vm.owner_id == thread.creator_id,
      do: Ledger.rollback(:machine_unavailable)

    :ok
  end

  @spec lock_thread!(String.t()) :: Thread.t()
  defp lock_thread!(id) do
    Thread
    |> Ash.Query.for_read(:history, %{}, actor: SystemActor.compute())
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one!() || Ledger.rollback(:not_found)
  end

  @doc "Resolves the current VM for a commit-gated sharing invalidation hint."
  @spec machine_id(Grant.t()) :: String.t() | nil
  def machine_id(%Grant{thread_id: id}) do
    case Ledger.history!(Thread, id: id) do
      [thread] -> thread.machine_id
      [] -> nil
    end
  end
end
