import base64
import hashlib
import json

from hegel import (
    MachineStateMachine,
    TestCase,
    assume,
    given,
    integers,
    invariant,
    just,
    one_of,
    optional,
    rule,
    sampled_from,
    text,
    uuids,
)

client.start()
client.wait_for_unit("agent-cli-fixture.service")
client.wait_until_succeeds(
    "curl --silent --show-error --max-time 5 --output /dev/null "
    "https://control.test:8443/api/agents/v1/session?vm_id=11111111-1111-4111-8111-111111111111"
)
client.succeed("install -d -m 700 /root/.config/overalls")
client.succeed(
    "printf '%s' '"
    + json.dumps({"origin": "https://control.test:8443", "zone": "vm.test"})
    + "' >/root/.config/overalls/config.json"
)
client.succeed("printf 'fixture prompt\n' >/run/agent-cli-fixture/prompt.txt")
client.succeed(
    "systemd-run --quiet --no-block --unit=agent-cli-test "
    "--setenv=HOME=/root --setenv=PATH=" + client_path + " --property=Type=oneshot "
    "--property=RemainAfterExit=yes "
    + shell_binary
    + " -c '"
    + overalls_binary
    + " agent --machine 11111111-1111-4111-8111-111111111111 "
    "</run/agent-cli-fixture/prompt.txt "
    ">/run/agent-cli-fixture/stdout 2>/run/agent-cli-fixture/stderr'"
)
client.wait_until_succeeds(
    "test -s /run/agent-cli-fixture/code || systemctl is-failed agent-cli-test.service"
)
assert client.execute("test -s /run/agent-cli-fixture/code")[0] == 0, client.succeed(
    "cat /run/agent-cli-fixture/stderr"
)
code = client.succeed("cat /run/agent-cli-fixture/code").strip()
assert len(code) == 64 and all(character in "0123456789abcdef" for character in code)
stderr = client.succeed("cat /run/agent-cli-fixture/stderr")
assert f"/agents/cli/approve/11111111-1111-4111-8111-111111111111/{code}" in stderr
assert "overalls_agent_" not in stderr
client.succeed("touch /run/agent-cli-fixture/approved")
client.wait_for_unit("agent-cli-test.service", timeout=60)
client.succeed("grep -Fx 'fixture agent reply' /run/agent-cli-fixture/stdout")
client.succeed("test -f /run/agent-cli-fixture/prompt-received")
logs = client.succeed(
    "journalctl -u agent-cli-fixture.service -u agent-cli-test.service --no-pager"
)
assert "fixture prompt" not in logs
assert "overalls_agent_" not in logs

VM_ID = "11111111-1111-4111-8111-111111111111"
OTHER_VM_ID = "99999999-9999-4999-8999-999999999999"
THREAD_ID = "22222222-2222-4222-8222-222222222222"
TURN_ID = "33333333-3333-4333-8333-333333333333"
BEARER_PREFIX = "overalls_agent_"
HEX_ALPHABET = "0123456789abcdef"
BEARER_ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._~-"
UUID_ALPHABET = "0123456789abcdef-"
SESSION_ROUTE = f"/api/agents/v1/session?vm_id={VM_ID}"
THREADS_ROUTE = f"/api/agents/v1/threads?vm_id={VM_ID}"
TURN_ROUTE = f"/api/agents/v1/turn/{TURN_ID}?vm_id={VM_ID}"


def _well_formed_bearer(value: str) -> bool:
    """Mirror the fixture's single-bearer acceptance predicate exactly."""
    return value.startswith(BEARER_PREFIX) and len(value) == len(BEARER_PREFIX) + 64


def _valid_uuid(value: str) -> bool:
    """Mirror the CLI's UUID gate exactly (dashes fixed, otherwise hexdigit)."""
    if len(value) != 36:
        return False
    return all(
        (character == "-") if index in (8, 13, 18, 23) else character in "0123456789abcdefABCDEF"
        for index, character in enumerate(value)
    )


def _request(
    method: str, route: str, bearer: str | None = None, body_path: str | None = None
) -> tuple[int, object]:
    """Probe the fixture over verified HTTPS; return the status and parsed body."""
    parts = [
        "curl --silent --show-error --max-time 10 --output /tmp/hegel-response-body",
        f"--request {method}",
        "-w '%{http_code}'",
    ]
    if bearer is not None:
        parts.append(f"--header 'Authorization: Bearer {bearer}'")
    if body_path is not None:
        parts.append("--header 'content-type: application/json'")
        parts.append(f"--data @{body_path}")
    parts.append(f"'https://control.test:8443{route}'")
    status = int(client.succeed(" ".join(parts)).strip())
    return status, json.loads(client.succeed("cat /tmp/hegel-response-body"))


