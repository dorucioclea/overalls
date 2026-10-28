# @cc [owner:ghuntley,label:verification;security] artifact-agent-publish-journey
# Through the real guest, Lyra, Ziggy and the deterministic provider, an agent
# turn MUST publish inline content (version 1); a stale-base publish MUST be
# refused with a typed result and no new version; a guest-staged 3 MiB upload
# MUST publish version 2 with the exact file digest. A shared viewer MUST
# render the page over the real content listener and be refused shared-storage
# writes; revoking the share MUST stop the same live ticket on its next fetch.
# Audit rows and catalogued events MUST exist and no log may contain content.
# The owner's deletion MUST stop the owner's live ticket and leave a deleted
# tombstone. A purge interrupted after one batch by stopping every Marshall
# replica MUST finish after they restart with one `purged` audit row, and a
# server-tool command still queued across a restart of every replica MUST then
# run exactly once.
# Fragment of the fleet driver: users, sql, eventually, operator and the
# server-tool setup helpers are defined by earlier fragments.
import hashlib

STAGED_SHA256 = hashlib.sha256(b"a" * 3_145_728).hexdigest()
CONTENT_HOST = "usercontent.example.test"


def artifact_state(artifact: str) -> dict[str, object]:
    return server_tool_operator(m1, dict(action="artifact-state", artifact_id=artifact))


def string_list(value: object) -> list[str]:
    assert isinstance(value, list)
    result: list[str] = []
    for item in value:
        assert isinstance(item, str)
        result.append(item)
    return result


def string_map(value: object) -> dict[str, str]:
    assert isinstance(value, dict)
    result: dict[str, str] = {}
    for key, item in value.items():
        assert isinstance(key, str) and isinstance(item, str)
        result[key] = item
    return result


def content_fetch(ticket_value: str) -> tuple[int, str]:
    """Fetch the ticket's page from m1's real content listener; the body is
    written to a private file and only checked for fixed markers."""
    assert all(c.isalnum() or c in "-_" for c in ticket_value)
    status = m1.succeed(
        f"curl --silent --show-error --cacert {root}/ca.crt --resolve m1:6443:127.0.0.1 "
        f"--header 'Host: {CONTENT_HOST}' --output {root}/artifact-body "
        f"--write-out '%{{http_code}}' https://m1:6443/v/{ticket_value}/"
    ).strip()
    body = m1.succeed(f"cat {root}/artifact-body")
    m1.succeed(f"rm -f {root}/artifact-body")
    return int(status), body


def viewer_ticket(artifact: str, version: int, name: str, holder: str = "stranger_id") -> str:
    output = f"{root}/artifact-ticket-{name}"
    server_tool_operator(
        m1,
        dict(
            action="artifact-ticket",
            artifact_id=artifact,
            version=version,
            user_id=users[holder],
            output=output,
        ),
    )
    value = m1.succeed(f"cat {output}").strip()
    m1.succeed(f"rm -f {output}")
    return value


with subtest("an agent turn publishes inline content as version 1"):
    publish_turn = server_tool_turn(server_tool_vm, "Publish artifact fixture")
    assert server_commands_unclaimed(publish_turn, "artifact") == 1
    artifact_id = sql(
        "SELECT result->>'artifact_id' FROM agent_commands "
        f"WHERE turn_id='{publish_turn}' AND tool='artifact'"
    )
    assert str(uuid.UUID(artifact_id)) == artifact_id
    assert artifact_state(artifact_id)["current_version"] == 1

with subtest("a stale-base publish is refused and creates no version"):
    stale_turn = server_tool_turn(server_tool_vm, "Publish stale artifact fixture")
    assert server_commands_unclaimed(stale_turn, "artifact", "failed") == 1
    refusal = sql(
        "SELECT result->>'reason' FROM agent_commands "
        f"WHERE turn_id='{stale_turn}' AND tool='artifact'"
    )
    assert refusal == "stale_base_version", refusal
    stale_state = artifact_state(artifact_id)
    assert stale_state["current_version"] == 1 and stale_state["versions"] == 1

