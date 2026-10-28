# Trusted fixture entry point for the artifact and thread server-tool fleets.
# Every action is fenced by the disposable database sentinel, returns only
# identifiers, closed outcomes or digests, and never prints content or tickets.

# @cc [owner:ghuntley,label:verification;security] fleet-server-tool-operator
# Prompts MUST go through Marshall.Agents.submit_prompt as the real member;
# sharing, tickets, storage and audit observations MUST use the reviewed
# ArtifactMachineFixture and ThreadMachineFixture surfaces, which use
# Marshall's authorized actions. This script MUST NOT complete, claim or forge any agent command.
Code.require_file("/etc/fleet-artifact-fixture.exs")

defmodule FleetServerToolOperator do
  alias ArtifactMachineFixture, as: Artifacts
  alias ThreadMachineFixture, as: Threads

  @prompts [
    "Publish artifact fixture",
    "Publish stale artifact fixture",
    "Publish staged artifact fixture",
    "Publish restarted artifact fixture",
    "Use thread tool fixture"
  ]

  @spec run(map()) :: map()
  def run(%{
        "action" => "server-tool-prompt",
        "actor_id" => actor_id,
        "vm_id" => vm_id,
        "prompt" => prompt,
        "key" => key
      })
      when prompt in @prompts do
    actor = Ash.get!(Marshall.Accounts.User, actor_id, authorize?: false)
    {:ok, [thread | _]} = Marshall.Agents.Conversation.list(vm_id, actor)

    {:ok, result} =
      Marshall.Agents.submit_prompt(
        %{thread_id: thread.id, prompt: prompt, request_key: key},
        actor: actor
      )

    %{thread_id: thread.id, turn_id: result.turn_id, status: result.status}
  end

  def run(%{
        "action" => "artifact-share",
        "artifact_id" => artifact,
        "owner_id" => owner,
        "user_id" => user,
        "role" => role
      })
      when role in ["viewer", "writer", "revoked"] do
    :ok = Artifacts.share!(artifact, owner, user, String.to_existing_atom(role))
    %{shared: role}
  end

  def run(%{
        "action" => "artifact-ticket",
        "artifact_id" => artifact,
        "version" => version,
        "user_id" => user,
        "output" => output
      })
      when is_integer(version) do
    ticket = Artifacts.issue_ticket!(%{id: artifact, version: version}, user_id: user)
    private_write(output, ticket)
    %{issued: true}
  end

  def run(%{
        "action" => "artifact-storage",
        "artifact_id" => artifact,
        "user_id" => user,
        "scope" => scope
      })
      when scope in ["shared", "personal"] do
    outcome =
      Artifacts.storage_write(artifact, user, String.to_existing_atom(scope), "fixture", "1")

    case outcome do
      :ok -> %{written: true, reason: nil}
      {:error, reason} when is_atom(reason) -> %{written: false, reason: Atom.to_string(reason)}
    end
  end

  # Purge interruption: this eval node never serves the artifacts queue, so the
  # one step it runs is the only work done before the replicas restart.
  def run(%{
        "action" => "artifact-purge-interrupted",
        "owner_id" => owner,
        "entries" => entries
      })
      when is_integer(entries) do
    :ok = Oban.pause_queue(queue: :artifacts, local_only: true)

    %{id: artifact} =
      Artifacts.seed_artifact!(%{
        owner_id: owner,
        title: "Purge fixture",
        entry: "index.html",
        files: %{"index.html" => "<p>purge fixture</p>"}
      })

    :ok = Artifacts.fill_storage!(artifact, owner, entries)
    :ok = Artifacts.delete!(artifact, owner)
    :ok = Artifacts.purge_step!(artifact)
    %{artifact_id: artifact}
  end

  def run(%{"action" => "artifact-delete", "artifact_id" => artifact, "owner_id" => owner}) do
    :ok = Artifacts.delete!(artifact, owner)
    %{deleting: true}
  end

  # Pauses server-tool execution on every replica through the shared notifier
  # so a queued command is still pending when the replicas restart.
  def run(%{"action" => "pause-agent-tools"}) do
    :ok = Oban.pause_queue(queue: :agent_tools)
    %{paused: "agent_tools"}
  end

  def run(%{"action" => "artifact-state", "artifact_id" => artifact}) do
    state = Artifacts.state!(artifact)

    %{
      current_version: state.current_version,
      versions: state.versions,
      file_sha256: state.file_sha256,
      audit_kinds: Enum.map(state.audit_kinds, &to_string/1)
    }
  end

  def run(
        %{
          "action" => "thread-seed",
          "owner_id" => owner,
          "title" => title,
          "readers" => readers
        } = request
      )
      when is_list(readers) do
    bind_vm_id =
      case Map.get(request, "bind_vm_id") do
        nil -> nil
        vm_id -> if OverallsProtocol.uuid?(vm_id), do: vm_id, else: raise(ArgumentError)
      end

    %{id: id} =
      Threads.seed_thread!(%{
        owner_id: owner,
        title: title,
        reader_ids: readers,
        bind_vm_id: bind_vm_id
      })

    %{thread_id: id}
  end

  def run(%{
        "action" => "thread-share",
        "thread_id" => thread,
        "owner_id" => owner,
        "user_id" => user,
        "role" => role
      })
      when role in ["operator", "viewer", "revoked"] do
    :ok = Threads.share!(thread, owner, user, String.to_existing_atom(role))
    %{shared: role}
  end

  defp private_write(path, value) when is_binary(value) do
    {:ok, file} = File.open(path, [:write, :exclusive, :binary])

    try do
      :ok = File.chmod(path, 0o600)
      :ok = IO.binwrite(file, value)
    after
      File.close(file)
    end
  end
end

try do
  {:ok, _} = Application.ensure_all_started(:marshall)
  id = System.fetch_env!("FLEET_FIXTURE_ID")
  true = OverallsProtocol.uuid?(id)

  %{rows: [[^id]]} =
    Ecto.Adapters.SQL.query!(Marshall.Repo, "SELECT id::text FROM overalls_fleet_fixture", [],
      log: false
    )

  [request] = System.argv()
  result = request |> File.read!() |> JSON.decode!() |> FleetServerToolOperator.run()
  IO.puts("FLEET_OK " <> JSON.encode!(result))
rescue
  error ->
    # Only exception module names and Marshall stack locations are reported;
    # messages, values and arguments stay private.
    inner =
      case error do
        %{errors: errors} when is_list(errors) ->
          Enum.map(errors, fn inner ->
            nested = Map.get(inner, :error)

            [
              inspect(inner.__struct__)
              | if(is_exception(nested), do: [inspect(nested.__struct__)], else: [])
            ]
            |> Enum.join("<")
          end)

        _ ->
          []
      end

    locations =
      for {module, function, _arity_or_args, location} <- __STACKTRACE__,
          String.starts_with?(inspect(module), ["Marshall", "FleetServerToolOperator"]),
          do: "#{inspect(module)}.#{function}:#{Keyword.get(location, :line, 0)}"

    IO.puts(
      :stderr,
      "Fleet server-tool operator failed (#{inspect(error.__struct__)} #{Enum.join(inner, ",")} at #{Enum.join(Enum.take(locations, 8), ",")}); private diagnostics withheld"
    )

    System.halt(1)
end
