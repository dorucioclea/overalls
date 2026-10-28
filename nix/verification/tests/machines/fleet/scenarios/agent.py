# @cc [owner:ghuntley,label:verification;security] fleet-agent-real-guest-roundtrip
# A shared VM operator prompts a stopped real guest. Marshall must wake it,
# Ziggy must obtain two model responses, and the guest must execute a fenced
# read_file through Audi private before the final answer. The model is an
# isolated deterministic provider fixture; no control or guest reply is forged.
import hashlib


def executor_capabilities(vm_id: str) -> list[str]:
    """@cc [owner:ghuntley,label:verification;security] native-context-skill-capabilities
    A live Firecracker guest executor MUST register the exact context and managed
    skill capability set before Marshall admits context preparation. The probe
    reads only the bounded capability array from the durable executor row; it
    MUST NOT inspect prompts, file contents or credentials.
    """
    assert str(uuid.UUID(vm_id)) == vm_id
    raw = json.loads(
        sql(
            "SELECT to_json(capabilities) FROM agent_executors WHERE root_id="
            "(SELECT id FROM agent_roots WHERE vm_id='"
            + vm_id
            + "') AND invalidated_at IS NULL ORDER BY inserted_at DESC LIMIT 1"
        )
    )
    assert isinstance(raw, list)
    result: list[str] = []
    for capability in raw:
        assert isinstance(capability, str)
        result.append(capability)
    return result


with subtest("private guest agent path has authenticated host services"):
    m1.succeed("systemctl start fleet-audi-ca.service")
    m1.wait_for_open_port(14000)
    m1.wait_until_succeeds(
        f"curl --fail --silent --cacert {root}/ca.crt --resolve m1:15000:127.0.0.1 "
        f"https://m1:15000/roots/0 >{root}/audi-root.pem"
    )
    for machine in provisioners:
        if otel_guest_enabled:
            machine.wait_for_unit("opentelemetry-collector.service")
            machine.wait_for_unit("overalls-otel-guest.service")
        transfer(m1, root + "/audi-root.pem", machine, "/run/galileo-audi-root.pem")
        machine.succeed("chmod 0444 /run/galileo-audi-root.pem")
        machine.succeed("fleet-seal-audi-private")
        machine.wait_for_unit("audi-private.service")
        machine.wait_until_succeeds(
            "curl --fail --silent --unix-socket /run/ziggy/proxy.sock "
            "http://ziggy/health/ready | jq -e '.ready == true'",
            timeout=120,
        )

with subtest("machine objective is admitted and executed after provisioning"):
    # Creating a user thread with an objective must provision its machine and
    # admit the initial prompt automatically once the real guest is available.
    created = operator(
        m1,
        dict(
            action="thread-create",
            owner_id=users["owner_id"],
            image_id=users["image_id"],
            key=str(uuid.uuid4()),
        ),
    )
    thread_id = str(uuid.UUID(str(created["thread_id"])))
    eventually(
        lambda: sql(f"SELECT status FROM threads WHERE id='{thread_id}'") == "ready",
        timeout=600,
    )
    vm_id = sql(f"SELECT machine_id FROM threads WHERE id='{thread_id}'")
    assert vm_id is not None
    vm_id = str(uuid.UUID(vm_id))
    # The user thread binds its machine's top-level agent thread; the two are
    # distinct identities, so compare the binding rather than the IDs.
    agent_thread_id = str(
        uuid.UUID(sql(f"SELECT agent_thread_id FROM threads WHERE id='{thread_id}'"))
    )
    assert (
        sql(
            "SELECT count(*) FROM agent_threads t JOIN agent_roots r ON r.id = t.root_id "
            f"WHERE t.id='{agent_thread_id}' AND r.vm_id='{vm_id}' AND t.parent_thread_id IS NULL"
        )
        == "1"
    )
    eventually(lambda: vm_state(vm_id) == "running", timeout=300)
    initial = f"thread-initial:{thread_id}"
    eventually(
        lambda: sql("SELECT count(*) FROM agent_turns WHERE request_key='" + initial + "'") == "1",
        timeout=300,
    )
    turn_id = sql("SELECT id FROM agent_turns WHERE request_key='" + initial + "'")
    assert turn_id is not None
    eventually(
        lambda: sql(f"SELECT status FROM agent_turns WHERE id='{turn_id}'") == "completed",
        timeout=600,
    )
    assert (
        sql(
            f"SELECT count(*) FROM agent_model_calls WHERE turn_id='{turn_id}' AND status='completed'"
        )
        >= "1"
    )
    # Reconciliation/retry must preserve the idempotent initial admission.
    m1.succeed("systemctl restart marshall-m1.service")
    m1.wait_for_unit("marshall-m1.service")
    eventually(
        lambda: sql("SELECT count(*) FROM agent_turns WHERE request_key='" + initial + "'") == "1",
        timeout=120,
    )