def _prompt_payload(kind: str, request_key: str) -> str:
    """Serialize one fixture POST shape; only a fully valid shape may succeed."""
    if kind == "malformed-json":
        return '{"vm_id": '
    if kind == "array-body":
        return "[1, 2, 3]"
    body: dict[str, object] = {
        "vm_id": VM_ID,
        "thread_id": THREAD_ID,
        "prompt": "fixture prompt",
        "request_key": request_key,
    }
    if kind == "wrong-vm":
        body["vm_id"] = OTHER_VM_ID
    elif kind == "wrong-thread":
        body["thread_id"] = OTHER_VM_ID
    elif kind == "wrong-prompt":
        body["prompt"] = "doctored fixture prompt"
    elif kind == "non-string-key":
        body["request_key"] = 9001
    elif kind == "missing-prompt":
        del body["prompt"]
    return json.dumps(body)


@given(
    method=sampled_from(["GET", "POST"]),
    route=sampled_from(
        [
            SESSION_ROUTE,
            THREADS_ROUTE,
            TURN_ROUTE,
            "/api/agents/v1/prompt",
            "/api/agents/v1/nonexistent",
            "/",
        ]
    ),
    bearer=optional(
        text(min_size=0, max_size=96, alphabet=BEARER_ALPHABET).filter(
            lambda value: not _well_formed_bearer(value)
        )
    ),
)
def unauthenticated_requests_refused(
    tc: TestCase, method: str, route: str, bearer: str | None
) -> None:
    status, body = _request(method, route, bearer=bearer)
    assert status == 403
    assert body == {"error": "machine_unavailable"}


@given(
    machine_id=text(min_size=0, max_size=48, alphabet=UUID_ALPHABET).filter(
        lambda value: not _valid_uuid(value) and not value.startswith("-")
    )
)
def cli_rejects_malformed_machine_ids(tc: TestCase, machine_id: str) -> None:
    client.fail(
        f"{overalls_binary} agent --machine '{machine_id}' </dev/null 2>/tmp/hegel-cli-stderr"
    )
    client.succeed("grep -F 'invalid machine or thread ID' /tmp/hegel-cli-stderr")
    client.fail(f"grep -F {BEARER_PREFIX} /tmp/hegel-cli-stderr")


@given(size=one_of(just(0), integers(min_value=65537, max_value=66048)))
def cli_rejects_out_of_bounds_prompt_sizes(tc: TestCase, size: int) -> None:
    client.succeed(f'python3 -c \'open("/tmp/hegel-prompt-size.txt", "w").write("a" * {size})\'')
    client.fail(
        f"{overalls_binary} agent --machine {VM_ID} "
        "</tmp/hegel-prompt-size.txt 2>/tmp/hegel-cli-stderr"
    )
    client.succeed("grep -F 'prompt unavailable' /tmp/hegel-cli-stderr")
    client.fail(f"grep -F {BEARER_PREFIX} /tmp/hegel-cli-stderr")


