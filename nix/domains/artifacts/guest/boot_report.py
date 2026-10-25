"""Bounded guest boot profile on the serial console; observation only, never readiness."""

import subprocess
import sys
import time
from collections.abc import Callable, Sequence
from typing import Final

MARKER: Final = "lilly-boot-report: "
READINESS_FAILURE_MARKER: Final = "/run/lilly-readiness-failure"
READINESS_FAILURES: Final = frozenset(
    {
        "multi_user_inactive",
        "lilly_network_inactive",
        "required_unit_inactive",
        "ssh_unit_inactive",
        "address_missing",
        "gateway_route_missing",
        "default_route_missing",
        "root_write_failed",
        "probe_error",
        "peer_rejected",
    }
)
MAXIMUM_LINE: Final = 200
MAXIMUM_SECTION_LINES: Final = 24
BLAME_LINES: Final = 15
# A guest whose timers keep starting jobs (for example a failing roster sync
# with no reachable authority) may never finish booting; report anyway.
FINISH_DEADLINE_SECONDS: Final = 30.0
POLL_SECONDS: Final = 0.25
# Units whose start and activation instants explain trust and readiness latency.
TIMELINE_UNITS: Final = (
    "systemd-modules-load.service",
    "local-fs.target",
    "systemd-udev-trigger.service",
    "systemd-udev-settle.service",
    "suid-sgid-wrappers.service",
    "sysinit.target",
    "basic.target",
    "lilly-grow-root.service",
    "overalls-guest-trust.service",
    "firewall.service",
    "lilly-network.service",
    "systemd-resolved.service",
    "lilly-private-dns.service",
    "lilly-readiness.service",
    # Inception's nested profile needs the identity and image phases called
    # out explicitly: a report that only names generic readiness units cannot
    # distinguish a KVM identity failure from a later image-build failure.
    "inception-identity.service",
    "inception-credentials.service",
    "inception-image.service",
    "inception-source.service",
    "multi-user.target",
)
CHAIN_UNITS: Final = ("overalls-guest-trust.service", "lilly-readiness.service")
STATUS_UNITS: Final = (
    "overalls-guest-trust.service",
    "lilly-network.service",
    "lilly-readiness.service",
    "inception-identity.service",
    "inception-credentials.service",
    "inception-image.service",
    "inception-storage.service",
    "postgresql-setup.service",
    "inception-database.service",
    "inception-environment.service",
    "inception-migrate.service",
    "inception-enrollment.service",
    "inception-enable.service",
    "lilly.service",
    "marshall-inception.service",
    "postgresql.service",
    "multi-user.target",
)
TIMELINE_PROPERTIES: Final = "InactiveExitTimestampMonotonic,ActiveEnterTimestampMonotonic"
MANAGER_PROPERTIES: Final = (
    "InitRDTimestampMonotonic,UserspaceTimestampMonotonic,FinishTimestampMonotonic"
)

Runner = Callable[[Sequence[str]], str | None]


def bound(text: str, limit: int = MAXIMUM_SECTION_LINES) -> list[str]:
    """@cc [owner:ghuntley,label:recovery] guest-boot-report-bounded
    Every emitted line MUST carry the report marker, contain no control
    characters and stay within MAXIMUM_LINE characters plus the marker; each
    section emits at most `limit` lines so a misbehaving tool cannot flood the
    bounded host boot log.
    """
    lines: list[str] = []
    for raw in text.splitlines():
        printable = "".join(character for character in raw if character.isprintable()).rstrip()
        if printable:
            lines.append(MARKER + printable[:MAXIMUM_LINE])
        if len(lines) == limit:
            break
    return lines


def timeline(raw: str) -> list[str]:
    """Render `systemctl show` blocks (one per requested unit, blank-line
    separated, in request order) as seconds since kernel start."""
    blocks = [block for block in raw.split("\n\n") if block.strip()]
    rendered: list[str] = []
    for unit, block in zip(TIMELINE_UNITS, blocks, strict=False):
        values = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
        started = _seconds(values.get("InactiveExitTimestampMonotonic", ""))
        active = _seconds(values.get("ActiveEnterTimestampMonotonic", ""))
        rendered.append(f"unit {unit} since-kernel start={started} active={active}")
    return rendered


