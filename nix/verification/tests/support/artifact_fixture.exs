# @cc [owner:ghuntley,label:verification;security] artifact-machine-fixture-real-actions
# Machine-test artifact and thread fixtures MUST publish, share, write storage
# and issue valid tickets through Marshall's real authorized actions as the
# named user. Only refusal-ticket shapes (expired, revoked, missing version,
# unauthorized holder) are written directly, because no authorized action can
# produce them; the content endpoint MUST still refuse each one. This file is
# loaded only by disposable machine-test eval scripts, never by the release.
defmodule ArtifactMachineFixture do
  alias Marshall.Accounts.{Security, User}

  alias Marshall.Artifacts.{
    Artifact,
    AuditEvent,
    Library,
    Publisher,
    Sharing,
    Storage,
    ViewTicket
  }

  alias Marshall.Compute.Ledger

  @type artifact_ref :: %{id: String.t(), version: pos_integer()}

  @spec user!(String.t()) :: User.t()
  defp user!(id), do: %User{} = Security.current(id)

  @spec seed_artifact!(%{
          owner_id: String.t(),
          title: String.t(),
          entry: String.t(),
          files: %{String.t() => binary()}
        }) :: artifact_ref()
  def seed_artifact!(%{owner_id: owner, title: title, entry: "index.html", files: files}) do
    {page, rest} = Map.pop!(files, "index.html")

    {:ok, %{artifact: artifact, version: version}} =
      Publisher.publish(user!(owner), %{
        artifact_id: nil,
        base_version: 0,
        page: {:content, page},
        title: title,
        files: Map.new(rest, fn {path, bytes} -> {path, {:bytes, bytes, nil}} end),
        via: :web
      })

    %{id: artifact.id, version: version.number}
  end

  @spec issue_ticket!(artifact_ref(), keyword()) :: String.t()
  def issue_ticket!(%{id: id, version: version}, options) do
    user = user!(Keyword.fetch!(options, :user_id))

    host =
      MarshallWeb.ArtifactContentEndpoint.config().host ||
        System.fetch_env!("MARSHALL_ARTIFACT_CONTENT_HOST")

    [artifact] = Ledger.read!(Artifact, id: id)

    refusal? =
      Keyword.has_key?(options, :expires_in) or Keyword.get(options, :revoked, false) or
        Keyword.get(options, :version, version) != version or
        not Marshall.Artifacts.Authorization.allowed?(artifact, user, :read)

    if refusal? do
      forged!(artifact, user, host, options, version)
    else
      {:ok, version_row} = Library.version(artifact, version)
      {:ok, token} = Marshall.Artifacts.Tickets.issue(user, artifact, version_row, host)
      token
    end
  end

  @spec forged!(Artifact.t(), User.t(), String.t(), keyword(), pos_integer()) :: String.t()
  defp forged!(artifact, user, host, options, version) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    lifetime = Keyword.get(options, :expires_in, 300)

    {:ok, _} =
      Ledger.transaction(
        fn ->
          ticket =
            Ledger.create!(ViewTicket, :issue, %{
              token_hash: :crypto.hash(:sha256, token),
              artifact_id: artifact.id,
              version_number: Keyword.get(options, :version, version),
              user_id: user.id,
              content_host: host,
              expires_at: DateTime.add(Ledger.now(), lifetime, :second)
            })

          if Keyword.get(options, :revoked, false), do: Ledger.update!(ticket, :revoke, %{})
          :ok
        end,
        {:system, nil}
      )

    token
  end

  @spec share!(String.t(), String.t(), String.t(), :viewer | :writer | :revoked) :: :ok
  def share!(artifact_id, owner_id, user_id, role) do
    {:ok, _} =
      Sharing.set_access(
        user!(owner_id),
        artifact_id,
        {:email, to_string(user!(user_id).email)},
        role,
        Ash.UUID.generate()
      )

    :ok
  end

  @spec storage_write(String.t(), String.t(), :shared | :personal, String.t(), String.t()) ::
          :ok | {:error, atom()}
  def storage_write(artifact_id, user_id, namespace, key, value),
    do: Storage.put(user!(user_id), artifact_id, namespace, key, value)

  @doc "Writes `count` small personal entries as the owner so a purge needs several steps."
  @spec fill_storage!(String.t(), String.t(), pos_integer()) :: :ok
  def fill_storage!(artifact_id, owner_id, count) when count in 1..5_000 do
    Enum.each(1..count, fn n ->
      :ok = Storage.put(user!(owner_id), artifact_id, :personal, "entry-#{n}", "1")
    end)
  end

  @doc "Deletes through the owner's authorized action; the purge job is enqueued with it."
  @spec delete!(String.t(), String.t()) :: :ok
  def delete!(artifact_id, owner_id) do
    {:ok, %Artifact{state: :deleting}} = Library.delete(user!(owner_id), artifact_id, :web)
    :ok
  end

  @doc "Runs exactly one purge step, as a worker would before being interrupted."
  @spec purge_step!(String.t()) :: :ok
  def purge_step!(artifact_id) do
    :ok = Marshall.Artifacts.PurgeJob.perform(%Oban.Job{args: %{"artifact_id" => artifact_id}})
  end

  @spec state!(String.t()) :: %{
          current_version: non_neg_integer(),
          versions: non_neg_integer(),
          file_sha256: %{String.t() => String.t()},
          audit_kinds: [atom()]
        }
  def state!(artifact_id) do
    [artifact] = Ledger.read!(Artifact, id: artifact_id)
    {:ok, current} = Library.version(artifact, artifact.current_version)

    %{
      current_version: artifact.current_version,
      versions: length(Library.versions(artifact)),
      file_sha256: Map.new(Library.files(current), &{&1.path, &1.sha256}),
      audit_kinds: Ledger.read!(AuditEvent, artifact_id: artifact_id) |> Enum.map(& &1.kind)
    }
  end
