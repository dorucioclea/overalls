"""Ordinary login and privileged step-up across three packaged Marshall replicas."""

import subprocess
import time
from collections.abc import Callable
from pathlib import Path
from typing import TypeGuard
from uuid import UUID

from playwright._impl._api_structures import SetCookieParam
from playwright.sync_api import (
    BrowserContext,
    CDPSession,
    Cookie,
    Dialog,
    Error,
    Page,
    expect,
    sync_playwright,
)

ORIGIN = "https://localhost"


def is_object_dict(value: object) -> TypeGuard[dict[object, object]]:
    return isinstance(value, dict)


def copy_cookie(cookie: Cookie) -> SetCookieParam:
    return {
        "name": cookie["name"],
        "value": cookie["value"],
        "domain": cookie["domain"],
        "path": cookie["path"],
        "expires": cookie["expires"],
        "httpOnly": cookie["httpOnly"],
        "secure": cookie["secure"],
        "sameSite": cookie["sameSite"],
    }


def sql(statement: str) -> str:
    """Read only the isolated VM's disposable database; never print credentials."""
    return subprocess.run(
        ["runuser", "-u", "postgres", "--", "psql", "-XAt", "-v", "ON_ERROR_STOP=1", "marshall"],
        input=statement,
        text=True,
        capture_output=True,
        check=True,
    ).stdout.strip()


def fixture_id(name: str) -> str:
    assert name in {"reader", "admin", "plain"}
    return str(UUID(sql(f"SELECT id FROM users WHERE email = '{name}@example.test';")))


def wait_sql(statement: str, expected: str) -> None:
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if sql(statement) == expected:
            return
        time.sleep(0.05)
    raise AssertionError("Fixture state did not reach the expected committed result")


def select_replica(context: BrowserContext, replica: str) -> None:
    assert replica in {"first", "second", "third"}
    context.add_cookies(
        [{"name": "fixture_replica", "value": replica, "url": ORIGIN, "secure": True}]
    )


def observe_sockets(
    context: BrowserContext, page: Page, expected: str
) -> tuple[CDPSession, list[str], Callable[[str], None]]:
    """Validate actual proxy backend for every WebSocket handshake, without URLs."""
    observed: list[str] = []
    state = {"expected": expected}
    session = context.new_cdp_session(page)

    def handshake(event: dict[str, object]) -> None:
        response = event.get("response")
        assert is_object_dict(response)
        headers: object = response.get("headers")
        assert isinstance(headers, dict)
        backend: object = next(
            (
                value
                for name, value in headers.items()
                if isinstance(name, str) and name.lower() == "x-fixture-replica"
            ),
            None,
        )
        assert isinstance(backend, str) and backend == state["expected"]
        observed.append(backend)

    def set_expected(replica: str) -> None:
        assert replica in {"first", "second", "third"}
        state["expected"] = replica

    session.send("Network.enable")
    session.on("Network.webSocketHandshakeResponseReceived", handshake)
    return session, observed, set_expected


def enable_authenticator(session: CDPSession) -> None:
    session.send("WebAuthn.enable")
    session.send(
        "WebAuthn.addVirtualAuthenticator",
        {
            "options": {
                "protocol": "ctap2",
                "transport": "internal",
                "hasResidentKey": True,
                "hasUserVerification": True,
                "isUserVerified": True,
                "automaticPresenceSimulation": True,
            }
        },
    )


def visit(page: Page, path: str, replica: str, destination: str | None = None) -> None:
    response = page.goto(ORIGIN + path)
    assert response is not None and response.headers.get("x-fixture-replica") == replica
    expect(page).to_have_url(ORIGIN + (destination or path))
    expect(page.locator("[data-phx-main].phx-connected")).to_be_visible()


