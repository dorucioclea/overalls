"""Inner control proxy configuration, certificate custody and live readiness."""

import importlib.util
import ipaddress
import os
import secrets
import socket
import ssl
import stat
import struct
import tempfile
import time
from datetime import UTC, datetime
from pathlib import Path
from types import ModuleType
from typing import TypedDict

import ingress
import roles
from cryptography import x509
from cryptography.hazmat.primitives import serialization
from runtime import SetupError

CERTIFICATES = Path("/var/lib/inception-control-proxy")
BACKEND_CA = Path("/run/inception-public/ca.crt")


class Binding(TypedDict):
    placement_id: str
    execution_epoch: int
    boot_challenge: str


class Boot(Binding):
    address: str
    gateway: str


class Validation(TypedDict):
    hostname: str
    openssl: str
    haproxy: str
    caFile: str
    destination: str
    peerCertificates: list[str]
    proxyConfig: str


def validation_settings(
    hostname: str,
    openssl: str,
    haproxy: str,
    ca_file: str | Path,
    destination: str | Path,
    proxy_config: str | Path,
) -> Validation:
    """@cc [owner:ghuntley,label:security] inception-control-validation-settings
    Every control certificate validation request MUST include the complete
    shared validator schema, including an explicit empty peer set when this
    proxy has no sibling certificates.

    Build the complete shared certificate-validation configuration.

    The shared validator treats peer certificate paths as part of its input
    contract, even when this single-certificate proxy has no peers. Keep that
    adapter here so production supervision and isolated validation tests use
    the same typed settings.
    """
    return {
        "hostname": hostname,
        "openssl": openssl,
        "haproxy": haproxy,
        "caFile": str(ca_file),
        "destination": str(destination),
        "peerCertificates": [],
        "proxyConfig": str(proxy_config),
    }


def proxy_config(boot: Boot, config: ingress.Configuration) -> str:
    """@cc [owner:ghuntley,label:security] inception-control-proxy-trust
    Control TLS MUST bind only the current control IPv4 address and route only
    to verified localhost Marshall. Original socket source MUST be checked before
    accepting PROXY metadata: only the parent connector and same-address local
    readiness probe are trusted. Public forwarding headers MUST be replaced.
    Request logs MUST NOT include URLs, headers, credentials or response bodies.
    """
    address = str(roles.control_address(boot, config))
    hostname = config["origins"]["control"]
    return f"""global
  maxconn 1024
  log stdout format raw local0
  ssl-default-bind-options ssl-min-ver TLSv1.2
  ssl-default-server-options ssl-min-ver TLSv1.2

defaults
  mode http
  log global
  timeout connect 5s
  timeout client 60s
  timeout server 60s
  timeout tunnel 1h
  timeout check 3s
  log-format '{{"event":"inception.control_request","status":%ST,"bytes":%B,"duration_ms":%Tt}}'

frontend control
  bind {address}:443 ssl crt {CERTIFICATES}/full.pem alpn h2,http/1.1
  tcp-request connection reject unless {{ src 10.40.0.1 {address} }}
  tcp-request connection expect-proxy layer4
  acl control_host hdr(host),lower -m str {hostname} {hostname}:443
  http-request deny deny_status 421 unless control_host
  http-request del-header Forwarded
  http-request set-header X-Forwarded-Proto https
  http-request set-header X-Forwarded-Host {hostname}
  http-request set-header X-Forwarded-For %[src]
  http-request set-header X-Request-ID %[uuid()]
  default_backend inner_marshall

backend inner_marshall
  option httpchk
  http-check send meth GET uri /health/ready ver HTTP/1.1 hdr Host {hostname}
  http-check expect status 200
  default-server inter 1s fall 2 rise 2
  server local 127.0.0.1:4443 resolve-prefer ipv4 ssl verify required verifyhost localhost sni str(localhost) check check-ssl check-sni localhost ca-file {BACKEND_CA}
"""