with subtest("shared operator prompt wakes guest and completes model tool round trip"):
    vm = provision_when_available(m1, "standard", disk_bytes=6_442_450_944)
    await_running(vm["vm_id"])
    host_for(vm).wait_until_succeeds(
        "fleet-galileo-guest agent-service " + shlex.quote(vm["placement_id"]), timeout=120
    )
    host_for(vm).wait_until_succeeds(
        "fleet-galileo-guest agent-route " + shlex.quote(vm["placement_id"]), timeout=120
    )
    eventually(
        lambda: (
            sql(
                "SELECT binary_sha256 FROM agent_executors WHERE root_id="
                f"(SELECT id FROM agent_roots WHERE vm_id='{vm['vm_id']}') "
                "AND invalidated_at IS NULL"
            )
            == agent_release_digest
        ),
        timeout=300,
    )
    host_for(vm).succeed(
        "fleet-galileo-guest agent-update "
        + shlex.quote(vm["placement_id"])
        + " "
        + agent_release_digest,
        timeout=120,
    )
    if not otel_guest_enabled:
        host_for(vm).succeed(
            "fleet-galileo-guest agent-reset "
            + shlex.quote(vm["placement_id"])
            + " "
            + agent_release_digest,
            timeout=120,
        )
        host_for(vm).wait_until_succeeds(
            "fleet-galileo-guest agent-update "
            + shlex.quote(vm["placement_id"])
            + " "
            + agent_release_digest,
            timeout=300,
        )
    operator(
        m1,
        dict(
            action="share",
            owner_id=users["owner_id"],
            vm_id=vm["vm_id"],
            email=users["member_email"],
            role="operator",
            key=str(uuid.uuid4()),
        ),
    )
    eventually(
        lambda: (
            sql(
                "SELECT count(*) FROM agent_executors WHERE root_id="
                f"(SELECT id FROM agent_roots WHERE vm_id='{vm['vm_id']}') "
                "AND expires_at > (clock_timestamp() AT TIME ZONE 'UTC')"
            )
            != "0"
        ),
        timeout=180,
    )
    # The source-built Lyra executor now advertises the context, managed skill,
    # GitHub tool, attachment and artifact staging operations Marshall requires
    # (stored sorted). Keeping this assertion beside the real guest round trip
    # prevents a stale image from appearing healthy while silently omitting them.
    capabilities = executor_capabilities(vm["vm_id"])
    expected_capabilities = [
        "artifacts-v1",
        "attachments-v1",
        "context-v1",
        "github-tools-v1",
        "skills-v1",
    ]
    assert capabilities == expected_capabilities, capabilities
    lifecycle(vm["vm_id"], "stop")
    eventually(lambda: vm_state(vm["vm_id"]) == "stopped", timeout=180)
    submitted = operator(
        m2,
        dict(
            action="agent-prompt",
            actor_id=users["member_id"],
            vm_id=vm["vm_id"],
            key=str(uuid.uuid4()),
        ),
    )
    turn_id = str(uuid.UUID(str(submitted["turn_id"])))
    assert submitted["status"] == "queued"
    eventually(lambda: vm_state(vm["vm_id"]) == "running", timeout=300)
    eventually(
        lambda: (
            sql(f"SELECT status FROM agent_turns WHERE id='{turn_id}'") in ("completed", "failed")
        ),
        timeout=300,
    )
    # Closed columns and response structure only (purpose, status, item types
    # and fixture tool names): no prompt, argument, result or reasoning bytes.
    turn_shape = sql(
        "SELECT status || ':' || coalesce(failure_reason, '') FROM agent_turns "
        f"WHERE id='{turn_id}'"
    )
    call_shapes = sql(
        "SELECT coalesce(string_agg(purpose || ':' || status || ':' || coalesce(("
        "SELECT string_agg(coalesce(i->>'type', '?') || '/' || coalesce(i->>'name', ''), '+') "
        "FROM jsonb_array_elements(CASE WHEN jsonb_typeof(response->'output') = 'array' "
        "THEN response->'output' ELSE '[]'::jsonb END) i), '') || ':' || "
        "coalesce(response->>'status', '') || ':' || coalesce(("
        "SELECT string_agg(coalesce(t->>'name', '?'), '+') "
        "FROM jsonb_array_elements(CASE WHEN jsonb_typeof(request->'tools') = 'array' "
        "THEN request->'tools' ELSE '[]'::jsonb END) t), ''), ',' ORDER BY inserted_at), '') "
        f"FROM agent_model_calls WHERE turn_id='{turn_id}'"
    )
    assert turn_shape == "completed:", (turn_shape, call_shapes)
    result = operator(m3, dict(action="agent-result", actor_id=users["member_id"], turn_id=turn_id))
    assert result == {"status": "completed", "answer_matches": True, "reason": None}
    if otel_guest_enabled:
        # @cc [owner:ghuntley,label:verification;durability] native-guest-durable-slo-restart
        # Successful physical and ready measurements MUST use this real guest's
        # retained evidence. Restarting Marshall MUST preserve nonzero source
        # counters, buckets and lifetimes, and another scan MUST not count twice.
        eventually(lambda: durable_service_level_snapshot(m1, vm["vm_id"]) != "", timeout=120)
        before_restart = durable_service_level_snapshot(m1, vm["vm_id"])
        m1.succeed("systemctl restart marshall-m1.service")
        m1.wait_for_unit("marshall-m1.service")
        assert durable_service_level_snapshot(m1, vm["vm_id"]) == before_restart
        assert durable_service_level_snapshot(m1, vm["vm_id"]) == before_restart

    assert (
        sql(
            f"SELECT count(*) FROM agent_model_calls WHERE turn_id='{turn_id}' AND status='completed'"
        )
        == "2"
    )
    # Context collection (context_inventory/context_read) precedes the model
    # turn; the guest tool round trip is exactly one fenced read_file.
    commands = sql(
        "SELECT coalesce(string_agg(tool || ':' || status, ',' ORDER BY inserted_at), '') "
        f"FROM agent_commands WHERE turn_id='{turn_id}'"
    )
    guest_commands = [
        command
        for command in commands.split(",")
        if command and not command.startswith(("context_inventory:", "context_read:"))
    ]
    assert guest_commands == ["read_file:completed"], commands
    assert all(command.endswith(":completed") for command in commands.split(",")), commands
    if otel_guest_enabled:
        # @cc [owner:ghuntley,label:verification;security] otel-native-guest-path
        # The observed count MUST come from the running Firecracker guest's
        # acknowledged Lyra tool result through Audi TLS and the Rust receiver.
        # A direct host-side metric fixture would bypass the binding boundary.
        host_for(vm).wait_until_succeeds(
            "curl -fsS http://127.0.0.1:9464/metrics | "
            "awk '$1 ~ /^overalls_guest_tool_calls(_total)?\\{/ && $2+0 >= 1 {ok=1} END {exit !ok}'",
            timeout=120,
        )
        # @cc [owner:ghuntley,label:verification;security] otel-native-guest-trace
        # Query the exact trace from the acknowledged real command at the
        # selected host's disposable Tempo; no host-side OTLP injection counts.
        command_id = sql(
            f"SELECT id FROM agent_commands WHERE turn_id='{turn_id}' AND tool='read_file'"
        )
        assert command_id is not None
        trace_id = hashlib.sha256(
            b"overalls.lyra.tool.trace.v1:" + command_id.replace("-", "").encode()
        ).hexdigest()[:32]
        host_for(vm).wait_until_succeeds(
            "curl -fsS http://127.0.0.1:3200/api/traces/"
            + trace_id
            + " | grep -q 'lyra.tool_result'",
            timeout=120,
        )
    assert (
        sql(
            "SELECT count(*) FROM agent_audit_events WHERE turn_id="
            f"'{turn_id}' AND kind='wake_requested'"
        )
        == "1"
    )