def sign_in(page: Page, name: str, login: str, replica: str, remember: bool = False) -> None:
    token = Path(f"/run/overalls-test/mfa-{name}-{login}").read_text().strip()
    try:
        response = page.goto(ORIGIN + "/magic_link/" + token)
        assert response is not None and response.headers.get("x-fixture-replica") == replica
        expect(page.locator("[data-phx-main].phx-connected")).to_be_visible()
        page.wait_for_url("**/overview")
        if remember:
            assert any("remember" in cookie["name"] for cookie in page.context.cookies())
    except (Error, AssertionError):
        raise AssertionError("Automatic fixture magic-link sign-in failed") from None
    expect(page.locator("[data-phx-main].phx-connected")).to_be_visible()


def export_status(page: Page, replica: str) -> int:
    result: object = page.evaluate("""async () => {
      const response = await fetch('/admin/usage/export');
      return {status: response.status, replica: response.headers.get('x-fixture-replica')};
    }""")
    assert is_object_dict(result) and result.get("replica") == replica
    status: object = result.get("status")
    assert isinstance(status, int)
    return status


def verify(page: Page) -> None:
    page.locator("#verify-passkey").click()
    expect(page.locator("#verification-status")).to_contain_text("Passkey verified")
    expect(page.locator("#security-continue")).to_be_visible()


def ordinary_access(page: Page, replica: str) -> None:
    for path in ["/overview", "/admin/users"]:
        visit(page, path, replica)
    assert export_status(page, replica) == 200


def accept_dialog(dialog: Dialog) -> None:
    dialog.accept()