def validator(path: str) -> ModuleType:
    """Load only the immutable image's shared certificate-validation module."""
    spec = importlib.util.spec_from_file_location("inception_certificate_validation", path)
    if spec is None or spec.loader is None:
        raise SetupError("control certificate validator unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate(pem: bytes, configuration: Validation, module: ModuleType, scratch: Path) -> bytes:
    """@cc [owner:ghuntley,label:security] inception-control-certificate-validation
    Certificate publication MUST verify current lifetime, hostname, CA trust,
    matching private key and the complete candidate HAProxy configuration before
    replacing any serving material. Failure MUST leave the old certificate intact.
    """
    if not isinstance(pem, bytes) or not 1 <= len(pem) <= 65536:
        raise SetupError("control certificate material invalid")
    with tempfile.TemporaryDirectory(prefix="validate-", dir=scratch) as directory:
        return module.validate(pem, Path(directory), configuration, 0)


def install(pem: bytes, directory: Path = CERTIFICATES) -> None:
    """@cc [owner:ghuntley,label:security;recovery] inception-control-certificate-custody
    Only already validated material may be installed. The owning certificate
    worker MUST atomically replace and sync a single-link 0640 file within its
    owned 0750 directory, preserving the proxy group. Existing material MUST NOT
    be truncated in place, including when validation or a later reload fails.
    """
    if not isinstance(pem, bytes) or not 1 <= len(pem) <= 65536:
        raise SetupError("control certificate material invalid")
    info = directory.lstat()
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.getuid()
        or stat.S_IMODE(info.st_mode) != 0o750
    ):
        raise SetupError("control certificate directory invalid")
    temporary = directory / (".certificate-" + secrets.token_hex(8))
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(pem)
            stream.flush()
            os.fchown(stream.fileno(), -1, info.st_gid)
            os.fchmod(stream.fileno(), 0o640)
            os.fsync(stream.fileno())
        os.replace(temporary, directory / "full.pem")
        fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        temporary.unlink(missing_ok=True)


def renewal_due(pem: bytes) -> bool:
    certificate = x509.load_pem_x509_certificates(pem)[0]
    lifetime = (certificate.not_valid_after_utc - certificate.not_valid_before_utc).total_seconds()
    remaining = (certificate.not_valid_after_utc - datetime.now(UTC)).total_seconds()
    return remaining <= min(604800, lifetime / 3)


def probe(address: str, hostname: str, roots: str | Path, pem: bytes, port: int = 443) -> bool:
    """@cc [owner:ghuntley,label:verification;security] inception-control-live-readiness
    Readiness MUST source-bind to the configured local IPv4 address, send fixed
    IPv4 PROXY v2 metadata, and verify CA, hostname, exact served leaf and HTTP 200
    under one one-second network deadline. Missing material, wrong peers, expiry
    and stalled connections MUST return false without another address or protocol.
    """
    try:
        ip = ipaddress.IPv4Address(address)
        if ip.is_unspecified:
            return False
        if (
            not isinstance(hostname, str)
            or not hostname
            or any(
                character not in "abcdefghijklmnopqrstuvwxyz0123456789-." for character in hostname
            )
        ):
            return False
        certificate = x509.load_pem_x509_certificates(pem)[0].public_bytes(
            serialization.Encoding.DER
        )
        context = ssl.create_default_context(cafile=str(roots))
        deadline = time.monotonic() + 1

        def remaining() -> float:
            left = deadline - time.monotonic()
            if left <= 0:
                raise TimeoutError()
            return left

        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as connection:
            connection.settimeout(remaining())
            connection.bind((str(ip), 0))
            connection.connect((str(ip), port))
            connection.settimeout(remaining())
            connection.sendall(
                struct.pack(
                    "!12sBBH4s4sHH",
                    b"\r\n\r\n\0\r\nQUIT\n",
                    0x21,
                    0x11,
                    12,
                    ip.packed,
                    ip.packed,
                    connection.getsockname()[1],
                    port,
                )
            )
            connection.settimeout(remaining())
            with context.wrap_socket(connection, server_hostname=hostname) as tls:
                if tls.getpeercert(binary_form=True) != certificate:
                    return False
                tls.settimeout(remaining())
                tls.sendall(
                    (
                        "GET /health/ready HTTP/1.1\r\nHost: "
                        + hostname
                        + "\r\nConnection: close\r\n\r\n"
                    ).encode("ascii")
                )
                response = b""
                while b"\r\n" not in response and len(response) < 1024:
                    tls.settimeout(remaining())
                    chunk = tls.recv(1024 - len(response))
                    if not chunk:
                        return False
                    response += chunk
                return time.monotonic() < deadline and response.split(b"\r\n", 1)[0] in [
                    b"HTTP/1.1 200 OK",
                    b"HTTP/1.0 200 OK",
                ]
    except (OSError, ValueError, IndexError, TypeError):
        return False