end

defmodule ThreadMachineFixture do
  alias Marshall.Accounts.Security
  alias Marshall.Compute.Ledger

  # A thread row without provisioning: the thread tool reads it through Cedar,
  # so sharing goes through the real set_access action as its creator. With
  # `bind_vm_id`, the thread becomes that machine's user thread (the machine
  # MUST belong to the thread owner) bound to a child agent thread of its root,
  # which is the retained binding ADR-0252 reads, subscribes to and replays.
  # Readers of a bound thread get `operator`, because a root named by a user
  # thread admits prompts only from that thread's writers.
  @spec seed_thread!(%{
          owner_id: String.t(),
          title: String.t(),
          reader_ids: [String.t()],
          bind_vm_id: String.t() | nil
        }) :: %{id: String.t()}
  def seed_thread!(%{owner_id: owner_id, title: title, reader_ids: readers, bind_vm_id: vm_id}) do
    owner = Security.current(owner_id)
    key = Ash.UUID.generate()
    [image | _] = Ledger.read!(Marshall.Compute.Image, [])
    vm = if vm_id, do: hd(Ledger.read!(Marshall.Compute.VirtualMachine, id: vm_id))
    true = is_nil(vm) or vm.owner_id == owner.id

    thread =
      Ledger.create!(Marshall.Threads.Thread, :open, %{
        creator_id: owner.id,
        objective: title,
        mode: :medium,
        machine_spec: %{
          idempotency_key: key,
          architecture: :x86_64,
          image_id: image.id,
          profile: :standard,
          vcpu: 2,
          memory_bytes: 536_870_912,
          disk_bytes: 2_147_483_648
        },
        idempotency_key: key,
        machine_key: if(vm, do: vm.idempotency_key, else: key)
      })

    Marshall.Threads.Generation.open!(thread, 1)
    thread = bind_machine!(thread, owner, vm)

    for reader <- readers do
      {:ok, _} =
        Marshall.Threads.set_access(
          %{
            thread_id: thread.id,
            email: to_string(Security.current(reader).email),
            role: if(vm, do: :operator, else: :viewer),
            idempotency_key: Ash.UUID.generate()
          },
          actor: owner
        )
    end

    %{id: thread.id}
  end

  @doc "Changes a reader's role through the creator's real set_access action."
  @spec share!(String.t(), String.t(), String.t(), :operator | :viewer | :revoked) :: :ok
  def share!(thread_id, owner_id, user_id, role) do
    {:ok, _} =
      Marshall.Threads.set_access(
        %{
          thread_id: thread_id,
          email: to_string(Security.current(user_id).email),
          role: role,
          idempotency_key: Ash.UUID.generate()
        },
        actor: Security.current(owner_id)
      )

    :ok
  end

  @spec bind_machine!(
          Marshall.Threads.Thread.t(),
          Marshall.Accounts.User.t(),
          Marshall.Compute.VirtualMachine.t() | nil
        ) :: Marshall.Threads.Thread.t()
  defp bind_machine!(thread, _owner, nil), do: thread

  defp bind_machine!(thread, owner, vm) do
    [root] = Ledger.read!(Marshall.Agents.Root, vm_id: vm.id)

    # A root has exactly one top-level agent thread, so the target is its child.
    top =
      Marshall.Agents.Thread
      |> Ledger.read!(root_id: root.id)
      |> Enum.find(&is_nil(&1.parent_thread_id))

    agent =
      Ledger.create!(Marshall.Agents.Thread, :open, %{
        root_id: root.id,
        parent_thread_id: top.id,
        title: "fixture subscription target",
        created_by_id: owner.id
      })

    thread
    |> Ledger.update!(:record_admitted_machine, %{machine_id: vm.id})
    |> Ledger.update!(:bind_agent, %{agent_root_id: root.id, agent_thread_id: agent.id})
    |> Ledger.update!(:mark_ready, %{})
  end
end