with subtest("native guest context inventory and project skills survive the model turn"):
    # Seed the files through the running guest's terminal.  The following turn
    # must collect them through context_inventory/context_read before the model
    # is admitted; querying the durable rows proves the operation crossed the
    # Marshall -> Audi -> Lyra boundary rather than reading the host fixture.
    placement = sql(
        f"SELECT current_placement_id FROM compute_virtual_machines WHERE id='{vm['vm_id']}'"
    )
    host_for(vm).wait_until_succeeds(
        "fleet-galileo-guest context-fixture " + shlex.quote(placement), timeout=180
    )
    context_turn = operator(
        m2,
        dict(
            action="agent-prompt",
            actor_id=users["member_id"],
            vm_id=vm["vm_id"],
            prompt="Read guest context and skills $review",
            key=str(uuid.uuid4()),
        ),
    )
    context_turn_id = str(uuid.UUID(str(context_turn["turn_id"])))
    eventually(
        lambda: sql(f"SELECT status FROM agent_turns WHERE id='{context_turn_id}'") == "completed",
        timeout=300,
    )
    context_commands = sql_json(
        "SELECT json_agg(json_build_object('tool',tool,'status',status,'result',result) "
        "ORDER BY inserted_at) "
        f"FROM agent_commands WHERE turn_id='{context_turn_id}' "
        "AND tool IN ('context_inventory','context_read')"
    )
    assert isinstance(context_commands, list) and context_commands
    assert all(command["status"] == "completed" for command in context_commands)
    inventory = next(
        command["result"]
        for command in context_commands
        if command["tool"] == "context_inventory"
        and isinstance(command["result"], dict)
        and command["result"].get("entries")
    )
    assert isinstance(inventory, dict)
    entries = inventory["entries"]
    assert isinstance(entries, list)
    paths = {entry["path"] for entry in entries if isinstance(entry, dict)}
    assert "/etc/overalls/AGENTS.md" in paths
    assert "/workspace/AGENTS.md" in paths
    assert "/workspace/.agents/skills/review/SKILL.md" in paths
    snapshot = sql_json(
        "SELECT json_build_object('catalog',skill_catalog,'sources',sources,"
        "'selected',selected_skills,'working_directory',working_directory) "
        f"FROM agent_context_snapshots WHERE turn_id='{context_turn_id}'"
    )
    assert isinstance(snapshot, dict)
    assert snapshot["working_directory"] == "/workspace"
    catalog = snapshot["catalog"]
    assert isinstance(catalog, list) and any(
        isinstance(skill, dict)
        and skill.get("name") == "review"
        and skill.get("scope") == "project"
        for skill in catalog
    )
    selected = snapshot["selected"]
    assert isinstance(selected, list) and len(selected) == 1 and isinstance(selected[0], str)
    assert any(
        isinstance(source, dict)
        and source.get("path") == "/workspace/.agents/skills/review/SKILL.md"
        for source in snapshot["sources"]
    )

