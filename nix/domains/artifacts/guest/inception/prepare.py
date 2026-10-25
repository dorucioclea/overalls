"""Privileged, retryable Inception preparation; serving units never migrate."""

import contextlib
import fcntl
import hashlib
import json
import os
import secrets
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import TypedDict

from runtime import (
    Identity,
    SetupError,
    application_environment,
    encode,
    environment_file,
    identities,
    private_directory,
    publish,
    read_private,
    smtp_environment,
)

STATE = Path("/var/lib/inception")
RUNTIME = Path("/run/inception")
SOURCE_STATUS = RUNTIME / "source-status"
PUBLIC = Path("/run/inception-public")
WORKSPACE = Path("/workspace")
CANONICAL_SOURCE_URL = "https://github.com/ghuntley/overalls"


def source_status(value: str) -> None:
    """Publish a fixed source-bootstrap outcome for bounded diagnostics."""
    with contextlib.suppress(OSError, SetupError):
        publish(SOURCE_STATUS, (value + "\n").encode())
        # Status is diagnostic only; a read-only runtime directory must never
        # change the checkout's retry or publication behavior.


def share_checkout(path: Path) -> None:
    """Make a checkout writable by every managed guest account.

    Inception's workspace is shared by the accounts reconciled into the guest,
    so a root-owned clone must not leave regular files writable only by root.
    Symlinks are intentionally left untouched; changing a link target while
    preparing a checkout would turn an otherwise local operation into a path
    traversal.  The checkout is a developer workspace, therefore the shared
    mode is the same 0666/0777 policy used by the generic guest receiver.
    """
    for candidate in [path, *path.rglob("*")]:
        info = candidate.lstat()
        if stat.S_ISLNK(info.st_mode):
            continue
        if stat.S_ISDIR(info.st_mode):
            candidate.chmod(0o777)
        elif stat.S_ISREG(info.st_mode):
            candidate.chmod(0o777 if info.st_mode & 0o111 else 0o666)


class Config(TypedDict):
    source_url: str
    openssl: str
    git: str
    runuser: str
    psql: str
    system_ca: str


