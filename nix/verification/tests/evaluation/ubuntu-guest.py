"""Unit and generated boundary tests against the real guest and lock helpers."""

import importlib.util
import sys
import types
import unittest
from collections.abc import Sequence
from pathlib import Path
from unittest.mock import patch

from hypothesis import given, settings
from hypothesis import strategies as st


def load(name: str, path: str | Path) -> types.ModuleType:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError("guest helper unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


root = Path(sys.argv.pop(1))
network = load("network", root / "network.py")
readiness = load("readiness", root / "readiness.py")
boot_report = load("boot_report", root / "boot_report.py")
platform_digest = load("platform_digest", root / "ubuntu/platform_digest.py")
resolver = load("resolver", root / "ubuntu/update-lock.py")
settings.register_profile("nix", max_examples=250, derandomize=True, database=None, deadline=None)
settings.load_profile("nix")


class GuestTests(unittest.TestCase):
    @given(st.sampled_from([10, 20, 30, 40]), st.integers(2, 65534))
    def test_network_and_readiness_agree_on_every_generated_valid_address(
        self, profile: int, slot: int
    ) -> None:
        ip = f"10.{profile}.{slot // 256}.{slot % 256}"
        address, gateway = network.parameters(f"console=ttyS0 lilly.ipv4={ip}")
        boot = readiness.identity(
            f"lilly.ipv4={ip} lilly.placement=11111111-1111-4111-8111-111111111111 "
            f"lilly.execution_epoch=1 lilly.boot_challenge={'a' * 64}"
        )
        self.assertEqual((address, gateway), (boot["address"], boot["gateway"]))
        with patch.object(network.subprocess, "run") as run:
            network.configure(f"lilly.ipv4={ip}", "/usr/sbin/ip")
            self.assertEqual(
                run.call_args_list[1].args[0],
                ["/usr/sbin/ip", "address", "replace", ip + "/32", "dev", "eth0"],
            )
            self.assertEqual(run.call_args_list[-1].args[0][-3:], [gateway, "dev", "eth0"])
            addresses = [
                call.args[0][3]
                for call in run.call_args_list
                if call.args[0][1:3] == ["address", "replace"]
            ]
            expected = [ip + "/32"]
            if profile == 40:
                expected.append(f"10.41.{slot // 256}.{slot % 256}/32")
            self.assertEqual(addresses, expected)

    @given(st.sampled_from([10, 20, 30, 40]), st.integers(2, 65534))
    def test_duplicate_address_never_mutates_network(self, profile: int, slot: int) -> None:
        param = f"lilly.ipv4=10.{profile}.{slot // 256}.{slot % 256}"
        with patch.object(network.subprocess, "run") as run:
            with self.assertRaises(ValueError):
                network.configure(param + " " + param, "/usr/sbin/ip")
            run.assert_not_called()

    @given(st.sampled_from([10, 20, 30, 40]), st.sampled_from([0, 1, 65535]))
    def test_reserved_slots_fail_before_effects(self, profile: int, slot: int) -> None:
        with patch.object(network.subprocess, "run") as run:
            with self.assertRaises(ValueError):
                network.configure(f"lilly.ipv4=10.{profile}.{slot // 256}.{slot % 256}", "ip")
            run.assert_not_called()

    def test_malformed_or_missing_address(self) -> None:
        for value in [
            "",
            "lilly.ipv4",
            "lilly.ipv4=",
            "lilly.ipv4=10.20.01.2",
            "lilly.ipv4=10.50.0.2",
            "lilly.ipv4=10.41.0.2",
            "lilly.ipv4=::1",
            "lilly.ipv4=10.20.0.2/32",
            "lilly.ipv4=10.20.0.2;reboot",
            "x" * 4097,
        ]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                network.parameters(value)

    @given(st.integers(1, 2**63 - 1))
    def test_boot_epoch_is_bound_and_duplicates_rejected(self, epoch: int) -> None:
        line = (
            "lilly.ipv4=10.20.1.2 lilly.placement=11111111-1111-4111-8111-111111111111 "
            f"lilly.execution_epoch={epoch} lilly.boot_challenge={'a' * 64}"
        )
        boot = readiness.identity(line)
        self.assertEqual(boot["execution_epoch"], epoch)
        with self.assertRaises(ValueError):
            readiness.identity(line + f" lilly.execution_epoch={epoch}")

    def test_packages_are_names_not_apt_commands(self) -> None:
        self.assertEqual(resolver.package_names(["git", "curl", "git"]), ["curl", "git"])
        for value in ["--allow-unauthenticated", "/tmp/foo.deb", "git=1", "git*", "git;id", ""]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                resolver.package_names([value])

    def test_download_records_require_sha256_and_official_snapshot(self) -> None:
        line = (
            "'https://snapshot.ubuntu.com/ubuntu/20260918T000000Z/pool/hello.deb' hello_2.10-1_amd64.deb 123 SHA256:"
            + "a" * 64
        )
        self.assertEqual(resolver.package_record(line)["version"], "2.10-1")
        for invalid in [
            line.replace("SHA256:", "MD5Sum:"),
            line.replace("amd64", "arm64"),
            line.replace("https://snapshot.ubuntu.com/ubuntu/", "http://untrusted/"),
            line.replace(" 123 ", " 0 "),
        ]:
            with self.assertRaises(ValueError):
                resolver.package_record(invalid)


class PlatformDigestTests(unittest.TestCase):
    def test_digest_matches_lilly_guest_trust_vector(self) -> None:
        # Lilly.VM.GuestTrust.digest(["a", "b"]) evaluated on the pinned runtime.
        expected = "18d79cb747ea174c59f3a3b41768672526d56fecc58360a99d283d0f9b0a3cc0"
        self.assertEqual(platform_digest.digest([b"a", b"b"]), expected)

    @given(st.lists(st.binary(min_size=1, max_size=64), min_size=1, max_size=8))
    def test_digest_ignores_root_order(self, roots: list[bytes]) -> None:
        self.assertEqual(
            platform_digest.digest(roots), platform_digest.digest(list(reversed(roots)))
        )

    def test_digest_refuses_an_empty_set(self) -> None:
        with self.assertRaises(ValueError):
            platform_digest.digest([])


class BootReportTests(unittest.TestCase):
    @given(st.text(max_size=4000), st.integers(1, 40))
    def test_every_emitted_line_is_marked_printable_and_bounded(
        self, text: str, limit: int
    ) -> None:
        lines = boot_report.bound(text, limit)
        self.assertLessEqual(len(lines), limit)
        for line in lines:
            self.assertTrue(line.startswith(boot_report.MARKER))
            self.assertTrue(line.isprintable())
            self.assertLessEqual(len(line), len(boot_report.MARKER) + boot_report.MAXIMUM_LINE)

    def test_timeline_renders_blocks_in_request_order(self) -> None:
        shown = (
            "InactiveExitTimestampMonotonic=1500000\nActiveEnterTimestampMonotonic=1877000\n\n"
            "InactiveExitTimestampMonotonic=0\nActiveEnterTimestampMonotonic=0\n"
        )
        self.assertEqual(
            boot_report.timeline(shown),
            [
                f"unit {boot_report.TIMELINE_UNITS[0]} since-kernel start=1.500s active=1.877s",
                f"unit {boot_report.TIMELINE_UNITS[1]} since-kernel start=- active=-",
            ],
        )

    def test_manager_phases_render_unfinished_boot(self) -> None:
        shown = (
            "InitRDTimestampMonotonic=1761000\nUserspaceTimestampMonotonic=5128000\n"
            "FinishTimestampMonotonic=0\n"
        )
        self.assertEqual(
            boot_report.manager(shown),
            "manager since-kernel initrd=1.761s userspace=5.128s finished=-",
        )

    def test_blame_drops_device_units(self) -> None:
        blame = "5.584s dev-vda.device\n1.660s register-nix-paths.service\n"
        self.assertEqual(boot_report.services(blame), "1.660s register-nix-paths.service")

    def test_report_waits_bounded_for_boot_finish_then_profiles(self) -> None:
        calls: list[list[str]] = []
        clock = [0.0]

        def run(arguments: Sequence[str]) -> str | None:
            calls.append(list(arguments))
            if arguments[1] == "time":
                return "Startup finished in 1s\n" if clock[0] >= 1.0 else None
            return "x\n"

        def sleep(seconds: float) -> None:
            clock[0] += seconds

        lines = boot_report.report("/a", "/c", "/j", run, sleep, lambda: clock[0])
        self.assertEqual(lines[0], boot_report.MARKER + "begin")
        self.assertEqual(lines[1], boot_report.MARKER + "Startup finished in 1s")
        self.assertEqual(lines[-1], boot_report.MARKER + "end")
        self.assertEqual(sum(1 for call in calls if call[1] == "time"), 5)

    def test_report_never_waits_past_its_deadline(self) -> None:
        clock = [0.0]

        def sleep(seconds: float) -> None:
            clock[0] += seconds

        lines = boot_report.report("/a", "/c", "/j", lambda _: None, sleep, lambda: clock[0])
        self.assertLessEqual(clock[0], boot_report.FINISH_DEADLINE_SECONDS + 1)
        self.assertIn(boot_report.MARKER + "Bootup is not yet finished", lines)
        self.assertEqual(lines[-1], boot_report.MARKER + "end")

    def test_report_keeps_unit_statuses_bound_to_their_names(self) -> None:
        def run(arguments: Sequence[str]) -> str | None:
            if len(arguments) >= 2 and arguments[1] == "time":
                return "Startup finished in 1s\n"
            if len(arguments) >= 3 and arguments[1:3] == ["show", "--no-pager"]:
                unit = arguments[-1]
                if unit == boot_report.STATUS_UNITS[0]:
                    return "ActiveState=active\nSubState=running\nResult=success\n"
                return None
            return "x\n"

        lines = boot_report.report("/a", "/c", "/j", run, lambda _: None, lambda: 0.0)
        self.assertIn(
            boot_report.MARKER
            + f"status unit={boot_report.STATUS_UNITS[0]} active=active substate=running result=success",
            lines,
        )
        self.assertIn(
            boot_report.MARKER
            + f"status unit={boot_report.STATUS_UNITS[1]} active=unknown substate=unknown result=unknown",
            lines,
        )


if __name__ == "__main__":
    unittest.main()