with subtest("Standard model cannot create a forbidden child agent"):
    denied = operator(
        m2,
        dict(
            action="agent-prompt",
            actor_id=users["member_id"],
            vm_id=vm["vm_id"],
            prompt="Try child agent",
            key=str(uuid.uuid4()),
        ),
    )
    denied_turn = str(uuid.UUID(str(denied["turn_id"])))
    eventually(
        lambda: sql(f"SELECT status FROM agent_turns WHERE id='{denied_turn}'") == "failed",
        timeout=300,
    )
    result = operator(
        m3, dict(action="agent-result", actor_id=users["member_id"], turn_id=denied_turn)
    )
    assert result == {
        "status": "failed",
        "answer_matches": False,
        "reason": "capability_denied",
    }
    # Context collection precedes the model; the refused turn ran no guest tool.
    assert (
        sql(
            f"SELECT count(*) FROM agent_commands WHERE turn_id='{denied_turn}' "
            "AND tool NOT IN ('context_inventory', 'context_read')"
        )
        == "0"
    )
    assert (
        sql(f"SELECT count(*) FROM agent_threads WHERE parent_thread_id='{denied['thread_id']}'")
        == "0"
    )

with subtest("Rust guest fetch reaches a VM-local HTTP service with content-free audit"):
    fetched = operator(
        m2,
        dict(
            action="agent-prompt",
            actor_id=users["member_id"],
            vm_id=vm["vm_id"],
            prompt="Fetch local content",
            key=str(uuid.uuid4()),
        ),
    )
    fetched_id = str(uuid.UUID(str(fetched["turn_id"])))
    eventually(
        lambda: sql(f"SELECT status FROM agent_turns WHERE id='{fetched_id}'") == "completed",
        timeout=300,
    )
    assert (
        sql(
            f"SELECT count(*) FROM agent_commands WHERE turn_id='{fetched_id}' "
            "AND status='completed' AND tool NOT IN ('context_inventory', 'context_read')"
        )
        == "2"
    )
    assert (
        sql(
            f"SELECT result->>'content' FROM agent_commands WHERE turn_id='{fetched_id}' AND tool='web_fetch'"
        )
        == "# Guest local content"
    )
    assert (
        sql(
            f"SELECT count(*) FROM agent_audit_events WHERE turn_id='{fetched_id}' AND row_to_json(agent_audit_events)::text LIKE '%Guest local content%'"
        )
        == "0"
    )

