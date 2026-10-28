"""Real IPv4/PROXY/TLS readiness and durable control certificate custody."""

import base64
import contextlib
import hashlib
import http.server
import importlib.util
import json
import os
import signal
import socket
import ssl
import stat
import struct
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

source = Path(sys.argv.pop(1))
spec = importlib.util.spec_from_file_location("runtime", source / "runtime.py")
if spec is None or spec.loader is None:
    raise RuntimeError("runtime helper unavailable")
runtime = importlib.util.module_from_spec(spec)
sys.modules["runtime"] = runtime
spec.loader.exec_module(runtime)
SetupError = runtime.SetupError
settings_spec = importlib.util.spec_from_file_location(
    "public_settings", source / "public_settings.py"
)
if settings_spec is None or settings_spec.loader is None:
    raise RuntimeError("public settings helper unavailable")
public_settings = importlib.util.module_from_spec(settings_spec)
sys.modules["public_settings"] = public_settings
settings_spec.loader.exec_module(public_settings)
observations_spec = importlib.util.spec_from_file_location(
    "observations", source / "observations.py"
)
if observations_spec is None or observations_spec.loader is None:
    raise RuntimeError("observations helper unavailable")
observations = importlib.util.module_from_spec(observations_spec)
sys.modules["observations"] = observations
observations_spec.loader.exec_module(observations)
ingress_spec = importlib.util.spec_from_file_location("ingress", source / "ingress.py")
if ingress_spec is None or ingress_spec.loader is None:
    raise RuntimeError("ingress helper unavailable")
ingress = importlib.util.module_from_spec(ingress_spec)
sys.modules["ingress"] = ingress
ingress_spec.loader.exec_module(ingress)
roles_spec = importlib.util.spec_from_file_location("roles", source / "roles.py")
if roles_spec is None or roles_spec.loader is None:
    raise RuntimeError("roles helper unavailable")
roles = importlib.util.module_from_spec(roles_spec)
sys.modules["roles"] = roles
roles_spec.loader.exec_module(roles)
tls_spec = importlib.util.spec_from_file_location("control_tls", source / "control_tls.py")
if tls_spec is None or tls_spec.loader is None:
    raise RuntimeError("control TLS helper unavailable")
control = importlib.util.module_from_spec(tls_spec)
sys.modules["control_tls"] = control
tls_spec.loader.exec_module(control)

VALIDATOR, OPENSSL, HAPROXY, CASES = sys.argv[1:5]
del sys.argv[1:5]


def certificate(name: str) -> tuple[bytes, bytes]:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Isolated control TLS fixture")])
    now = datetime.now(UTC)
    leaf = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(subject)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(minutes=1))
        .not_valid_after(now + timedelta(days=30))
        .add_extension(x509.SubjectAlternativeName([x509.DNSName(name)]), critical=False)
        .sign(key, hashes.SHA256())
    )
    cert = leaf.public_bytes(serialization.Encoding.PEM)
    return key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
    ) + cert, cert


