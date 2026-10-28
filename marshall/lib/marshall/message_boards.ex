defmodule Marshall.MessageBoards do
  @moduledoc "User/profile message boards with machine-scoped cleanup."
  require Ash.Query
  require Marshall.Events
  alias Marshall.Compute.Ledger
  alias Marshall.MessageBoards.{Board, Post}
  alias Marshall.Authorization.SystemActor

  @profiles [:standard, :oss]
  @max_body 65_536

  @type profile :: :standard | :oss
  @type post :: %{
          id: String.t(),
          board_id: String.t(),
          author_id: String.t(),
          body: String.t(),
          vm_id: String.t() | nil,
          thread_id: String.t() | nil,
          root_id: String.t()
        }

  @spec profiles() :: [profile()]
  def profiles, do: @profiles

  @spec list!(String.t(), profile()) :: [post()]
  def list!(user_id, profile) when is_binary(user_id) and profile in @profiles do
    if match?(
         %Marshall.Accounts.User{active: true, deleted_at: nil},
         Marshall.Accounts.Security.current(user_id)
       ) do
      board_id = ensure_board!(user_id, profile)

      Post
      |> Ash.Query.filter(board_id == ^board_id)
      |> Ash.Query.sort(inserted_at: :desc, id: :desc)
      |> Ash.Query.limit(100)
      |> Ash.read!(actor: SystemActor.compute())
      |> Enum.map(&project/1)
    else
      []
    end
  end

  @spec ensure_board!(String.t(), profile()) :: String.t()
  def ensure_board!(user_id, profile) when is_binary(user_id) and profile in @profiles do
    {:ok, id} =
      Ledger.transaction(fn ->
        Ecto.Adapters.SQL.query!(
          Marshall.Repo,
          "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
          ["message-board:#{user_id}:#{profile}"],
          log: false
        )

        case Ledger.read!(Board, user_id: user_id, profile: profile) do
          [board] -> board.id
          [] -> Ledger.create!(Board, :open, %{user_id: user_id, profile: profile}).id
        end
      end)

    id
  end

  @spec post!(String.t(), profile(), String.t(), String.t(), keyword()) ::
          {:ok, post()} | {:error, atom()}
  def post!(author_id, profile, request_key, body, opts \\ [])
      when is_binary(author_id) and profile in @profiles and is_binary(request_key) and
             is_binary(body) do
    if body == "" or byte_size(body) > @max_body,
      do: {:error, :invalid_body},
      else: do_post(author_id, profile, request_key, body, opts)
  end

  @spec purge_machine!(String.t()) :: non_neg_integer()
  def purge_machine!(vm_id), do: purge_for_state!(vm_id, :stopped)

  @spec purge_for_state!(String.t(), atom()) :: non_neg_integer()
  def purge_for_state!(vm_id, state) when state in [:paused, :stopped, :deleted] do
    {:ok, count} =
      Ledger.transaction(fn ->
        vm = Ledger.lock_history!(Marshall.Compute.VirtualMachine, vm_id)

        if vm && (vm.desired_state == state or vm.observed_state == state) do
          posts = Ledger.read!(Post, vm_id: vm_id)

          posts
          |> Enum.group_by(& &1.thread_id)
          |> Enum.each(fn {thread_id, group} ->
            if thread_id, do: append_cleanup!(thread_id, vm_id, state, length(group))
          end)

          Enum.each(posts, &Ledger.archive!(&1, :destroy))
          count = length(posts)

          Ledger.after_commit(fn ->
            Marshall.Events.emit("message_board.posts_purged",
              vm_id: vm_id,
              state: state,
              count: count
            )
          end)

          count
        else
          0
        end
      end)

    count
  end

  def purge_for_state!(_, _), do: 0

  # @cc [owner:ghuntley,label:durability] board-cleanup-notification-atomicity
  # Cleanup notifications and removed posts MUST commit together. User-thread IDs
  # MUST resolve to the retained agent binding, never be inserted as agent IDs.
  @spec append_cleanup!(String.t(), String.t(), atom(), pos_integer()) :: term()
  defp append_cleanup!(thread_id, vm_id, state, count) do
    case notification_target(thread_id, vm_id) do
      {id, owner} ->
        Marshall.Agents.ThreadFeed.append_locked!(thread_id, id, owner, :machine_purged, %{
          state: Atom.to_string(state),
          vm_id: vm_id,
          count: count
        })

      _ ->
        :ok
    end
  end

  @spec notification_target(String.t(), String.t()) :: {String.t(), String.t()} | nil
  defp notification_target(thread_id, vm_id) do
    case Ledger.history!(Marshall.Threads.Thread, id: thread_id) do
      [thread] ->
        binding =
          if thread.machine_id == vm_id do
            thread.agent_thread_id
          else
            case Ledger.read!(Marshall.Threads.Generation,
                   thread_id: thread_id,
                   machine_id: vm_id
                 ) do
              [generation] -> generation.agent_thread_id
              _ -> nil
            end
          end

        if is_binary(binding), do: {binding, thread.creator_id}

      _ ->
        nil
    end
  end

  @spec purge_thread!(String.t()) :: non_neg_integer()
  def purge_thread!(thread_id) do
    {:ok, count} =
      Ledger.transaction(fn ->
        posts = Ledger.read!(Post, thread_id: thread_id)
        Enum.each(posts, &Ledger.archive!(&1, :destroy))
        length(posts)
      end)

    count
  end

  @spec do_post(String.t(), profile(), String.t(), String.t(), keyword()) ::
          {:ok, post()} | {:error, atom()}
  defp do_post(author_id, profile, request_key, body, opts) do
    {:ok, %{result: result}} =
      Ledger.transaction(fn ->
        result =
          with :ok <- authorize_post(author_id, profile, opts) do
            board_id = ensure_board!(author_id, profile)

            case Ledger.read!(Post,
                   board_id: board_id,
                   author_id: author_id,
                   request_key: request_key
                 ) do
              [row] ->
                if row.body == body and row.vm_id == opts[:vm_id] and
                     row.thread_id == opts[:thread_id],
                   do: {:ok, project(row)},
                   else: {:error, :request_key_conflict}

              [] ->
                row =
                  Ledger.create!(Post, :post, %{
                    board_id: board_id,
                    author_id: author_id,
                    request_key: request_key,
                    body: body,
                    vm_id: opts[:vm_id],
                    thread_id: opts[:thread_id],
                    root_id: opts[:root_id] || Ecto.UUID.generate()
                  })

                {:ok, project(row)}
            end
          end

        %{result: result}
      end)

    result
  end

  # @cc [owner:ghuntley,label:security] board-post-current-authority
  # Machine-tagged posts MUST require current VM write authority, matching profile
  # and running intent/observation. Thread links MUST require current write access
  # and match the tagged machine. Acquire thread authority before the VM lock.
  @spec authorize_post(String.t(), profile(), keyword()) :: :ok | {:error, :forbidden}
  defp authorize_post(actor_id, profile, opts) do
    actor = Marshall.Accounts.Security.current(actor_id)

    thread_ok =
      case opts[:thread_id] do
        nil ->
          true

        id ->
          case Ledger.lock_history!(Marshall.Threads.Thread, id) do
            nil ->
              false

            thread ->
              Marshall.Threads.Authorization.allowed?(thread, actor, "write") and
                (is_nil(opts[:vm_id]) or thread.machine_id == opts[:vm_id])
          end
      end

    vm_ok =
      case opts[:vm_id] do
        nil ->
          true

        id ->
          case Ledger.lock_history!(Marshall.Compute.VirtualMachine, id) do
            %{
              archived_at: nil,
              profile: ^profile,
              desired_state: :running,
              observed_state: :running
            } = vm ->
              Marshall.Access.Authorization.allowed?(vm, actor, "write")

            _ ->
              false
          end
      end

    if match?(%Marshall.Accounts.User{active: true, deleted_at: nil}, actor) and thread_ok and
         vm_ok, do: :ok, else: {:error, :forbidden}
  end

  @spec project(Post.t()) :: post()
  defp project(row),
    do: Map.take(row, [:id, :board_id, :author_id, :body, :vm_id, :thread_id, :root_id])
end