with subtest("a guest-staged large upload publishes version 2"):
    staged_turn = server_tool_turn(server_tool_vm, "Publish staged artifact fixture", timeout=600)
    assert server_commands_unclaimed(staged_turn, "artifact") == 1
    # The staging helper is executor work, not a server tool: it ran in the guest.
    assert (
        sql(
            f"SELECT count(*) FROM agent_commands WHERE turn_id='{staged_turn}' "
            "AND tool='exec_command' AND status='completed' AND executor_id IS NOT NULL"
        )
        == "1"
    )
    staged_state = artifact_state(artifact_id)
    assert staged_state["current_version"] == 2 and staged_state["versions"] == 2
    assert string_map(staged_state["file_sha256"]).get("large.txt") == STAGED_SHA256

with subtest("a shared viewer renders the page and cannot write shared storage"):
    unshared_ticket = viewer_ticket(artifact_id, 2, "unshared")
    status, body = content_fetch(unshared_ticket)
    assert status != 200 and "staged artifact" not in body, status
    server_tool_operator(
        m1,
        dict(
            action="artifact-share",
            artifact_id=artifact_id,
            owner_id=users["member_id"],
            user_id=users["stranger_id"],
            role="viewer",
        ),
    )
    live_ticket = viewer_ticket(artifact_id, 2, "viewer")
    status, body = content_fetch(live_ticket)
    assert status == 200 and "staged artifact" in body, status
    shared = server_tool_operator(
        m1,
        dict(
            action="artifact-storage",
            artifact_id=artifact_id,
            user_id=users["stranger_id"],
            scope="shared",
        ),
    )
    assert shared == {"written": False, "reason": "forbidden"}, shared
    personal = server_tool_operator(
        m1,
        dict(
            action="artifact-storage",
            artifact_id=artifact_id,
            user_id=users["stranger_id"],
            scope="personal",
        ),
    )
    assert personal == {"written": True, "reason": None}, personal

with subtest("revoking the share stops a live ticket on its next fetch"):
    server_tool_operator(
        m1,
        dict(
            action="artifact-share",
            artifact_id=artifact_id,
            owner_id=users["member_id"],
            user_id=users["stranger_id"],
            role="revoked",
        ),
    )
    status, body = content_fetch(live_ticket)
    assert status != 200 and "staged artifact" not in body, status

with subtest("audit rows and catalogued events exist and logs carry no payload"):
    kinds = string_list(artifact_state(artifact_id)["audit_kinds"])
    for kind in ["published", "publish_refused", "ticket_issued", "storage_refused"]:
        assert kind in kinds, kind
    assert kinds.count("published") == 2
    journals = "".join(
        machine.succeed(f"journalctl -u marshall-{machine.name}.service --no-pager -o cat")
        for machine in [m1, m2, m3]
    )
    assert "artifact.published" in journals and "artifact.publish_refused" in journals
    for secret in ["fleet artifact v1", "staged artifact", "<p>stale</p>", live_ticket]:
        assert secret not in journals, "artifact content or a ticket reached the logs"

MARSHALLS = [m1, m2, m3]
CONTENT_TABLES = [
    "artifact_storage_entries",
    "artifact_storage_usage",
    "artifact_view_tickets",
    "artifact_version_files",
    "artifact_versions",
]


def content_rows(artifact: str) -> int:
    assert str(uuid.UUID(artifact)) == artifact
    return sum(
        int(sql(f"SELECT count(*) FROM {table} WHERE artifact_id='{artifact}'"))
        for table in CONTENT_TABLES
    )


def artifact_row_state(artifact: str) -> str:
    assert str(uuid.UUID(artifact)) == artifact
    return sql(f"SELECT state FROM artifacts WHERE id='{artifact}'")


