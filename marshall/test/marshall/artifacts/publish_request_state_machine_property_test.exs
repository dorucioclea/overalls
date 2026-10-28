defmodule Marshall.Artifacts.PublishRequestStateMachinePropertyTest do
  # @cc [owner:ghuntley,label:verification;capacity;security] artifact-publish-request-model
  # Generated settle, refuse, expiry, stage-attach and direct-transition
  # histories over staged publishes MUST match the model: only `staging` may
  # move, once, to committed, refused or expired; terminal requests never
  # change again; every terminal request has released all staged chunks; and
  # expiry resumes the parent command exactly through its server-tool job.
  use Marshall.DataCase, async: false
  import Hegel
  import Hegel.Gen

  alias Marshall.Artifacts.{ExpiryJob, PublishRequest, Staging}
  alias Marshall.Compute.Ledger

  @terminal [:committed, :refused, :expired]

  @tag :hegel_case_sandbox
  @tag timeout: 900_000
  property "staged publishes move only from staging and always release chunks",
    test_cases: 25 do
    Marshall.DataCase.isolate_property_case()

    requests = for _ <- 1..3, do: open!()

    steps =
      draw(
        "steps",
        list_of(
          tuple([
            integer(0, 2),
            member_of([:settle_ok, :settle_refused, :expire, :attach, :commit_direct, :chunk])
          ]),
          min_length: 1,
          max_length: 16
        )
      )

    model = Map.new(requests, &{&1.id, :staging})

    final =
      Enum.reduce(steps, model, fn {index, op}, model ->
        request = Enum.at(requests, index)
        model = step(op, request, model)

        for current <- requests do
          [row] = Ledger.read!(PublishRequest, id: current.id)
          assert row.state == model[current.id]
          if row.state in @terminal, do: assert(chunks(current.id) == 0)
        end

        model
      end)

    expired = Enum.count(final, fn {_, state} -> state == :expired end)

    resumed =
      [repo: Marshall.Repo, worker: Marshall.Agents.ServerToolJob]
      |> Oban.Testing.all_enqueued()
      |> Enum.map(& &1.args["command_id"])
      |> Enum.uniq()

    assert length(resumed) == expired
  end

  defp step(:settle_ok, request, model) do
    artifact_id = Ash.UUID.generate()

    :ok =
      Staging.settle(
        request.command_id,
        {:ok, %{artifact: %{id: artifact_id}, version: %{number: 1}}}
      )

    if model[request.id] == :staging do
      assert [%{artifact_id: ^artifact_id, version_number: 1}] =
               Ledger.read!(PublishRequest, id: request.id)

      Map.put(model, request.id, :committed)
    else
      model
    end
  end

  defp step(:settle_refused, request, model) do
    :ok = Staging.settle(request.command_id, {:error, :limit_exceeded})

    if model[request.id] == :staging do
      assert [%{reason: :limit_exceeded}] = Ledger.read!(PublishRequest, id: request.id)
      Map.put(model, request.id, :refused)
    else
      model
    end
  end

  defp step(:expire, request, model) do
    Ecto.Adapters.SQL.query!(
      Marshall.Repo,
      "UPDATE artifact_publish_requests SET expires_at = now() - interval '1 second' WHERE id = $1",
      [Ecto.UUID.dump!(request.id)],
      log: false
    )

    assert :ok = Oban.Testing.perform_job(ExpiryJob, %{}, repo: Marshall.Repo)

    Map.new(model, fn
      {id, :staging} ->
        [row] = Ledger.read!(PublishRequest, id: id)

        {id,
         if(DateTime.compare(row.expires_at, Ledger.now()) == :gt, do: :staging, else: :expired)}

      other ->
        other
    end)
  end

  defp step(:attach, request, model) do
    result =
      attempt(fn ->
        Ledger.update!(current(request), :attach_stage, %{stage_command_id: Ash.UUID.generate()})
      end)

    assert result == (model[request.id] == :staging)
    model
  end

  defp step(:commit_direct, request, model) do
    result =
      attempt(fn ->
        Ledger.update!(current(request), :commit, %{
          artifact_id: Ash.UUID.generate(),
          version_number: 2
        })
      end)

    assert result == (model[request.id] == :staging)
    if result, do: Staging.release!(request.id)
    if result, do: Map.put(model, request.id, :committed), else: model
  end

  defp step(:chunk, request, model) do
    if model[request.id] == :staging, do: chunk!(request.id, chunks(request.id))
    model
  end

  defp current(request) do
    [row] = Ledger.read!(PublishRequest, id: request.id)
    row
  end

  @spec attempt((-> term())) :: boolean()
  defp attempt(fun) do
    result =
      Ledger.transaction(fn ->
        try do
          fun.()
        rescue
          _ -> Ledger.rollback(:refused)
        end
      end)

    match?({:ok, _}, result)
  end

  defp open! do
    request =
      Ledger.create!(PublishRequest, :open, %{
        command_id: Ash.UUID.generate(),
        user_id: Ash.UUID.generate(),
        vm_id: Ash.UUID.generate(),
        files: [%{"file_index" => 0, "path" => "index.html", "content_type" => "text/html"}],
        expires_at: DateTime.add(Ledger.now(), 3600, :second)
      })

    chunk!(request.id, 0)
    request
  end

  defp chunk!(request_id, index) do
    Ecto.Adapters.SQL.query!(
      Marshall.Repo,
      """
      INSERT INTO artifact_staged_chunks
        (publish_request_id, file_index, chunk_index, sha256, data, inserted_at)
      VALUES ($1, 0, $2, $3, $4, now())
      """,
      [Ecto.UUID.dump!(request_id), index, String.duplicate("0", 64), "chunk"],
      log: false
    )
  end

  defp chunks(request_id) do
    %{rows: [[count]]} =
      Ecto.Adapters.SQL.query!(
        Marshall.Repo,
        "SELECT count(*) FROM artifact_staged_chunks WHERE publish_request_id = $1",
        [Ecto.UUID.dump!(request_id)],
        log: false
      )

    count
  end
end
