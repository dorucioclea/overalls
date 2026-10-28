# @cc [owner:ghuntley,label:verification;security] thread-tool-journey
# Through the real guest and deterministic provider, the member's ADR-0252
# `thread` tool search, read, subscribe and replay MUST return only threads the
# member can read through Cedar (the owner's machine thread shared with the
# member, never the owner's private thread). The ADR-0255 Oban job
# MUST run every thread command without a guest executor identity, each MUST
# write one tool_finished audit row, and no log may contain thread titles.
# Revoking the member's share MUST move the member's subscription to `revoked`
# through the ADR-0261 job, deactivate its receivers and record one audit row.
# Fragment of the fleet driver: users, sql, operator and the server-tool setup
# helpers are defined by earlier fragments.


def seed_thread(owner: str, title: str, readers: list[str], bind_vm_id: str | None) -> str:
    request: dict[str, object] = dict(
        action="thread-seed", owner_id=owner, title=title, readers=readers
    )
    if bind_vm_id is not None:
        request["bind_vm_id"] = bind_vm_id
    result = server_tool_operator(m1, request)
    thread = str(uuid.UUID(str(result["thread_id"])))
    return thread


with subtest("two users' shared threads are seeded through the fixture surface"):
    owner_id = str(users["owner_id"])
    member_id = str(users["member_id"])
    # The shared thread becomes the owner's user thread for the fixture machine,
    # retaining a real agent binding the tool can read, subscribe to and replay;
    # the private thread stays unbound and unreadable by the member.
    shared_thread = seed_thread(owner_id, "Fleet shared plan", [member_id], server_tool_vm)
    private_thread = seed_thread(owner_id, "Fleet private plan", [], None)

with subtest("thread search, read, subscribe and replay honour Cedar read access"):
    thread_turn = server_tool_turn(server_tool_vm, "Use thread tool fixture")
    assert server_commands_unclaimed(thread_turn, "thread") == 4
    operations = sql(
        "SELECT string_agg(arguments->>'operation', ',' ORDER BY inserted_at) "
        f"FROM agent_commands WHERE turn_id='{thread_turn}' AND tool='thread'"
    )
    assert operations == "search,read,subscribe,replay", operations
    found = sql(
        "SELECT string_agg(item->>'id', ',') FROM agent_commands, "
        "jsonb_array_elements(result->'items') AS item "
        f"WHERE turn_id='{thread_turn}' AND tool='thread' AND arguments->>'operation'='search'"
    ).split(",")
    assert found == [shared_thread], "search did not return exactly the shared thread"
    assert private_thread not in found, "search returned an unreadable thread"
    targets = sql(
        "SELECT string_agg(DISTINCT arguments->>'thread_id', ',') FROM agent_commands "
        f"WHERE turn_id='{thread_turn}' AND tool='thread' AND arguments ? 'thread_id'"
    )
    assert targets == shared_thread, "tool targeted an unexpected thread"
    replay_events = sql(
        "SELECT jsonb_typeof(result->'items') FROM agent_commands "
        f"WHERE turn_id='{thread_turn}' AND tool='thread' AND arguments->>'operation'='replay'"
    )
    assert replay_events == "array"

with subtest("thread operations write audit rows and logs omit thread content"):
    audited = sql(
        "SELECT count(*) FROM agent_audit_events a JOIN agent_commands c ON c.id = a.target_id "
        f"WHERE c.turn_id='{thread_turn}' AND c.tool='thread' "
        "AND a.kind='tool_finished' AND a.outcome='completed'"
    )
    assert audited == "4", audited
    receivers = sql(
        "SELECT count(*) FROM agent_thread_receivers r JOIN agent_thread_tool_subscriptions s "
        "ON s.id = r.subscription_id "
        f"WHERE s.owner_id='{member_id}' AND r.state='active'"
    )
    assert receivers == "1", receivers
    journals = "".join(
        machine.succeed(f"journalctl -u marshall-{machine.name}.service --no-pager -o cat")
        for machine in [m1, m2, m3]
    )
    for title in ["Fleet shared plan", "Fleet private plan"]:
        assert title not in journals, "thread content reached the logs"

with subtest("revoking the share revokes the member's subscription"):
    server_tool_operator(
        m1,
        dict(
            action="thread-share",
            thread_id=shared_thread,
            owner_id=owner_id,
            user_id=member_id,
            role="revoked",
        ),
    )
    subscription_filter = f"owner_id='{member_id}' AND user_thread_id='{shared_thread}'"
    eventually(
        lambda: (
            sql(f"SELECT state FROM agent_thread_tool_subscriptions WHERE {subscription_filter}")
            == "revoked"
        ),
        timeout=180,
    )
    subscription = sql(
        f"SELECT id FROM agent_thread_tool_subscriptions WHERE {subscription_filter}"
    )
    assert (
        sql(
            "SELECT count(*) FROM agent_thread_receivers "
            f"WHERE subscription_id='{subscription}' AND state='active'"
        )
        == "0"
    )
    assert (
        sql(
            "SELECT count(*) FROM agent_audit_events "
            f"WHERE target_id='{subscription}' AND kind='thread_subscription_revoked'"
        )
        == "1"
    )