def purged_audits(artifact: str) -> str:
    return sql(
        f"SELECT count(*) FROM artifact_audit_events WHERE artifact_id='{artifact}' "
        "AND kind='purged'"
    )


def restart_marshalls() -> None:
    for machine in MARSHALLS:
        machine.succeed(f"systemctl restart marshall-{machine.name}.service")
    for machine in MARSHALLS:
        machine.wait_for_unit(f"marshall-{machine.name}.service")


with subtest("the owner's deletion stops a live ticket and leaves a tombstone"):
    owner_ticket = viewer_ticket(artifact_id, 2, "owner", holder="member_id")
    status, body = content_fetch(owner_ticket)
    assert status == 200 and "staged artifact" in body, status
    server_tool_operator(
        m1, dict(action="artifact-delete", artifact_id=artifact_id, owner_id=users["member_id"])
    )
    status, body = content_fetch(owner_ticket)
    assert status != 200 and "staged artifact" not in body, status
    eventually(lambda: artifact_row_state(artifact_id) == "deleted", timeout=180)
    assert content_rows(artifact_id) == 0 and purged_audits(artifact_id) == "1"

with subtest("a purge interrupted by stopping every replica finishes after restart"):
    for machine in MARSHALLS:
        machine.succeed(f"systemctl stop marshall-{machine.name}.service")
    interrupted = server_tool_operator(
        m1,
        dict(action="artifact-purge-interrupted", owner_id=users["member_id"], entries=2500),
    )
    purge_id = str(uuid.UUID(str(interrupted["artifact_id"])))
    assert artifact_row_state(purge_id) == "deleting"
    remaining = content_rows(purge_id)
    assert 0 < remaining < 2500, remaining
    assert purged_audits(purge_id) == "0"
    for machine in MARSHALLS:
        machine.succeed(f"systemctl start marshall-{machine.name}.service")
    for machine in MARSHALLS:
        machine.wait_for_unit(f"marshall-{machine.name}.service")
    eventually(lambda: artifact_row_state(purge_id) == "deleted", timeout=300)
    assert content_rows(purge_id) == 0 and purged_audits(purge_id) == "1"

with subtest("a server-tool command queued across a full restart runs exactly once"):
    server_tool_operator(m1, dict(action="pause-agent-tools"))
    submitted = server_tool_operator(
        m2,
        dict(
            action="server-tool-prompt",
            actor_id=users["member_id"],
            vm_id=server_tool_vm,
            prompt="Publish restarted artifact fixture",
            key=str(uuid.uuid4()),
        ),
    )
    restart_turn = str(uuid.UUID(str(submitted["turn_id"])))
    eventually(
        lambda: (
            sql(
                f"SELECT count(*) FROM agent_commands WHERE turn_id='{restart_turn}' "
                "AND tool='artifact' AND status='queued'"
            )
            == "1"
        ),
        timeout=300,
    )
    restart_marshalls()
    eventually(
        lambda: (
            sql(f"SELECT status FROM agent_turns WHERE id='{restart_turn}'")
            in ("completed", "failed")
        ),
        timeout=300,
    )
    assert sql(f"SELECT status FROM agent_turns WHERE id='{restart_turn}'") == "completed"
    assert server_commands_unclaimed(restart_turn, "artifact") == 1
    restarted_command = sql(
        f"SELECT id FROM agent_commands WHERE turn_id='{restart_turn}' AND tool='artifact'"
    )
    assert (
        sql(
            "SELECT count(*) FROM agent_audit_events "
            f"WHERE target_id='{restarted_command}' AND kind='tool_finished'"
        )
        == "1"
    )
    restarted_artifact = sql(
        f"SELECT result->>'artifact_id' FROM agent_commands WHERE id='{restarted_command}'"
    )
    assert artifact_state(restarted_artifact)["current_version"] == 1