def main() -> None:
    """@cc [owner:ghuntley,label:verification] native-subsequent-mfa-login
    Subsequent magic-link and remembered logins MUST allow ordinary workspace,
    Control room and export access without inheriting passkey elevation.
    An administrator without a passkey MUST enroll, return to the original page,
    and explicitly retry before inline verification executes the mutation once.
    Admin-UI revocation on a
    second serving replica MUST invalidate the mounted first and copied cookies
    on a third. Replica observations MUST include actual WebSocket handshakes.
    A ceremony finished after its database-side challenge deadline MUST be
    refused without elevation, and a fresh begin/verify MUST then succeed on a
    different serving replica, proving challenge expiry comes from the shared
    Postgres clock rather than node-local state.
    """
    reader_id, admin_id = (fixture_id(name) for name in ["reader", "admin"])
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path="/run/current-system/sw/bin/chromium", args=["--no-sandbox"]
        )
        reader_context = browser.new_context()
        select_replica(reader_context, "first")
        reader = reader_context.new_page()
        reader_cdp, reader_sockets, reader_set_replica = observe_sockets(
            reader_context, reader, "first"
        )
        enable_authenticator(reader_cdp)
        sign_in(reader, "reader", "initial", "first")
        assert sql(f"SELECT administrator FROM users WHERE id = '{reader_id}';") == "f"
        visit(reader, "/settings", "first")
        reader.locator("#add-passkey").click()
        expect(reader.locator("#passkey-list > div")).to_have_count(1)
        verify(reader)
        visit(reader, "/overview", "first")
        assert export_status(reader, "first") == 200
        signed_out_cookies = [copy_cookie(cookie) for cookie in reader_context.cookies()]
        reader.goto(ORIGIN + "/sign-out")
        reader.get_by_role("button", name="Sign out", exact=True).click()
        expect(reader).to_have_url(ORIGIN + "/sign-in")

        old_context = browser.new_context()
        old_context.add_cookies(signed_out_cookies)
        select_replica(old_context, "third")
        old_page = old_context.new_page()
        visit(old_page, "/admin/users", "third", "/sign-in")
        assert export_status(old_page, "third") == 404
        old_context.close()

        sign_in(reader, "reader", "subsequent", "first", remember=True)
        ordinary_access(reader, "first")
        visit(reader, "/settings", "first")
        expect(reader.locator("#security-continue")).to_have_count(0)
        verify(reader)
        visit(reader, "/admin/users", "first")
        assert export_status(reader, "first") == 200

        # Dropping only the session cookie models restarting a browser while its
        # persistent remember cookie survives. The same virtual device remains.
        cookies = [copy_cookie(cookie) for cookie in reader_context.cookies()]
        remember = [cookie for cookie in cookies if "remember" in cookie["name"]]
        assert len(remember) == 1
        remember_expiry = remember[0]["expires"]
        assert isinstance(remember_expiry, (int, float)) and remember_expiry > 0
        reader_context.clear_cookies()
        reader_context.add_cookies(remember)
        select_replica(reader_context, "first")
        visit(reader, "/overview", "first")
        ordinary_access(reader, "first")
        visit(reader, "/settings", "first")
        expect(reader.locator("#security-continue")).to_have_count(0)
        verify(reader)
        visit(reader, "/admin/users", "first")
        assert export_status(reader, "first") == 200
        stale_cookies = [copy_cookie(cookie) for cookie in reader_context.cookies()]
        assert sql(f"SELECT administrator FROM users WHERE id = '{reader_id}';") == "f"

        admin_context = browser.new_context()
        select_replica(admin_context, "second")
        admin = admin_context.new_page()
        admin.on("dialog", accept_dialog)
        admin_cdp, admin_sockets, _ = observe_sockets(admin_context, admin, "second")
        enable_authenticator(admin_cdp)
        sign_in(admin, "admin", "initial", "second")
        visit(admin, "/admin/users", "second")
        admin.locator(f"#sessions-{reader_id}").click()
        expect(admin).to_have_url(ORIGIN + "/settings?return_to=%2Fadmin%2Fusers#security")
        expect(admin.locator("[data-phx-main].phx-connected")).to_be_visible()
        admin.locator("#add-passkey").click()
        expect(admin.locator("#passkey-list > div")).to_have_count(1)
        assert (
            sql(
                f"SELECT count(*) FROM account_admin_events WHERE kind = 'sessions_revoke' AND actor_id = '{admin_id}' AND target_id = '{reader_id}';"
            )
            == "0"
        )
        admin.locator("#security-continue").click()
        expect(admin).to_have_url(ORIGIN + "/admin/users")
        expect(admin.locator("[data-phx-main].phx-connected")).to_be_visible()
        assert reader_sockets and admin_sockets
        admin.locator(f"#sessions-{reader_id}").click()
        expect(admin.locator("#admin-elevation-modal")).to_be_visible()
        assert (
            sql(
                f"SELECT count(*) FROM account_admin_events WHERE kind = 'sessions_revoke' AND actor_id = '{admin_id}' AND target_id = '{reader_id}';"
            )
            == "0"
        )
        admin.locator("#admin-elevation-verify").click()
        expect(admin.locator("#admin-elevation-modal")).not_to_be_visible()
        expect(admin.locator("#flash-info")).to_contain_text("Browser sessions revoked")
        assert (
            sql(
                f"SELECT count(*) FROM account_admin_events WHERE kind = 'sessions_revoke' AND actor_id = '{admin_id}' AND target_id = '{reader_id}';"
            )
            == "1"
        )
        assert (
            sql(
                f"SELECT EXTRACT(EPOCH FROM elevated_until - verified_at) = 900 FROM account_verifications WHERE user_id = '{admin_id}' AND verified_at IS NOT NULL ORDER BY verified_at DESC LIMIT 1;"
            )
            == "t"
        )
        expect(reader).to_have_url(ORIGIN + "/sign-in", timeout=15000)
        assert export_status(reader, "first") == 404

        third_context = browser.new_context()
        third_context.add_cookies(stale_cookies)
        select_replica(third_context, "third")
        third = third_context.new_page()
        _, third_sockets, _ = observe_sockets(third_context, third, "third")
        for path in ["/overview", "/admin/users"]:
            visit(third, path, "third", "/sign-in")
        assert export_status(third, "third") == 404
        assert third_sockets
        third_context.clear_cookies()
        third_context.add_cookies(
            [cookie for cookie in stale_cookies if "remember" in cookie["name"]]
        )
        select_replica(third_context, "third")
        visit(third, "/overview", "third", "/sign-in")
        assert sql(f"SELECT administrator FROM users WHERE id = '{reader_id}';") == "f"
        # Revocation must remove remembered ordinary access for both enrolled
        # and unenrolled identities.
        plain_context = browser.new_context()
        select_replica(plain_context, "third")
        plain = plain_context.new_page()
        _, plain_sockets, _ = observe_sockets(plain_context, plain, "third")
        sign_in(plain, "plain", "initial", "third", remember=True)
        assert export_status(plain, "third") == 200
        plain_id = fixture_id("plain")
        assert (
            sql(f"SELECT administrator, mfa_enabled FROM users WHERE id = '{plain_id}';") == "f|f"
        )
        plain_cookies = [
            copy_cookie(cookie)
            for cookie in plain_context.cookies()
            if "remember" in cookie["name"]
        ]
        assert len(plain_cookies) == 1 and plain_sockets
        admin.locator(f"#sessions-{plain_id}").click()
        expect(admin.locator("#flash-info")).to_contain_text("Browser sessions revoked")
        wait_sql(
            f"SELECT count(*) FROM account_admin_events WHERE kind = 'sessions_revoke' AND actor_id = '{admin_id}' AND target_id = '{plain_id}';",
            "1",
        )
        plain_context.clear_cookies()
        plain_context.add_cookies(plain_cookies)
        select_replica(plain_context, "third")
        visit(plain, "/overview", "third", "/sign-in")
        assert export_status(plain, "third") == 404

        # An expired ceremony MUST be refused without elevation; a fresh
        # begin/verify succeeds on a different serving replica.
        sign_in(reader, "reader", "expiry", "first")
        ordinary_access(reader, "first")
        visit(reader, "/settings", "first")
        open_challenges = (
            "SELECT count(*) FROM account_passkey_challenges "
            f"WHERE user_id = '{reader_id}' AND consumed_at IS NULL;"
        )
        assert sql(open_challenges) == "0"
        # Hold the browser-side WebAuthn call until the server-side challenge
        # row exists and has been backdated past its database-clock deadline.
        reader.evaluate("""() => {
          const orig = navigator.credentials.get.bind(navigator.credentials);
          navigator.credentials.get = (opts) => {
            navigator.credentials.get = orig;
            return new Promise((resolve) => {
              window.__releaseCeremony = () => orig(opts).then(resolve);
            });
          };
        }""")
        reader.locator("#verify-passkey").click()
        wait_sql(open_challenges, "1")
        sql(
            "UPDATE account_passkey_challenges "
            "SET expires_at = clock_timestamp() - interval '1 second' "
            f"WHERE user_id = '{reader_id}' AND consumed_at IS NULL;"
        )
        reader.evaluate("() => window.__releaseCeremony()")
        expect(reader.locator("#flash-error")).to_contain_text("could not be completed")
        expect(reader.locator("#security-continue")).to_have_count(0)
        expect(reader.locator("#verification-status")).not_to_contain_text("Passkey verified")
        ordinary_access(reader, "first")

        # The fresh retry reuses this browser page: the resident passkey lives
        # in the virtual authenticator attached to it. Its socket observation
        # now binds to the third serving replica instead of the first.
        reader_set_replica("third")
        sockets_before = len(reader_sockets)
        select_replica(reader_context, "third")
        visit(reader, "/settings", "third")
        try:
            verify(reader)
        except AssertionError:
            status = reader.locator("#verification-status").inner_text().strip()
            flash_info = reader.locator("#flash-info")
            flash_error = reader.locator("#flash-error")
            info_text = flash_info.inner_text().strip() if flash_info.count() else "<absent>"
            error_text = flash_error.inner_text().strip() if flash_error.count() else "<absent>"
            raise AssertionError(
                "fresh cross-replica ceremony did not verify: "
                f"status={status!r} flash_info={info_text!r} flash_error={error_text!r}"
            ) from None
        visit(reader, "/overview", "third")
        assert sql(open_challenges) == "0"
        assert len(reader_sockets) > sockets_before
        print(
            "Ordinary login, privileged step-up, revocation and expired-ceremony refusal passed on observed "
            "first/second/third replicas"
        )
        browser.close()


if __name__ == "__main__":
    main()
