"""Host-only, boot-bound SMTP delivery over Firecracker vsock."""

import contextlib
import fcntl
import json
import os
import socket
import subprocess
import sys
from collections.abc import Callable, Mapping
from pathlib import Path

import prepare
from runtime import SetupError, encode, identities, private_directory, publish, read_private

PORT = 1025
LIMIT = 65536
BINDING = {"placement_id", "execution_epoch", "boot_challenge"}


def envelope(body: bytes, boot: Mapping[str, object]) -> object:
    """@cc [owner:ghuntley,label:security] inception-credentials-boot-bound
    Credential input MUST be bounded and match this kernel boot's placement,
    epoch and challenge exactly. Only the closed SMTP schema may be delivered;
    caller input MUST NOT select a path, command or internal application key.
    """
    value: object = json.loads(body)
    if (
        not isinstance(value, dict)
        or set(value) != BINDING | {"version", "smtp"}
        or type(value["version"]) is not int
        or value["version"] != 1
        or type(value["execution_epoch"]) is not int
        or any(value[key] != boot[key] for key in BINDING)
    ):
        raise SetupError("credential boot binding invalid")
    return value["smtp"]


def install(
    bundle: object,
    config: prepare.Config,
    restart: Callable[[], None],
) -> None:
    """@cc [owner:ghuntley,label:security;recovery] inception-smtp-runtime-publication
    SMTP MUST live only in private runtime files. Rotation MUST preserve the
    persisted internal identity and prepare the environment before restarting
    Marshall. The listener accepts the first host delivery while this unit is
    still activating; readiness is published only after the bundle and
    environment are valid. A lost acknowledgment MUST permit an idempotent
    retry; a failed preparation or restart request MUST NOT mark the bundle as
    applied.
    """
    private_directory(prepare.RUNTIME)
    fd = os.open(prepare.STATE / "bootstrap.lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "rb") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        # Validate before replacing the last accepted bundle. The schema check
        # can publish only its validated public SMTP CA to the private runtime.
        prepare.smtp_environment(bundle, prepare.RUNTIME)
        data = encode(bundle)
        applied = prepare.RUNTIME / "smtp-applied.json"
        try:
            if read_private(applied) == data:
                return
        except FileNotFoundError:
            pass
        publish(prepare.RUNTIME / "smtp.json", data)
        prepare.prepare_environment(identities(prepare.STATE), config["system_ca"])
        restart()
        publish(applied, data)


def answer(
    connection: socket.socket,
    peer: tuple[int, int],
    boot: Mapping[str, object],
    accept: Callable[[object], None],
) -> None:
    connection.settimeout(5)
    if peer[0] != 2:
        return
    with connection.makefile("rb") as stream:
        body = stream.readline(LIMIT + 1)
    if len(body) > LIMIT or not body.endswith(b"\n"):
        raise SetupError("credential input invalid")
    accept(envelope(body, boot))
    response = {key: boot[key] for key in BINDING}
    response.update(version=1, state="configured")
    connection.sendall(encode(response) + b"\n")


def notify() -> None:
    target = os.environ.get("NOTIFY_SOCKET")
    if target:
        if target.startswith("@"):
            target = "\0" + target[1:]
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as channel:
            channel.connect(target)
            channel.sendall(b"READY=1")


def main() -> None:
    # The readiness module is the canonical kernel-command-line parser; it is
    # loaded from a runtime-provided directory rather than a package import.
    readiness_path, config_path, systemctl = sys.argv[1:]
    sys.path.insert(0, readiness_path)
    from readiness import identity

    boot = identity(Path("/proc/cmdline").read_text())
    config = json.loads(Path(config_path).read_bytes())

    def restart() -> None:
        # The initial bundle arrives before Marshall can be active: its
        # environment depends on this receiver. Restart only an already
        # running instance; the normal systemd dependency chain starts the
        # inactive instance after this transaction commits.
        active = subprocess.run(
            [systemctl, "--quiet", "is-active", "marshall-inception.service"],
            check=False,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
        if active.returncode == 0:
            subprocess.run(
                [systemctl, "--no-block", "restart", "marshall-inception.service"],
                check=True,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10,
            )

    def accept(bundle: object) -> None:
        install(bundle, config, restart)
        notify()

    with socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM) as listener:
        listener.bind((socket.VMADDR_CID_ANY, PORT))
        listener.listen(4)
        while True:
            connection, peer = listener.accept()
            with (
                connection,
                contextlib.suppress(
                    OSError, ValueError, TypeError, SetupError, subprocess.SubprocessError
                ),
            ):
                # No payload, exception text or underlying command output is logged.
                answer(connection, peer, boot, accept)


if __name__ == "__main__":
    main()