with subtest("Marshall web search returns every synthetic result and caches the next call"):
    first = operator(
        m2,
        dict(
            action="agent-prompt",
            actor_id=users["member_id"],
            vm_id=vm["vm_id"],
            prompt="Search example topic",
            key=str(uuid.uuid4()),
        ),
    )
    first_id = str(uuid.UUID(str(first["turn_id"])))
    eventually(
        lambda: sql(f"SELECT status FROM agent_turns WHERE id='{first_id}'") == "completed",
        timeout=300,
    )
    assert (
        sql(
            f"SELECT credits FROM agent_search_usage WHERE command_id=(SELECT id FROM agent_commands WHERE turn_id='{first_id}' AND tool='web_search')"
        )
        == "3"
    )
    assert (
        sql(
            f"SELECT cache_hit FROM agent_search_usage WHERE command_id=(SELECT id FROM agent_commands WHERE turn_id='{first_id}' AND tool='web_search')"
        )
        == "f"
    )
    assert (
        sql(
            "SELECT result->'results'->1->>'url' FROM agent_commands "
            f"WHERE turn_id='{first_id}' AND tool='web_search'"
        )
        == "https://example.org/2"
    )

    second = operator(
        m3,
        dict(
            action="agent-prompt",
            actor_id=users["member_id"],
            vm_id=vm["vm_id"],
            prompt="Search example topic",
            key=str(uuid.uuid4()),
        ),
    )
    second_id = str(uuid.UUID(str(second["turn_id"])))
    eventually(
        lambda: sql(f"SELECT status FROM agent_turns WHERE id='{second_id}'") == "completed",
        timeout=300,
    )
    assert (
        sql(
            f"SELECT credits FROM agent_search_usage WHERE command_id=(SELECT id FROM agent_commands WHERE turn_id='{second_id}' AND tool='web_search')"
        )
        == "0"
    )
    assert (
        sql(
            f"SELECT cache_hit FROM agent_search_usage WHERE command_id=(SELECT id FROM agent_commands WHERE turn_id='{second_id}' AND tool='web_search')"
        )
        == "t"
    )
    assert (
        sql(
            f"SELECT count(*) FROM agent_audit_events WHERE turn_id='{second_id}' "
            "AND kind='tool_finished' AND target_id=(SELECT id FROM agent_commands "
            f"WHERE turn_id='{second_id}' AND tool='web_search')"
        )
        == "1"
    )