class ControlTLSTest(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.pem, self.cert = certificate("control.example")
        self.roots = self.root / "roots.pem"
        self.roots.write_bytes(self.cert)
        self.chain = self.root / "full.pem"
        self.chain.write_bytes(self.pem)

    def serve(
        self,
        expected: bytes | None = None,
        hostname: str = "control.example",
        response: bytes = b"HTTP/1.1 200 OK\r\n\r\n",
    ) -> tuple[bool, list[bytes]]:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(self.chain)
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        listener.settimeout(3)
        port = listener.getsockname()[1]
        observed = []
        errors = []

        def server() -> None:
            try:
                with listener, listener.accept()[0] as peer:
                    peer.settimeout(3)
                    header = b""
                    while len(header) < 28:
                        part = peer.recv(28 - len(header))
                        if not part:
                            raise AssertionError("truncated PROXY header")
                        header += part
                    observed.append(header)
                    with context.wrap_socket(peer, server_side=True) as tls:
                        request = tls.recv(4096)
                        observed.append(request)
                        if request:
                            tls.sendall(response)
            except ssl.SSLError:
                pass  # Expected when the client rejects the certificate name.
            except (BrokenPipeError, ConnectionResetError) as error:
                if expected is None and hostname == "control.example":
                    errors.append(error)
            except Exception as error:
                errors.append(error)

        thread = threading.Thread(target=server)
        thread.start()
        result = control.probe(
            "127.0.0.1", hostname, self.roots, self.pem if expected is None else expected, port
        )
        thread.join(4)
        self.assertFalse(thread.is_alive())
        self.assertEqual(errors, [])
        header = struct.unpack("!12sBBH4s4sHH", observed[0])
        self.assertEqual(
            header[:6],
            (
                b"\r\n\r\n\0\r\nQUIT\n",
                0x21,
                0x11,
                12,
                socket.inet_aton("127.0.0.1"),
                socket.inet_aton("127.0.0.1"),
            ),
        )
        self.assertEqual(header[7], port)
        return result, observed

    def test_live_verified_health_with_ipv4_proxy_metadata(self) -> None:
        result, observed = self.serve()
        self.assertTrue(result)
        self.assertIn(b"Host: control.example\r\n", observed[1])

    def test_wrong_name_leaf_and_unhealthy_backend_are_not_ready(self) -> None:
        self.assertFalse(self.serve(hostname="other.example")[0])
        self.assertFalse(self.serve(expected=certificate("control.example")[0])[0])
        self.assertFalse(self.serve(response=b"HTTP/1.1 503 Unavailable\r\n\r\n")[0])

    def test_invalid_address_and_header_injection_fail_closed(self) -> None:
        for address in ["::1", "0.0.0.0", "localhost"]:
            self.assertFalse(control.probe(address, "control.example", self.roots, self.pem))
        self.assertFalse(
            control.probe("127.0.0.1", "control.example\r\nInjected: yes", self.roots, self.pem)
        )

    def test_atomic_private_install_preserves_prior_inode_and_rejects_bad_custody(self) -> None:
        destination = self.root / "serving"
        destination.mkdir(mode=0o750)
        control.install(self.pem, destination)
        target = destination / "full.pem"
        with target.open("rb") as old:
            replacement = certificate("control.example")[0]
            control.install(replacement, destination)
            self.assertEqual(old.read(), self.pem)
            self.assertEqual(target.read_bytes(), replacement)
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o640)
        self.assertEqual(target.stat().st_nlink, 1)
        destination.chmod(0o777)
        with self.assertRaises(SetupError):
            control.install(self.pem, destination)
        self.assertEqual(target.read_bytes(), replacement)

    def configuration(self) -> tuple[dict[str, object], dict[str, object], str]:
        boot = {
            "placement_id": "11111111-1111-4111-8111-111111111111",
            "execution_epoch": 1,
            "boot_challenge": "a" * 64,
            "address": "10.40.0.2",
        }
        binding = {key: value for key, value in boot.items() if key != "address"}
        namespace = "dev-" + "2" * 32 + ".inception.apps.example"
        hostname = "control." + namespace
        config = {
            "version": 1,
            "binding": binding,
            "request_id": boot["placement_id"],
            "generation": 1,
            "origins": {"namespace": namespace, "control": hostname, "apps": "apps." + namespace},
            "public": next(
                item["value"]
                for item in json.loads(Path(CASES).read_text())
                if item["name"] == "public"
            ),
        }
        return boot, config, hostname

    def test_actual_proxy_configuration_and_certificate_validation(self) -> None:
        boot, config, hostname = self.configuration()
        pem, cert = certificate(hostname)
        self.roots.write_bytes(cert)
        proxy = self.root / "haproxy.cfg"
        # Replace only the immutable backend trust path with this isolated root.
        proxy.write_text(
            control.proxy_config(boot, config).replace(str(control.BACKEND_CA), str(self.roots))
        )
        settings = control.validation_settings(
            hostname,
            OPENSSL,
            HAPROXY,
            self.roots,
            control.CERTIFICATES,
            proxy,
        )
        module = control.validator(VALIDATOR)
        accepted = control.validate(pem, settings, module, self.root)
        self.assertEqual(
            x509.load_pem_x509_certificates(accepted)[0].serial_number,
            x509.load_pem_x509_certificates(pem)[0].serial_number,
        )
        with self.assertRaises(ValueError):
            control.validate(self.pem, settings, module, self.root)

    def test_live_proxy_source_enforcement_headers_and_graceful_reload(self) -> None:
        boot, config, hostname = self.configuration()
        first, first_cert = certificate(hostname)
        second, second_cert = certificate(hostname)
        self.chain.write_bytes(first)
        self.roots.write_bytes(first_cert + second_cert)
        backend_pem, backend_cert = certificate("localhost")
        backend_chain = self.root / "backend.pem"
        backend_chain.write_bytes(backend_pem)
        backend_ca = self.root / "backend-ca.pem"
        backend_ca.write_bytes(backend_cert)

        class Handler(http.server.BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, format: str, *args: object) -> None:
                pass

            def do_GET(self) -> None:
                if self.path == "/socket":
                    self.send_response(101)
                    self.send_header("Connection", "Upgrade")
                    self.send_header("Upgrade", "websocket")
                    self.send_header(
                        "Sec-WebSocket-Accept",
                        base64.b64encode(
                            hashlib.sha1(
                                (
                                    self.headers["Sec-WebSocket-Key"]
                                    + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
                                ).encode()
                            ).digest()
                        ).decode(),
                    )
                    self.end_headers()
                    self.wfile.flush()
                    self.connection.settimeout(10)
                    try:
                        while data := self.rfile.read(1):
                            self.wfile.write(data)
                            self.wfile.flush()
                    except (OSError, ValueError):
                        pass
                    return
                body = json.dumps(dict(self.headers)).encode()
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        backend = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(backend_chain)
        backend.socket = context.wrap_socket(backend.socket, server_side=True)
        thread = threading.Thread(target=backend.serve_forever)
        thread.start()

        def stop_backend() -> None:
            backend.shutdown()
            backend.server_close()
            thread.join(3)

        self.addCleanup(stop_backend)
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        # Preserve generated trust rules and protocol configuration, mapping only
        # fixture addresses, ports and certificate paths to isolated loopback.
        configuration = control.proxy_config(boot, config)
        configuration = configuration.replace("10.40.0.2:443", f"127.0.0.1:{port}")
        configuration = configuration.replace("10.40.0.1 10.40.0.2", "127.0.0.3 127.0.0.1")
        configuration = configuration.replace("127.0.0.1:4443", f"127.0.0.1:{backend.server_port}")
        configuration = configuration.replace(
            str(control.CERTIFICATES / "full.pem"), str(self.chain)
        )
        configuration = configuration.replace(str(control.BACKEND_CA), str(backend_ca))
        proxy = self.root / "live.cfg"
        proxy.write_text(configuration)
        process = subprocess.Popen(
            [HAPROXY, "-W", "-db", "-f", str(proxy)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )

        def stop_proxy() -> None:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)

        self.addCleanup(stop_proxy)

        def connect(source: str = "127.0.0.1", claimed: str = "192.0.2.44") -> ssl.SSLSocket:
            connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            try:
                connection.settimeout(2)
                connection.bind((source, 0))
                connection.connect(("127.0.0.1", port))
                connection.sendall(
                    struct.pack(
                        "!12sBBH4s4sHH",
                        b"\r\n\r\n\0\r\nQUIT\n",
                        0x21,
                        0x11,
                        12,
                        socket.inet_aton(claimed),
                        socket.inet_aton("127.0.0.1"),
                        12345,
                        port,
                    )
                )
                client_context = ssl.create_default_context(cafile=str(self.roots))
                return client_context.wrap_socket(connection, server_hostname=hostname)
            except BaseException:
                connection.close()
                raise

        deadline = time.monotonic() + 10
        while True:
            try:
                with connect() as client:
                    client.sendall(
                        f"GET /health/ready HTTP/1.1\r\nHost: {hostname}\r\n\r\n".encode()
                    )
                    if client.recv(4096).startswith(b"HTTP/1.1 200"):
                        break
            except OSError:
                pass
            self.assertIsNone(process.poll())
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.05)
        with self.assertRaises(OSError), connect(source="127.0.0.2", claimed="127.0.0.1"):
            self.fail("untrusted original source supplied trusted PROXY metadata")
        with connect() as client:
            client.sendall(
                (
                    f"GET /headers HTTP/1.1\r\nHost: {hostname}\r\nConnection: close\r\n"
                    "Forwarded: forged\r\nX-Forwarded-For: forged\r\n"
                    "X-Forwarded-Host: forged\r\nX-Forwarded-Proto: http\r\n\r\n"
                ).encode()
            )
            response = b""
            while data := client.recv(4096):
                response += data
            headers = {
                key.lower(): value
                for key, value in json.loads(response.split(b"\r\n\r\n", 1)[1]).items()
            }
            self.assertNotIn("forwarded", headers)
            self.assertEqual(headers["x-forwarded-for"], "192.0.2.44")
            self.assertEqual(headers["x-forwarded-host"], hostname)
            self.assertEqual(headers["x-forwarded-proto"], "https")
        with connect() as upgraded:
            upgraded.sendall(
                (
                    f"GET /socket HTTP/1.1\r\nHost: {hostname}\r\n"
                    "Connection: Upgrade\r\nUpgrade: websocket\r\n"
                    "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
                    "Sec-WebSocket-Version: 13\r\n\r\n"
                ).encode()
            )
            response = b""
            while b"\r\n\r\n" not in response:
                response += upgraded.recv(4096)
            self.assertTrue(response.startswith(b"HTTP/1.1 101"), response.split(b"\r\n", 1)[0])
            self.chain.write_bytes(second)
            process.send_signal(signal.SIGUSR2)
            expected = x509.load_pem_x509_certificates(second)[0].public_bytes(
                serialization.Encoding.DER
            )
            deadline = time.monotonic() + 10
            while True:
                with connect() as client:
                    if client.getpeercert(binary_form=True) == expected:
                        break
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.05)
            upgraded.sendall(b"x")
            self.assertEqual(upgraded.recv(1), b"x")


unittest.main()