def command(
    arguments: list[str],
    data: bytes | None = None,
    env: dict[str, str] | None = None,
    timeout: float = 180,
) -> bytes:
    """@cc [owner:ghuntley,label:recovery] inception-command-timeout-boundary
    A timed-out preparation command MUST terminate its complete child process
    group before returning so a stalled Git transport cannot block source
    retries or leave descendants running in the guest.
    """
    # Commands such as git clone spawn a transport helper.  A timeout that
    # kills only the git parent can leave that helper holding the stdout pipe,
    # preventing communicate() from returning and blocking source retries.
    # Put each command in its own process group so a timeout terminates the
    # complete bounded operation before the retry loop continues.
    process = subprocess.Popen(
        arguments,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        env=env,
        start_new_session=True,
    )
    try:
        output, _ = process.communicate(input=data, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        with contextlib.suppress(ProcessLookupError):
            os.killpg(process.pid, signal.SIGKILL)
        process.communicate()
        # Treat a stalled network operation like any other bounded preparation
        # failure so the source bootstrap can retry it without exposing the
        # command, URL, or subprocess diagnostics.
        raise SetupError("preparation command timed out") from error
    if process.returncode != 0:
        raise SetupError("preparation command failed")
    if output is None:
        raise SetupError("preparation command produced no output")
    return output


def bootstrap_git_environment() -> dict[str, str]:
    """Use the canonical GitHub URL without guest-wide URL rewrites.

    The shared guest image installs an interactive Git configuration that
    rewrites GitHub URLs through the platform broker.  Inception's bootstrap
    has its own reviewed trust and egress boundary and must clone the
    canonical public repository directly, so system and user Git configuration
    cannot alter the source URL or inject credentials.
    """
    return {
        **os.environ,
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
    }


def prepare_source(source_url: str, git: str) -> None:
    """@cc [owner:ghuntley,label:product;recovery] inception-development-checkout
    A new Inception workload MUST clone the canonical Overalls repository into
    ``/workspace/overalls``. The clone is published atomically and a restart
    MUST leave an existing developer checkout, including uncommitted edits,
    untouched.
    """
    workspace = WORKSPACE
    workspace.mkdir(mode=0o755, exist_ok=True)
    info = workspace.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o022:
        raise SetupError("development workspace invalid")
    # The identity service runs with a private umask.  Keep the workspace
    # itself traversable by managed developer accounts while retaining
    # root-only ownership and rejecting group/other write access above.
    workspace.chmod(0o755)
    target = workspace / "overalls"
    if os.path.lexists(target):
        git_directory = target / ".git"
        target_info = target.lstat()
        git_info = git_directory.lstat() if os.path.lexists(git_directory) else None
        if (
            target.is_symlink()
            or not stat.S_ISDIR(target_info.st_mode)
            or target_info.st_uid != os.getuid()
            or target_info.st_mode & 0o7000
            or git_info is None
            or git_directory.is_symlink()
            or not stat.S_ISDIR(git_info.st_mode)
            or git_info.st_uid != os.getuid()
            or git_info.st_mode & 0o7000
        ):
            raise SetupError("development workspace invalid")
        try:
            origin = command(
                [git, "-C", str(target), "config", "--local", "--get", "remote.origin.url"],
                env=bootstrap_git_environment(),
            )
        except SetupError as error:
            raise SetupError("development workspace invalid") from error
        if origin.decode().strip() != source_url:
            raise SetupError("development source origin invalid")
        # A valid checkout may have been copied from an older image or had
        # modes tightened by a tool between boots.  Reapply the shared
        # workspace policy without touching content or following links.
        share_checkout(target)
        source_status("existing")
        return
    with tempfile.TemporaryDirectory(prefix=".overalls-", dir=workspace) as temporary:
        tree = Path(temporary) / "source"
        last_error: SetupError | None = None
        for attempt in range(5):
            try:
                source_status("attempt")
                command(
                    # The guest deliberately disables the interactive GitHub
                    # broker config. Keep the broker's reviewed transport
                    # choice (HTTP/1.1 with connection close) for direct
                    # public egress as well; nested NATs have historically
                    # exposed HTTP/2 stalls that otherwise consume the whole
                    # retry window.
                    [
                        git,
                        "-c",
                        "http.version=HTTP/1.1",
                        "clone",
                        "--depth=1",
                        "--",
                        source_url,
                        str(tree),
                    ],
                    env=bootstrap_git_environment(),
                    # GitHub is public egress and may be temporarily
                    # unreachable while the nested route converges. Bound
                    # each attempt so the service can retry within the guest
                    # readiness envelope instead of spending the whole boot
                    # window in one stalled TCP operation.
                    timeout=60,
                )
                last_error = None
                break
            except SetupError as error:
                source_status(
                    "timeout" if str(error) == "preparation command timed out" else "failed"
                )
                last_error = error
                shutil.rmtree(tree, ignore_errors=True)
                if attempt < 4:
                    # GitHub may not be reachable when the guest's network is
                    # still converging. Keep the identity unit retryable while
                    # avoiding an unbounded bootstrap loop.
                    time.sleep(5)
        if last_error is not None:
            raise last_error
        if (
            command(
                [git, "-C", str(tree), "config", "--local", "--get", "remote.origin.url"],
                env=bootstrap_git_environment(),
            )
            .decode()
            .strip()
            != source_url
        ):
            raise SetupError("development source origin invalid")
        share_checkout(tree)
        os.rename(tree, target)
        source_status("success")
        fd = os.open(workspace, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)


def public_directory() -> None:
    PUBLIC.mkdir(mode=0o755, exist_ok=True)
    info = PUBLIC.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o022:
        raise SetupError("public certificate directory invalid")
    # Bootstrap deliberately runs under umask 0077. mkdir's requested mode is
    # masked, so explicitly make this certificates-only directory traversable
    # by the unprivileged Marshall service after validating its owner and type.
    PUBLIC.chmod(0o755)


def public_certificate(name: str, data: bytes) -> None:
    public_directory()
    publish(PUBLIC / name, data)
    (PUBLIC / name).chmod(0o644)


def certificates(openssl: str) -> None:
    """@cc [owner:ghuntley,label:security;recovery] inception-private-tls-identities
    TLS private keys MUST be generated per instance outside the image and reused
    on restart. Only certificates may enter the public runtime directory. Partial
    unpublished generation MUST NOT replace a published certificate directory.
    """
    target = STATE / "tls"
    if not os.path.lexists(target):
        with tempfile.TemporaryDirectory(prefix=".tls-", dir=STATE) as temporary:
            temporary = Path(temporary)
            command(
                [
                    openssl,
                    "req",
                    "-x509",
                    "-newkey",
                    "rsa:2048",
                    "-nodes",
                    "-sha256",
                    "-days",
                    "3650",
                    "-subj",
                    "/CN=Inception instance CA",
                    "-addext",
                    "basicConstraints=critical,CA:TRUE",
                    "-addext",
                    "keyUsage=critical,keyCertSign,cRLSign",
                    "-keyout",
                    str(temporary / "ca.key"),
                    "-out",
                    str(temporary / "ca.crt"),
                ]
            )
            for name in ["database", "marshall"]:
                command(
                    [
                        openssl,
                        "req",
                        "-new",
                        "-newkey",
                        "rsa:2048",
                        "-nodes",
                        "-subj",
                        "/CN=localhost",
                        "-keyout",
                        str(temporary / (name + ".key")),
                        "-out",
                        str(temporary / (name + ".csr")),
                    ]
                )
                extensions = temporary / "extensions"
                extensions.write_text(
                    "subjectAltName=DNS:localhost,IP:127.0.0.1\n"
                    "extendedKeyUsage=serverAuth\n"
                    "basicConstraints=critical,CA:FALSE\n"
                    "keyUsage=critical,digitalSignature,keyEncipherment\n"
                )
                command(
                    [
                        openssl,
                        "x509",
                        "-req",
                        "-in",
                        str(temporary / (name + ".csr")),
                        "-CA",
                        str(temporary / "ca.crt"),
                        "-CAkey",
                        str(temporary / "ca.key"),
                        "-set_serial",
                        "0x" + secrets.token_hex(16),
                        "-days",
                        "1825",
                        "-sha256",
                        "-extfile",
                        str(extensions),
                        "-out",
                        str(temporary / (name + ".crt")),
                    ]
                )
                (temporary / (name + ".csr")).unlink()
            (temporary / "extensions").unlink()
            for path in temporary.iterdir():
                path.chmod(0o600)
                with path.open("rb") as stream:
                    os.fsync(stream.fileno())
            # TemporaryDirectory cleans the old name after the atomic publication.
            os.rename(temporary, target)
            fd = os.open(STATE, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(fd)
            finally:
                os.close(fd)
    private_directory(target)
    for name in ["ca", "database", "marshall"]:
        read_private(target / (name + ".key"))
        read_private(target / (name + ".crt"))
        key = command([openssl, "pkey", "-in", str(target / (name + ".key")), "-pubout"])
        certificate = command(
            [openssl, "x509", "-in", str(target / (name + ".crt")), "-pubkey", "-noout"]
        )
        if key != certificate:
            raise SetupError("TLS identity mismatch")
    for name in ["database", "marshall"]:
        command(
            [
                openssl,
                "verify",
                "-CAfile",
                str(target / "ca.crt"),
                "-verify_hostname",
                "localhost",
                str(target / (name + ".crt")),
            ]
        )
    public_certificate("ca.crt", read_private(target / "ca.crt"))


def prepare_environment(identity: Identity, system_ca: str) -> None:
    bundle: object = json.loads(read_private(RUNTIME / "smtp.json"))
    smtp = smtp_environment(bundle, RUNTIME)
    if isinstance(bundle, dict) and "ca_pem" in bundle:
        public_certificate("smtp-ca.crt", read_private(RUNTIME / "smtp-ca.crt"))
    else:
        public_certificate("smtp-ca.crt", Path(system_ca).read_bytes())
    smtp["MARSHALL_SMTP_CA_CERTFILE"] = str(PUBLIC / "smtp-ca.crt")
    env = application_environment(identity, smtp, PUBLIC / "ca.crt")
    publish(RUNTIME / "marshall.env", environment_file(env))
    publish(RUNTIME / "environment.json", encode(env))


def prepare_database(identity: Identity, config: Config) -> None:
    """@cc [owner:ghuntley,label:recovery] inception-database-password-stability
    Database preparation MUST use the persisted per-instance password and send it
    to local PostgreSQL on stdin, never in argv or diagnostics. Retry MUST NOT
    generate or rotate a password. The Nix PostgreSQL module owns role/database creation.
    """
    password = identity["database_password"]  # validated hexadecimal, not external SMTP input
    sql = (
        "SET log_statement = 'none'; SET log_min_error_statement = 'panic';\n"
        "ALTER ROLE marshall WITH LOGIN PASSWORD '" + password + "';\n"
    )
    command(
        [
            config["runuser"],
            "-u",
            "postgres",
            "--",
            config["psql"],
            "--no-psqlrc",
            "--set",
            "ON_ERROR_STOP=1",
            "--dbname",
            "postgres",
        ],
        sql.encode(),
    )


def main() -> None:
    if os.getuid() != 0:
        raise SetupError("root preparation required")
    action, config_path, *arguments = sys.argv[1:]
    config = json.loads(Path(config_path).read_bytes())
    private_directory(STATE)
    private_directory(RUNTIME)
    # The source checkout is an optional network operation.  It must not hold
    # the bootstrap lock while GitHub is unavailable: identity, credentials
    # and private-PKI preparation all use that lock and are prerequisites for
    # the guest's readiness exchange.  The checkout is published atomically
    # by prepare_source and its systemd unit serializes retries.
    if action == "source":
        if config.get("source_url") != CANONICAL_SOURCE_URL:
            raise SetupError("development source origin invalid")
        # The source origin is part of the workload contract. Keep the
        # production bootstrap on the canonical HTTPS URL even in fixtures;
        # test routing changes the endpoint behind that hostname rather than
        # accepting a transport or URL override.
        prepare_source(config["source_url"], config["git"])
        return
    fd = os.open(STATE / "bootstrap.lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "rb") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        identity = identities(STATE)
        if action == "identity":
            certificates(config["openssl"])
            hostid = hashlib.sha256(identity["instance_id"].encode()).digest()[:4]
            if hostid == bytes(4):
                hostid = b"\x01\x00\x00\x00"
            hostid_path = Path("/etc/hostid")
            if os.path.lexists(hostid_path):
                if hostid_path.is_symlink() or hostid_path.read_bytes() != hostid:
                    raise SetupError("host identity changed")
            else:
                publish(hostid_path, hostid, replace=False)
                hostid_path.chmod(0o644)
        elif action == "environment":
            prepare_environment(identity, config["system_ca"])
        elif action == "database":
            prepare_database(identity, config)
        elif action == "exec":
            env = {
                **os.environ,
                **json.loads(read_private(RUNTIME / "environment.json")),
                "RELEASE_COOKIE": secrets.token_hex(32),
                "PHX_SERVER": "false",
            }
            # The child may perform long-running application work; it does not own
            # the bootstrap lock. Unit dependencies serialize bootstrap actions.
            fcntl.flock(lock, fcntl.LOCK_UN)
            os.execve(arguments[0], arguments, env)
        else:
            raise SetupError("unknown preparation action")


if __name__ == "__main__":
    try:
        main()
    except SetupError as error:
        # SetupError messages are fixed local reason strings, never subprocess
        # output, argv, JSON values or database errors.
        print("Inception preparation failed: " + str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:
        # Underlying exceptions can contain credentials, SQL or environment values.
        print(
            "Inception preparation failed; check private inputs and service prerequisites",
            file=sys.stderr,
        )
        sys.exit(1)