def manager(raw: str) -> str:
    """Render manager phase instants (seconds since kernel start); works
    before the boot transaction finishes, unlike systemd-analyze."""
    values = dict(line.split("=", 1) for line in raw.splitlines() if "=" in line)
    initrd = _seconds(values.get("InitRDTimestampMonotonic", ""))
    userspace = _seconds(values.get("UserspaceTimestampMonotonic", ""))
    finished = _seconds(values.get("FinishTimestampMonotonic", ""))
    return f"manager since-kernel initrd={initrd} userspace={userspace} finished={finished}"


def services(blame: str) -> str:
    """Drop device units: their blame value is udev appearance, not start work."""
    return "\n".join(line for line in blame.splitlines() if not line.rstrip().endswith(".device"))


def readiness_failure(run: Runner) -> str | None:
    """Read only the fixed category emitted by the live readiness probe."""
    value = run(["cat", READINESS_FAILURE_MARKER])
    if value is None:
        return None
    category = value.strip()
    return category if category in READINESS_FAILURES else None


def _seconds(microseconds: str) -> str:
    if not microseconds.isdecimal() or int(microseconds) == 0:
        return "-"
    return f"{int(microseconds) / 1_000_000:.3f}s"


def run_tool(arguments: Sequence[str]) -> str | None:
    try:
        completed = subprocess.run(
            list(arguments),
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            errors="replace",
            timeout=20,
            env={"SYSTEMD_PAGER": "cat", "SYSTEMD_COLORS": "0", "LC_ALL": "C"},
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return completed.stdout if completed.returncode == 0 else None


def report(
    analyze: str,
    systemctl: str,
    journalctl: str,
    run: Runner = run_tool,
    sleep: Callable[[float], None] = time.sleep,
    clock: Callable[[], float] = time.monotonic,
) -> list[str]:
    """Wait (bounded) for the boot transaction to finish, then profile it."""
    deadline = clock() + FINISH_DEADLINE_SECONDS
    finished = run([analyze, "time"])
    while finished is None and clock() < deadline:
        sleep(POLL_SECONDS)
        finished = run([analyze, "time"])
    lines = [MARKER + "begin"]
    failure = readiness_failure(run)
    if failure is not None:
        lines.append(MARKER + "readiness-failure=" + failure)
    lines += bound(finished or "Bootup is not yet finished")
    phases = run([systemctl, "show", "--no-pager", "-p", MANAGER_PROPERTIES])
    lines += bound(manager(phases or ""), 1)
    chain = run([analyze, "critical-chain", "--no-pager", *CHAIN_UNITS])
    lines += bound(chain or "critical-chain unavailable")
    shown = run([systemctl, "show", "--no-pager", "-p", TIMELINE_PROPERTIES, *TIMELINE_UNITS])
    lines += bound("\n".join(timeline(shown or "")), len(TIMELINE_UNITS))
    # Query one unit at a time.  `systemctl show` does not guarantee a blank
    # separator when several units are passed, and a missing unit can suppress
    # the remaining output on some systemd versions.  Positional association
    # would then report a healthy unit under the wrong name.  The fixed list and
    # per-call timeout keep this diagnostic bounded and prevent unit names from
    # becoming guest-controlled output.
    for unit in STATUS_UNITS:
        shown = run(
            [
                systemctl,
                "show",
                "--no-pager",
                "-p",
                "ActiveState,SubState,Result",
                unit,
            ]
        )
        values = dict(line.split("=", 1) for line in (shown or "").splitlines() if "=" in line)
        active = values.get("ActiveState", "unknown")
        substate = values.get("SubState", "unknown")
        result = values.get("Result", "unknown")
        if active not in {"active", "inactive", "failed", "activating", "deactivating"}:
            active = "unknown"
        if substate not in {"running", "dead", "exited", "failed", "auto-restart", "start-pre"}:
            substate = "unknown"
        if result not in {"success", "exit-code", "signal", "timeout", "dependency", "skipped"}:
            result = "unknown"
        lines.append(
            f"{MARKER}status unit={unit} active={active} substate={substate} result={result}"
        )
    # The trust receiver's catalogued events (awaiting/installing/installed)
    # carry no payload; their monotonic stamps split listen and install time.
    trust = run([journalctl, "-b", "--no-pager", "-o", "short-monotonic", "-u", CHAIN_UNITS[0]])
    lines += bound(trust or "trust journal unavailable")
    blame = run([analyze, "blame", "--no-pager"])
    lines += bound(services(blame) if blame else "blame unavailable", BLAME_LINES)
    lines.append(MARKER + "end")
    return lines


def main() -> int:
    analyze, systemctl, journalctl = sys.argv[1:]
    for line in report(analyze, systemctl, journalctl):
        print(line, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
