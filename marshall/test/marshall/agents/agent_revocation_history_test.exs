defmodule Marshall.Agents.AgentRevocationHistoryTest do
  use MarshallWeb.ConnCase, async: false
  import Hegel
  import Hegel.Gen

  alias Marshall.Accounts.User
  alias Marshall.AgentRevocationFixture, as: Fixture
  alias Marshall.Agents.{AuditEvent, CLIAccess, CLISession, Command, ExecutorSession}
  alias Marshall.Agents.{ModelCall, ModelCalls, Turn}
  alias Marshall.Compute.Ledger

  @moduletag capture_log: true

  @type stage :: :queued | :claimed | :started | :completed
  @type boundary :: :withdraw | :expire | :delete | :retire

  # @cc [owner:ghuntley,label:verification;security;recovery] revocation-ordering-terminal-uniqueness
  # Generated queue/claim/start/complete stages crossed with withdraw/expire/delete/retire
  # boundaries MUST settle to exactly one terminal turn state with receipts and closed CLI
  # authority. Post-settlement ticks and claim polls MUST NOT change any scoped row digest.
  property "generated revocation orderings settle to one terminal state with receipts",
    test_cases: 100 do
    pairs =
      for stage <- [:queued, :claimed, :started, :completed],
          boundary <- [:withdraw, :expire, :delete, :retire],
          do: {stage, boundary}

    order = draw("order", shuffle(pairs))

    Enum.each(order, fn {stage, boundary} ->
      try do
        history(stage, boundary)
      rescue
        error ->
          reraise RuntimeError,
                  "#{stage}/#{boundary}: " <> Exception.message(error),
                  __STACKTRACE__
      end
    end)
  end

  # @cc [owner:ghuntley,label:verification;security] cli-approval-sequence-single-commit
  # Every generated approval sequence over fresh or repeated digests MUST keep at
  # most one session row per digest; every losing attempt MUST record exactly one
  # cli_refused receipt and authorized winners exactly one cli_approved receipt.
  # Other approved secrets remain valid while the actor retains current access;
  # sharing withdrawal MUST revoke them independently of this sequence.
  property "generated approval sequences keep one session per digest with classified refusals",
    test_cases: 100 do
    actions =
      draw("actions", list_of(member_of([:same, :owner, :fresh]), min_length: 1, max_length: 8))

    withdrawn? = draw("withdrawn?", boolean())
    c = Fixture.setup()
    if withdrawn?, do: assert({:ok, _} = Fixture.share(c, :revoked))

    salt = Ash.UUID.generate()
    primary_secret = sequence_secret("#{salt}:primary")

    state =
      Enum.reduce(
        actions,
        %{approved: %{}, refused: 0, fresh: 0},
        fn action, model ->
          {secret, actor} =
            case action do
              :same ->
                {primary_secret, c.member}

              :owner ->
                {primary_secret, c.owner}

              :fresh ->
                {sequence_secret("#{salt}:fresh_#{model.fresh}"), c.member}
            end

          code = Base.encode16(:crypto.hash(:sha256, secret), case: :lower)

          model =
            if action == :fresh,
              do: %{model | fresh: model.fresh + 1},
              else: model

          permitted =
            (actor.id == c.owner.id or not withdrawn?) and
              not Map.has_key?(model.approved, code)

          result = CLIAccess.approve(c.vm.id, code, actor)

          if permitted do
            assert {:ok, _} = result
            %{model | approved: Map.put(model.approved, code, {actor.id, secret})}
          else
            assert {:error, _} = result
            %{model | refused: model.refused + 1}
          end
        end
      )

    for {code, {actor_id, secret}} <- state.approved do
      assert [%{actor_id: ^actor_id}] = Ledger.read!(CLISession, code_hash: code)
      assert {:ok, %{id: ^actor_id}} = CLIAccess.authorize(c.vm.id, secret)
    end

    member_id = c.member.id

    if withdrawn?,
      do: assert({:error, :unauthorized} = CLIAccess.authorize(c.vm.id, c.secret)),
      else: assert({:ok, %{id: ^member_id}} = CLIAccess.authorize(c.vm.id, c.secret))

    # Exactly one session row per approved digest, no row for refused digests.
    approved = Map.keys(state.approved)

    assert %{rows: [[approved_sessions]]} =
             Fixture.query(
               "SELECT count(*) FROM agent_cli_sessions WHERE vm_id=$1",
               [Ecto.UUID.dump!(c.vm.id)]
             )

    assert approved_sessions == 1 + length(approved)

    if approved != [] do
      assert %{rows: [[counted]]} =
               Fixture.query(
                 "SELECT count(*) FROM agent_cli_sessions WHERE code_hash = ANY($1)",
                 [approved]
               )

      assert counted == length(approved)
    end

    # Aggregate receipt inventory: the fixture's initial approval plus this
    # sequence's accepted approvals, and one refusal receipt per denial.
    receipts =
      Fixture.query(
        "SELECT kind::text, count(*) FROM agent_audit_events WHERE vm_id=$1 AND kind IN ('cli_approved','cli_refused') GROUP BY kind",
        [Ecto.UUID.dump!(c.vm.id)]
      ).rows
      |> Map.new(fn [kind, counted] -> {kind, counted} end)

    assert Map.get(receipts, "cli_approved", 0) == 1 + length(approved)
    assert Map.get(receipts, "cli_refused", 0) == state.refused
    :ok
  end

  @spec sequence_secret(String.t()) :: String.t()
  defp sequence_secret(label) do
    "overalls_agent_" <> Base.encode16(:crypto.hash(:sha256, label), case: :lower)
  end

  # @cc [owner:ghuntley,label:verification;recovery] cli-reaper-expiry-sweep
  # Generated expiry offsets MUST destroy exactly the sessions past their expiry
  # plus retention hour, leaving every not-yet-reapable row intact, with one
  # cli_expired receipt per destroyed row and idempotent subsequent passes.
  property "the CLI session reaper destroys exactly expired approvals with receipts",
    test_cases: 100 do
    offsets =
      draw(
        "offsets",
        list_of(
          one_of([integer(-7200..-3660), integer(-3540..1800)]),
          min_length: 2,
          max_length: 10
        )
      )

    c = Fixture.setup()

    generated =
      for offset <- offsets do
        secret = "overalls_agent_" <> Base.encode16(:crypto.strong_rand_bytes(32), case: :lower)
        code = Base.encode16(:crypto.hash(:sha256, secret), case: :lower)
        assert {:ok, session} = CLIAccess.approve(c.vm.id, code, c.member)

        Fixture.query(
          """
          UPDATE agent_cli_sessions
          SET inserted_at = now() + (least($2, 0) - 1) * interval '1 second',
              expires_at = now() + $2 * interval '1 second'
          WHERE id = $1
          """,
          [Ecto.UUID.dump!(session.id), offset]
        )

        {code, offset}
      end

    expired = for {code, offset} <- generated, offset < -3600, do: code
    live = for {code, offset} <- generated, offset >= -3600, do: code

    assert :ok = CLIAccess.reap()

    assert %{rows: [[0]]} =
             Fixture.query(
               "SELECT count(*) FROM agent_cli_sessions WHERE code_hash = ANY($1)",
               [expired]
             )

    expected_live = length(live)

    assert %{rows: [[^expected_live]]} =
             Fixture.query(
               "SELECT count(*) FROM agent_cli_sessions WHERE code_hash = ANY($1)",
               [live]
             )

    # Every expired session must surface exactly one audit receipt; a second
    # sweep must neither remove a live session nor duplicate a receipt.
    assert :ok = CLIAccess.reap()
    expected_expired = length(expired)

    assert %{rows: [[^expected_expired]]} =
             Fixture.query(
               """
               SELECT count(*) FROM agent_audit_events
               WHERE vm_id = $1 AND kind = 'cli_expired'
                 AND target_id IS NOT NULL
               """,
               [Ecto.UUID.dump!(c.vm.id)]
             )

    assert %{rows: [[^expected_live]]} =
             Fixture.query(
               "SELECT count(*) FROM agent_cli_sessions WHERE code_hash = ANY($1)",
               [live]
             )
  end

  @spec history(stage(), boundary()) :: :ok
  defp history(stage, boundary) do
    c = Fixture.setup()
    turn = Fixture.submit!(c)
    {executor, command} = advance_to_stage(c, turn, stage)

    apply_boundary(c, boundary)
    assert {:error, :unauthorized} = CLIAccess.authorize(c.vm.id, c.secret)

    current_executor =
      case boundary do
        :expire ->
          settle_expiry(c, turn, stage, executor, command)

        :delete ->
          settle_delete(c, turn, stage)

        other when other in [:withdraw, :retire] ->
          settle_revocation(c, turn, stage, executor, command)
      end

    # Terminal uniqueness: exactly one terminal marker event per turn, forever.
    assert 1 ==
             Fixture.query(
               """
               SELECT count(*) FROM agent_events
               WHERE turn_id=$1 AND kind IN ('turn_failed', 'assistant')
               """,
               [Ecto.UUID.dump!(turn.id)]
             ).rows
             |> hd()
             |> hd()

    stable = Fixture.snapshot(c.vm.id)
    assert :ok = Fixture.tick()
    assert {:ok, %{call: nil}} = ModelCalls.claim(c.token)
    assert Fixture.snapshot(c.vm.id) == stable

    if current_executor do
      assert {:ok, nil} =
               ExecutorSession.claim(c.binding, current_executor.id, current_executor.fence_epoch)
    end

    assert_cli_receipts(c)
    :ok
  end

  @spec advance_to_stage(Fixture.fixture(), Turn.t(), stage()) ::
          {Marshall.Agents.Executor.t() | nil, Command.t() | nil}
  defp advance_to_stage(_c, _turn, :queued), do: {nil, nil}

  defp advance_to_stage(c, turn, stage) when stage in [:claimed, :started, :completed] do
    assert :ok = Fixture.tick()
    assert %{status: :running} = Fixture.turn(turn.id)
    Fixture.queue_tool!(c, turn)
    executor = Fixture.register!(c)
    command = Fixture.claim_tool!(c, executor)
    assert command.turn_id == turn.id

    if stage in [:started, :completed] do
      assert {:ok, %{status: :started}} =
               ExecutorSession.transition(
                 c.binding,
                 executor.id,
                 executor.fence_epoch,
                 command.id,
                 :started
               )
    end

    if stage == :completed do
      assert {:ok, %{status: :completed}} =
               ExecutorSession.transition(
                 c.binding,
                 executor.id,
                 executor.fence_epoch,
                 command.id,
                 :completed,
                 %{"stdout" => "fixture"}
               )

      assert :ok = Fixture.tick()
      Fixture.complete_model!(c, turn)
      assert %{status: :completed} = Fixture.turn(turn.id)
    end

    {executor, command}
  end

  @spec apply_boundary(Fixture.fixture(), boundary()) :: :ok
  defp apply_boundary(c, :withdraw) do
    assert {:ok, _} = Fixture.share(c, :revoked)
    :ok
  end

  defp apply_boundary(c, :expire) do
    [session] = Ledger.read!(CLISession, code_hash: c.code)

    Fixture.query(
      """
      UPDATE agent_cli_sessions
      SET inserted_at = now() - interval '7200 seconds',
          expires_at = now() - interval '3700 seconds'
      WHERE id = $1
      """,
      [Ecto.UUID.dump!(session.id)]
    )

    :ok
  end

  defp apply_boundary(c, :delete) do
    assert {:ok, _} =
             Marshall.Compute.lifecycle(
               %{vm_id: c.vm.id, kind: :delete, idempotency_key: Ash.UUID.generate()},
               actor: c.owner
             )

    :ok
  end

  defp apply_boundary(c, :retire) do
    admin = Marshall.PasskeyFixture.verified_session(Marshall.PasskeyFixture.user(true))

    assert {:ok, %{deleting: true}} =
             User
             |> Ash.ActionInput.for_action(
               :delete_user,
               %{user_id: c.member.id, confirmation: to_string(c.member.email)},
               actor: admin
             )
             |> Ash.run_action()

    Marshall.PasskeyFixture.cleanup(admin)

    assert {:error, _} =
             Marshall.Agents.submit_prompt(
               %{
                 thread_id: c.thread.id,
                 prompt: "post-retirement probe",
                 request_key: Ash.UUID.generate()
               },
               actor: c.member
             )

    :ok
  end

  # CLI session expiry closes only the CLI: executor and model authority derive
  # from current VM access, so the in-flight turn still completes durably.
  @spec settle_expiry(Fixture.fixture(), Turn.t(), stage(), term(), Command.t() | nil) ::
          Marshall.Agents.Executor.t() | nil
  defp settle_expiry(c, turn, stage, executor, command) do
    executor =
      if stage == :completed do
        executor
      else
        if executor == nil do
          assert :ok = Fixture.tick()
          Fixture.queue_tool!(c, turn)
        end

        assert %{status: :running} = Fixture.turn(turn.id)
        executor = executor || Fixture.register!(c)

        command =
          case command do
            nil -> Fixture.claim_tool!(c, executor)
            %Command{} = existing -> hd(Ledger.read!(Command, id: existing.id))
          end

        if command.status == :claimed do
          assert {:ok, _} =
                   ExecutorSession.transition(
                     c.binding,
                     executor.id,
                     executor.fence_epoch,
                     command.id,
                     :started
                   )
        end

        assert {:ok, %{status: :completed}} =
                 ExecutorSession.transition(
                   c.binding,
                   executor.id,
                   executor.fence_epoch,
                   command.id,
                   :completed,
                   %{"stdout" => "fixture"}
                 )

        assert :ok = Fixture.tick()
        Fixture.complete_model!(c, turn)
        executor
      end

    assert %{status: :completed} = Fixture.turn(turn.id)

    # The expired session itself is refused and ages into the reaper with a
    # durable, content-free expiry receipt instead of a silent destroy.
    assert {:error, :unauthorized} = CLIAccess.authorize(c.vm.id, c.secret)
    assert [%{id: session_id}] = Ledger.read!(CLISession, code_hash: c.code)
    assert :ok = CLIAccess.reap()
    assert [] = Ledger.read!(CLISession, code_hash: c.code)

    assert [%{kind: :cli_expired, target_id: ^session_id, outcome: :accepted}] =
             Ledger.read!(AuditEvent, vm_id: c.vm.id, kind: :cli_expired)

    assert :ok = CLIAccess.reap()
    executor
  end

  # VM deletion fails non-terminal turns with machine_unavailable and retains
  # in-flight command rows; the fence closes registration against the dead VM.
  @spec settle_delete(Fixture.fixture(), Turn.t(), stage()) :: nil
  defp settle_delete(c, turn, stage) do
    unless stage == :completed do
      assert :ok = Fixture.tick()
      assert :ok = Fixture.tick()
      assert %{status: :failed, failure_reason: :machine_unavailable} = Fixture.turn(turn.id)
      assert {:error, :stale_execution} = ExecutorSession.register(c.binding, nil, ["context-v1"])
    else
      assert %{status: :completed} = Fixture.turn(turn.id)
    end

    assert {:error, :unauthorized} = CLIAccess.authorize(c.vm.id, c.secret)
    nil
  end

  # Access withdrawal or member retirement must terminate a non-terminal turn
  # with :access_revoked, refuse new claims and retire in-flight work exactly
  # once when the replacement lease arrives.
  @spec settle_revocation(
          Fixture.fixture(),
          Turn.t(),
          stage(),
          Marshall.Agents.Executor.t() | nil,
          Command.t() | nil
        ) :: Marshall.Agents.Executor.t() | nil
  defp settle_revocation(c, turn, stage, executor, command) do
    if stage == :completed do
      assert %{status: :completed} = Fixture.turn(turn.id)
      assert :ok = Fixture.tick()
      assert %{status: :completed} = Fixture.turn(turn.id)
    else
      assert :ok = Fixture.tick()
      assert :ok = Fixture.tick()
      assert %{status: :failed, failure_reason: :access_revoked} = Fixture.turn(turn.id)
    end

    assert {:error, :unauthorized} = CLIAccess.authorize(c.vm.id, c.secret)

    assert {:error, _} =
             Marshall.Agents.submit_prompt(
               %{
                 thread_id: c.thread.id,
                 prompt: "post-revocation probe",
                 request_key: Ash.UUID.generate()
               },
               actor: c.member
             )

    executor =
      if stage in [:claimed, :started] and command != nil do
        # The in-flight command holds exactly one outcome; the turn is already
        # terminal, so the replacement lease retires the stale claim without
        # re-dispatching it.
        assert [%{status: in_flight}] = Ledger.read!(Command, id: command.id)
        assert in_flight == stage

        replacement = Fixture.register!(c)
        assert replacement.fence_epoch > executor.fence_epoch

        expected = if stage == :claimed, do: :cancelled, else: :uncertain

        assert [%{status: ^expected}] = Ledger.read!(Command, id: command.id)

        assert {:ok, nil} =
                 ExecutorSession.claim(c.binding, replacement.id, replacement.fence_epoch)

        assert [%{status: ^expected}] = Ledger.read!(Command, id: command.id)
        replacement
      else
        executor
      end

    if stage == :queued do
      assert [] = tool_commands(turn_id: turn.id)
      assert [] = Ledger.read!(ModelCall, turn_id: turn.id)
      assert :ok = Fixture.tick()
    end

    executor
  end

  @spec assert_cli_receipts(Fixture.fixture()) :: :ok
  defp assert_cli_receipts(c) do
    assert [%{kind: :cli_approved, outcome: :accepted}] =
             Ledger.read!(AuditEvent, vm_id: c.vm.id, kind: :cli_approved)

    # Receipts are content-free by construction: the resource has no attribute
    # beyond identifiers, closed kinds and outcomes.
    for event <- Ledger.read!(AuditEvent, vm_id: c.vm.id) do
      assert event.kind in [
               :agent_registered,
               :executor_updated,
               :prompt_admitted,
               :turn_started,
               :child_created,
               :wake_requested,
               :model_dispatched,
               :model_finished,
               :tool_dispatched,
               :tool_finished,
               :turn_finished,
               :thread_deleted,
               :cli_approved,
               :cli_refused,
               :cli_expired,
               :context_captured,
               :context_compacted
             ]
    end

    :ok
  end

  test "a refused browser approval commits a content-free denial receipt" do
    c = Fixture.setup()
    assert {:ok, _} = Fixture.share(c, :revoked)

    stranger_code = Base.encode16(:crypto.hash(:sha256, "overalls_agent_other"), case: :lower)

    assert {:error, :forbidden} = CLIAccess.approve(c.vm.id, stranger_code, c.member)

    assert [%{kind: :cli_refused, outcome: :failed, actor_id: actor_id}] =
             Ledger.read!(AuditEvent, vm_id: c.vm.id, kind: :cli_refused)

    assert actor_id == c.member.id
    assert [] = Ledger.read!(CLISession, code_hash: stranger_code)

    # A repeated approval of the same digest commits exactly one session and
    # one denial receipt, never a second row nor a raised crash.
    assert {:error, %Ash.Error.Invalid{}} = CLIAccess.approve(c.vm.id, c.code, c.owner)

    assert [%{}] = Ledger.read!(CLISession, code_hash: c.code)

    assert [%{kind: :cli_refused, outcome: :failed, actor_id: owner_id} | _] =
             Ledger.read!(AuditEvent, vm_id: c.vm.id, kind: :cli_refused, actor_id: c.owner.id)

    assert owner_id == c.owner.id
    :ok
  end

  test "an invalid approval request leaves no receipt and no session" do
    c = Fixture.setup()
    assert {:error, :invalid_request} = CLIAccess.approve(c.vm.id, "bogus", c.member)
    assert {:error, :invalid_request} = CLIAccess.approve("bogus", c.code, c.member)

    assert [] =
             Ledger.read!(AuditEvent, vm_id: c.vm.id, kind: :cli_refused, actor_id: c.member.id)

    :ok
  end

  test "reaping an expired approved session commits a closure receipt" do
    c = Fixture.setup()
    [session] = Ledger.read!(CLISession, code_hash: c.code)

    Fixture.query(
      """
      UPDATE agent_cli_sessions
      SET inserted_at = now() - interval '7200 seconds',
          expires_at = now() - interval '3700 seconds'
      WHERE id = $1
      """,
      [Ecto.UUID.dump!(session.id)]
    )

    assert {:error, :unauthorized} = CLIAccess.authorize(c.vm.id, c.secret)
    assert :ok = CLIAccess.reap()
    assert [] = Ledger.read!(CLISession, id: session.id)

    assert [%{kind: :cli_expired, target_id: target_id, outcome: :accepted, actor_id: actor}] =
             Ledger.read!(AuditEvent, vm_id: c.vm.id, kind: :cli_expired)

    assert target_id == session.id
    assert actor == c.member.id
    assert :ok = CLIAccess.reap()
    :ok
  end

  test "a capability refusal at model admission fails the turn with capability_denied" do
    c = Fixture.setup()

    # The owner prompts directly: the profile flipped below keeps VM write
    # authority for the owner while emptying the model's tool matrix.
    {:ok, submitted} = Fixture.prompt(c, Ash.UUID.generate(), c.owner)
    [turn] = Ledger.read!(Turn, id: submitted.turn_id)
    Fixture.settle_context!(c, turn, c.owner)

    # Synthetic persisted-profile boundary: the model admission policy cannot
    # advertise tools for a profile outside the agent matrix.
    Fixture.query(
      "UPDATE compute_virtual_machines SET profile = 'customer' WHERE id = $1",
      [Ecto.UUID.dump!(c.vm.id)]
    )

    assert :ok = Fixture.tick()
    assert %{status: :failed, failure_reason: :capability_denied} = Fixture.turn(turn.id)
    assert [] = Ledger.read!(ModelCall)
    assert [] = tool_commands([])
    assert :ok = Fixture.tick()
    :ok
  end

  test "registration refuses a retired root owner and reclaims no work" do
    c = Fixture.setup()
    admin = Marshall.PasskeyFixture.verified_session(Marshall.PasskeyFixture.user(true))

    assert {:ok, %{deleting: true}} =
             User
             |> Ash.ActionInput.for_action(
               :delete_user,
               %{user_id: c.owner.id, confirmation: to_string(c.owner.email)},
               actor: admin
             )
             |> Ash.run_action()

    Marshall.PasskeyFixture.cleanup(admin)

    assert {:error, :access_revoked} = ExecutorSession.register(c.binding, nil, ["context-v1"])
    assert {:error, :access_revoked} = ExecutorSession.register(c.binding, nil, ["context-v1"])
    assert [] = Ledger.read!(Marshall.Agents.Executor)

    # Member withdrawal alone never mints refusals at registration: the lease
    # binds the owner's VM; per-turn authority still gates claims.
    c = Fixture.setup()
    assert {:ok, _} = Fixture.share(c, :revoked)
    assert {:ok, executor} = ExecutorSession.register(c.binding, nil, ["context-v1"])
    assert {:ok, nil} = ExecutorSession.claim(c.binding, executor.id, executor.fence_epoch)
    :ok
  end

  test "an orphaned queued command is retired once its turn is terminal" do
    c = Fixture.setup()
    turn = Fixture.submit!(c)
    assert :ok = Fixture.tick()
    Fixture.queue_tool!(c, turn)
    [command] = tool_commands(turn_id: turn.id)
    assert command.status == :queued

    assert {:ok, _} = Fixture.share(c, :revoked)
    assert :ok = Fixture.tick()
    assert %{status: :failed, failure_reason: :access_revoked} = Fixture.turn(turn.id)
    assert [%{status: :queued}] = Ledger.read!(Command, id: command.id)

    assert :ok = Fixture.tick()

    assert [%{status: :cancelled, result: %{"reason" => "turn_finished"}}] =
             Ledger.read!(Command, id: command.id)

    assert [%{kind: :tool_finished, outcome: :failed}] =
             Ledger.read!(AuditEvent, kind: :tool_finished, target_id: command.id)

    before = Fixture.snapshot(c.vm.id)
    assert :ok = Fixture.tick()
    assert :ok = Fixture.tick()
    assert Fixture.snapshot(c.vm.id) == before
    :ok
  end

  # Context preparation leaves a completed context_inventory command; these
  # histories count only the tool commands the model requested.
  @spec tool_commands(keyword()) :: [Command.t()]
  defp tool_commands(filter),
    do: Command |> Ledger.read!(filter) |> Enum.reject(&(&1.tool == :context_inventory))
end
