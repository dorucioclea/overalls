# @cc [owner:ghuntley,label:verification;security] fleet-server-tool-guest-setup
# Server-tool journeys (artifact, thread) run on the same real guest topology as
# the agent fleet: a shared operator's prompt reaches a source-built Lyra
# executor through Ziggy and the deterministic provider. Server-tool commands
# MUST then execute in Marshall; the fixture never claims or completes them.
# Requires the agent scenario's first subtest (host services) to have run.


def server_tool_operator(
    machine: MachineLike, request: dict[str, object], timeout: int = 180
) -> dict[str, object]:
    """Run one request through the server-tool fixture operator script."""
    path = request_file(machine, request)
    output = machine.succeed(
        "FLEET_OPERATOR_SCRIPT=/etc/fleet-server-tool-operator.exs fleet-op " + shlex.quote(path),
        timeout=timeout,
    )
    rows = [
        line.removeprefix("FLEET_OK ")
        for line in output.splitlines()
        if line.startswith("FLEET_OK ")
    ]
    assert len(rows) == 1
    result: dict[str, object] = json.loads(rows[0])
    return result


def server_tool_turn(vm_id: str, prompt: str, timeout: int = 300) -> str:
    """Submit a fixed fixture prompt as the shared member and await completion."""
    submitted = server_tool_operator(
        m2,
        dict(
            action="server-tool-prompt",
            actor_id=users["member_id"],
            vm_id=vm_id,
            prompt=prompt,
            key=str(uuid.uuid4()),
        ),
    )
    turn = str(uuid.UUID(str(submitted["turn_id"])))
    eventually(
        lambda: sql(f"SELECT status FROM agent_turns WHERE id='{turn}'") in ("completed", "failed"),
        timeout=timeout,
    )
    status = sql(f"SELECT status FROM agent_turns WHERE id='{turn}'")
    # Closed enum columns only: no prompt, argument or result payload.
    failure = sql(f"SELECT coalesce(failure_reason, '') FROM agent_turns WHERE id='{turn}'")
    commands = sql(
        "SELECT coalesce(string_agg(tool || ':' || status || ':' || "
        "coalesce(result->>'reason', ''), ',' ORDER BY inserted_at), '') "
        f"FROM agent_commands WHERE turn_id='{turn}'"
    )
    calls = sql(
        "SELECT coalesce(string_agg(status, ',' ORDER BY inserted_at), '') "
        f"FROM agent_model_calls WHERE turn_id='{turn}'"
    )
    assert status == "completed", (status, failure, commands, calls)
    result = operator(m3, dict(action="agent-result", actor_id=users["member_id"], turn_id=turn))
    assert result == {"status": "completed", "answer_matches": True, "reason": None}, result
    return turn


def server_commands_unclaimed(turn: str, tool: str, status: str = "completed") -> int:
    """@cc [owner:ghuntley,label:verification;security] fleet-server-tool-never-claimed
    Server-tool commands MUST complete without any guest executor identity or
    fence. A typed server tool (`artifact`) records only Marshall's claim_id,
    which fences its finish, so every finished one carries it. `thread` claims,
    runs and finishes in one transaction under its row lock and records none.
    A typed refusal finishes `failed`; returns the number of commands in `status`.
    """
    assert str(uuid.UUID(turn)) == turn and tool in ("artifact", "thread")
    assert status in ("completed", "failed")
    typed_claim = (
        " OR (status IN ('completed', 'failed') AND claim_id IS NULL)" if tool == "artifact" else ""
    )
    claimed = sql(
        f"SELECT count(*) FROM agent_commands WHERE turn_id='{turn}' AND tool='{tool}' "
        f"AND (executor_id IS NOT NULL OR fence_epoch IS NOT NULL{typed_claim})"
    )
    assert claimed == "0", "a guest executor claimed a server-tool command"
    return int(
        sql(
            f"SELECT count(*) FROM agent_commands WHERE turn_id='{turn}' AND tool='{tool}' "
            f"AND status='{status}'"
        )
    )


with subtest("server-tool guest executor is current and shared with the member"):
    vm = provision_when_available(m1, "standard", disk_bytes=6_442_450_944)
    await_running(vm["vm_id"])
    for command in ["agent-service", "agent-route"]:
        host_for(vm).wait_until_succeeds(
            f"fleet-galileo-guest {command} " + shlex.quote(vm["placement_id"]), timeout=120
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
    for command in ["agent-update", "agent-reset", "agent-update"]:
        host_for(vm).wait_until_succeeds(
            f"fleet-galileo-guest {command} "
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
    server_tool_vm = str(vm["vm_id"])