class PairedFixtureLifecycle(MachineStateMachine):
    """Driver-paired lifecycle: pairing, approval revocation, restart recovery."""

    def setup(self) -> None:
        self._restart_fixture()

    def _restart_fixture(self) -> None:
        client.systemctl("restart agent-cli-fixture.service")
        client.wait_for_unit("agent-cli-fixture.service")
        client.wait_until_succeeds(
            f"curl --silent --max-time 5 --output /dev/null 'https://control.test:8443{SESSION_ROUTE}'"
        )
        self.token: str | None = None
        self.approved: bool = False
        self.prompted: bool = False

    def _stage_body(self, raw: str) -> None:
        encoded = base64.b64encode(raw.encode()).decode()
        client.succeed(f"echo {encoded} | base64 --decode >/tmp/hegel-request-body")

    @rule(weight=4, suffix=text(min_size=64, max_size=64, alphabet=HEX_ALPHABET))
    def pair_first_well_formed_bearer(self, suffix: str) -> None:
        assume(self.token is None, "fixture already paired in this case")
        bearer = BEARER_PREFIX + suffix
        status, body = _request("GET", SESSION_ROUTE, bearer=bearer)
        expected = {"status": "approved" if self.approved else "pending"}
        assert status == 200 and body == expected
        digest = hashlib.sha256(bearer.encode()).hexdigest()
        assert client.succeed("cat /run/agent-cli-fixture/code").strip() == digest
        self.token = bearer

    @rule(
        weight=3,
        suffix=text(min_size=64, max_size=64, alphabet=HEX_ALPHABET),
        route=sampled_from([SESSION_ROUTE, THREADS_ROUTE, TURN_ROUTE]),
    )
    def reject_foreign_bearer(self, suffix: str, route: str) -> None:
        assume(self.token is not None, "pairing not established yet")
        bearer = BEARER_PREFIX + suffix
        assume(bearer != self.token, "drew the paired bearer")
        status, body = _request("GET", route, bearer=bearer)
        assert status == 403 and body == {"error": "machine_unavailable"}

    @rule(weight=2)
    def approve_pairing(self) -> None:
        client.succeed("touch /run/agent-cli-fixture/approved")
        self.approved = True

    @rule(weight=1)
    def revoke_approval(self) -> None:
        client.succeed("rm -f /run/agent-cli-fixture/approved")
        self.approved = False

    @rule(weight=1)
    def recover_across_restart(self) -> None:
        self._restart_fixture()

    @rule(weight=3)
    def session_status_tracks_approval(self) -> None:
        assume(self.token is not None, "pairing not established yet")
        status, body = _request("GET", SESSION_ROUTE, bearer=self.token)
        assert status == 200
        assert body == {"status": "approved" if self.approved else "pending"}

    @rule(
        weight=2,
        query=sampled_from(["", "?vm_id=", f"?vm_id={OTHER_VM_ID}", f"?machine={VM_ID}"]),
    )
    def reject_malformed_session_query(self, query: str) -> None:
        assume(self.token is not None, "pairing not established yet")
        status, body = _request("GET", "/api/agents/v1/session" + query, bearer=self.token)
        assert status == 400 and body == {"error": "invalid_request"}

    @rule(weight=2)
    def threads_require_approval(self) -> None:
        assume(self.token is not None, "pairing not established yet")
        status, body = _request("GET", THREADS_ROUTE, bearer=self.token)
        if not self.approved:
            assert status == 403 and body == {"error": "machine_unavailable"}
            return
        assert status == 200
        assert body == {"threads": [{"id": THREAD_ID, "title": "Root", "parent_thread_id": None}]}

    @rule(weight=2)
    def terminal_result_tracks_prompt(self) -> None:
        assume(self.token is not None, "pairing not established yet")
        status, body = _request("GET", TURN_ROUTE, bearer=self.token)
        if not self.approved:
            assert status == 403 and body == {"error": "machine_unavailable"}
        elif self.prompted:
            assert status == 200
            assert body == {
                "id": TURN_ID,
                "status": "completed",
                "text": "fixture agent reply",
            }
        else:
            assert status == 200
            assert body == {"id": TURN_ID, "status": "queued"}

    @rule(
        weight=2,
        route=sampled_from(["/api/agents/v1/nonexistent", "/api/agents/v1", "/"]),
    )
    def unknown_get_route(self, route: str) -> None:
        assume(self.token is not None, "pairing not established yet")
        status, body = _request("GET", route + f"?vm_id={VM_ID}", bearer=self.token)
        if not self.approved:
            assert status == 403 and body == {"error": "machine_unavailable"}
        else:
            assert status == 404 and body == {"error": "not_found"}

    @rule(weight=2, request_key=uuids())
    def prompt_requires_approval(self, request_key: str) -> None:
        assume(self.token is not None and not self.approved, "unapproved pairing required")
        self._stage_body(_prompt_payload("valid", request_key))
        status, body = _request(
            "POST",
            "/api/agents/v1/prompt",
            bearer=self.token,
            body_path="/tmp/hegel-request-body",
        )
        assert status == 403 and body == {"error": "machine_unavailable"}

    @rule(
        weight=3,
        kind=sampled_from(
            [
                "valid",
                "wrong-vm",
                "wrong-thread",
                "wrong-prompt",
                "non-string-key",
                "missing-prompt",
                "array-body",
                "malformed-json",
            ]
        ),
        request_key=uuids(),
    )
    def prompt_shape_gate(self, kind: str, request_key: str) -> None:
        assume(self.token is not None and self.approved, "approved pairing required")
        self._stage_body(_prompt_payload(kind, request_key))
        status, body = _request(
            "POST",
            "/api/agents/v1/prompt",
            bearer=self.token,
            body_path="/tmp/hegel-request-body",
        )
        if kind != "valid":
            assert status == 400 and body == {"error": "invalid_request"}
            return
        assert status == 200
        assert body == {"turn_id": TURN_ID, "status": "queued"}
        self.prompted = True

    @invariant(always=True)
    def malformed_bearer_always_refused(self) -> None:
        status, body = _request("GET", SESSION_ROUTE, bearer="not-a-token")
        assert status == 403 and body == {"error": "machine_unavailable"}

    @invariant(always=False)
    def journals_carry_no_secret_material(self) -> None:
        logs = client.succeed(
            "journalctl -u agent-cli-fixture.service -u agent-cli-test.service --no-pager"
        )
        assert BEARER_PREFIX not in logs
        assert "fixture prompt" not in logs


PairedFixtureLifecycle.run()
