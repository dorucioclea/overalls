"""Readiness failure boundaries using the actual guest module and local sockets."""

import importlib.util
import json
import os
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("readiness", sys.argv.pop(1))
if spec is None or spec.loader is None:
    raise RuntimeError("readiness helper unavailable")
readiness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(readiness)
PLACEMENT = "11111111-1111-4111-8111-111111111111"
BOOT_ID = "22222222-2222-4222-8222-222222222222"
PARAMETERS = {
    "lilly.placement": PLACEMENT,
    "lilly.execution_epoch": "9",
    "lilly.boot_challenge": "a" * 64,
    "lilly.ipv4": "10.20.1.2",
}


def cmdline(parameters: dict[str, str] | None = None) -> str:
    return "console=ttyS0 " + " ".join(
        f"{key}={value}"
        for key, value in (PARAMETERS if parameters is None else parameters).items()
    )


class ReadinessTest(unittest.TestCase):
    def setUp(self) -> None:
        self.boot = readiness.identity(cmdline())
        self.addresses = [
            {
                "ifname": "eth0",
                "flags": ["UP"],
                "addr_info": [{"family": "inet", "local": "10.20.1.2", "prefixlen": 32}],
            }
        ]
        self.routes = [
            {"dev": "eth0", "scope": "link", "dst": "10.20.0.1"},
            {"dev": "eth0", "dst": "default", "gateway": "10.20.0.1"},
        ]

    def test_boot_binding_rejects_missing_duplicate_and_malformed_values(self) -> None:
        for key in PARAMETERS:
            without = dict(PARAMETERS)
            del without[key]
            with self.assertRaises(ValueError):
                readiness.identity(cmdline(without))
            for suffix in (f" {key}=other", f" {key}"):
                with self.assertRaises(ValueError):
                    readiness.identity(cmdline() + suffix)
        invalid = {
            "lilly.placement": ["../placement", PLACEMENT.upper().replace("1", "A", 1), "x"],
            "lilly.execution_epoch": ["0", "01", "-1", "9223372036854775808", "1.0"],
            "lilly.boot_challenge": ["a" * 63, "A" * 64, "z" * 64],
            "lilly.ipv4": [
                "10.20.0.0",
                "10.20.0.1",
                "10.20.255.255",
                "10.21.1.2",
                "10.20.01.2",
                "10.20.256.2",
                "127.0.0.1",
            ],
        }
        for key, values in invalid.items():
            for value in values:
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    readiness.identity(cmdline({**PARAMETERS, key: value}))
        with self.assertRaises(ValueError):
            readiness.identity("x" * 4097)

    def test_epoch_upper_bound_and_all_profile_endpoints(self) -> None:
        for profile in (10, 20, 30, 40):
            for address in (f"10.{profile}.0.2", f"10.{profile}.255.254"):
                boot = readiness.identity(
                    cmdline(
                        {
                            **PARAMETERS,
                            "lilly.ipv4": address,
                            "lilly.execution_epoch": str(readiness.MAXIMUM),
                        }
                    )
                )
                self.assertEqual(boot["execution_epoch"], readiness.MAXIMUM)
                self.assertEqual(boot["address"], address)

    def test_network_requires_address_prefix_interface_and_both_routes(self) -> None:
        self.assertTrue(readiness.network_ready(self.boot, self.addresses, self.routes))
        for routes in (
            [],
            self.routes[:1],
            self.routes[1:],
            [{**item, "dev": "eth1"} for item in self.routes],
        ):
            self.assertFalse(readiness.network_ready(self.boot, self.addresses, routes))
        for change in (
            {"ifname": "eth1"},
            {"flags": []},
            {"addr_info": [{"family": "inet", "local": "10.20.1.2", "prefixlen": 16}]},
            {"addr_info": [{"family": "inet", "local": "10.20.1.3", "prefixlen": 32}]},
        ):
            self.assertFalse(
                readiness.network_ready(self.boot, [{**self.addresses[0], **change}], self.routes)
            )

    def test_root_probe_writes_syncs_and_removes_its_file(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            readiness.writable_root(root)
            self.assertEqual(os.listdir(root), [])
            with (
                patch.object(readiness.os, "fsync", side_effect=OSError("I/O error")),
                self.assertRaises(OSError),
            ):
                readiness.writable_root(root)
            self.assertEqual(os.listdir(root), [])

    def test_health_failure_at_every_probe_refuses_readiness(self) -> None:
        results = [b"", b"", json.dumps(self.addresses).encode(), json.dumps(self.routes).encode()]
        with (
            patch.object(readiness, "command", side_effect=results),
            patch.object(readiness, "writable_root") as root,
        ):
            self.assertTrue(readiness.ready(self.boot, "systemctl", "ip"))
            root.assert_called_once_with()
        for index in range(4):
            failed = [*results[:index], subprocess.CalledProcessError(1, "probe")]
            with (
                patch.object(readiness, "command", side_effect=failed),
                patch.object(readiness, "writable_root") as root,
            ):
                self.assertFalse(readiness.ready(self.boot, "systemctl", "ip"))
                root.assert_not_called()
        with (
            patch.object(readiness, "command", side_effect=results),
            patch.object(readiness, "writable_root", side_effect=OSError("read-only")),
        ):
            self.assertFalse(readiness.ready(self.boot, "systemctl", "ip"))

    def test_required_stack_units_must_all_be_active(self) -> None:
        units = "lilly.service marshall-inception.service postgresql.service"
        with patch.dict(os.environ, {"LILLY_REQUIRED_UNITS": units}):
            for failing in [None, *units.split()]:

                def execute(arguments: list[str], failing: str | None = failing) -> bytes:
                    if failing and failing in arguments:
                        raise subprocess.CalledProcessError(1, "systemctl")
                    if "address" in arguments:
                        return json.dumps(self.addresses).encode()
                    if "route" in arguments:
                        return json.dumps(self.routes).encode()
                    return b""

                with (
                    patch.object(readiness, "command", side_effect=execute),
                    patch.object(readiness, "writable_root"),
                ):
                    self.assertEqual(readiness.ready(self.boot, "systemctl", "ip"), failing is None)
        with (
            patch.dict(os.environ, {"LILLY_REQUIRED_UNITS": "--unexpected-option"}),
            patch.object(readiness, "command", return_value=b""),
        ):
            self.assertFalse(readiness.ready(self.boot, "systemctl", "ip"))

    def test_ssh_readiness_follows_configured_service(self) -> None:
        commands: list[list[str]] = []

        def execute(arguments: list[str]) -> bytes:
            commands.append(arguments)
            if "address" in arguments:
                return json.dumps(self.addresses).encode()
            if "route" in arguments:
                return json.dumps(self.routes).encode()
            return b""

        with (
            patch.dict(os.environ, {"LILLY_SSH_UNIT": "sshd.service"}),
            patch.object(readiness, "command", side_effect=execute),
            patch.object(readiness, "writable_root"),
        ):
            self.assertTrue(readiness.ready(self.boot, "systemctl", "ip"))
        self.assertIn(["systemctl", "is-active", "--quiet", "sshd.service"], commands)

    def test_route_query_keeps_device_fields_needed_for_validation(self) -> None:
        # iproute2 omits "dev" when the query itself filters by device.
        def execute(arguments: list[str]) -> bytes:
            if "address" in arguments:
                return json.dumps(self.addresses).encode()
            if "route" in arguments:
                routes = self.routes
                if "dev" in arguments:
                    routes = [
                        {key: value for key, value in route.items() if key != "dev"}
                        for route in routes
                    ]
                return json.dumps(routes).encode()
            return b""

        with (
            patch.object(readiness, "command", side_effect=execute),
            patch.object(readiness, "writable_root"),
        ):
            self.assertTrue(readiness.ready(self.boot, "systemctl", "ip"))

    def test_malformed_probe_results_fail_closed(self) -> None:
        for value in (b"invalid", b"null", b"{}", b'["bad"]'):
            with patch.object(readiness, "command", side_effect=[b"", b"", value, b"[]"]):
                self.assertFalse(readiness.ready(self.boot, "systemctl", "ip"))

    def test_nonhost_peer_does_not_probe_or_receive(self) -> None:
        for peer in (0, 1, 3, 99):
            server, client = socket.socketpair()
            with (
                server,
                client,
                patch.object(readiness, "ready") as probe,
                patch.object(readiness, "record_failure") as failure,
            ):
                readiness.answer(server, (peer, 1234), self.boot, BOOT_ID, probe)
                probe.assert_not_called()
                failure.assert_called_once_with("peer_rejected")
                server.shutdown(socket.SHUT_WR)
                self.assertEqual(client.recv(1), b"")

    def test_host_receives_only_live_ready_boot_bound_evidence(self) -> None:
        for healthy in (False, True):
            server, client = socket.socketpair()
            with server, client:
                readiness.answer(server, (2, 1234), self.boot, BOOT_ID, lambda ready=healthy: ready)
                server.shutdown(socket.SHUT_WR)
                body = client.recv(512)
            if healthy:
                self.assertLess(len(body), 512)
                self.assertTrue(body.endswith(b"\n"))
                self.assertEqual(
                    json.loads(body),
                    {
                        "version": 1,
                        "state": "ready",
                        "placement_id": PLACEMENT,
                        "execution_epoch": 9,
                        "boot_challenge": "a" * 64,
                        "boot_id": BOOT_ID,
                    },
                )
            else:
                self.assertEqual(body, b"")

    def test_invalid_kernel_boot_id_cannot_be_reported(self) -> None:
        with self.assertRaises(ValueError):
            readiness.response(self.boot, "invalid")


if __name__ == "__main__":
    unittest.main()
