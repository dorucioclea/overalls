"""Bounded Inception Git identity writer checks."""

import base64
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("git_identity", sys.argv.pop(1))
if spec is None or spec.loader is None:
    raise RuntimeError("identity helper unavailable")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class GitIdentityTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        raw = json.dumps(
            {"version": 1, "name": "Example Person", "email": "person@example.test"},
            separators=(",", ":"),
        ).encode()
        self.encoded = base64.urlsafe_b64encode(raw).decode().rstrip("=")

    def test_parse_and_install(self) -> None:
        identity = module.parse_command_line(f"quiet lilly.git_identity={self.encoded}")
        self.assertIsNotNone(identity)
        destination = self.root / "identity"
        module.install(identity, destination)
        self.assertEqual(
            (destination / "gitconfig").read_text(),
            '[user]\n\tname = "Example Person"\n\temail = "person@example.test"\n',
        )
        self.assertEqual((destination / "gitconfig").stat().st_mode & 0o777, 0o644)

    def test_missing_identity_clears_include(self) -> None:
        destination = self.root / "identity"
        module.install(module.parse_command_line(f"lilly.git_identity={self.encoded}"), destination)
        module.install(None, destination)
        self.assertEqual((destination / "gitconfig").read_bytes(), b"")

    def test_config_is_effective_through_system_include(self) -> None:
        destination = self.root / "identity"
        identity = module.parse_command_line(f"lilly.git_identity={self.encoded}")
        module.install(identity, destination)
        system = self.root / "gitconfig"
        system.write_text(
            f"[include]\n\tpath = {destination / 'gitconfig'}\n",
            encoding="utf-8",
        )
        result = subprocess.run(
            ["git", "var", "GIT_AUTHOR_IDENT"],
            cwd=self.root,
            env={
                **os.environ,
                "HOME": str(self.root),
                "GIT_CONFIG_SYSTEM": str(system),
                "GIT_CONFIG_GLOBAL": os.devnull,
            },
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertTrue(result.stdout.startswith("Example Person <person@example.test> "))

    def test_rejects_duplicate_and_malformed_values(self) -> None:
        value = f"lilly.git_identity={self.encoded}"
        with self.assertRaises(module.SetupError):
            module.parse_command_line(f"{value} {value}")
        with self.assertRaises(module.SetupError):
            module.parse_command_line("lilly.git_identity=not-base64!")
        with self.assertRaises(module.SetupError):
            module.validate({"version": 1, "name": "bad\nname", "email": "person@example.test"})
        with self.assertRaises(module.SetupError):
            module.validate({"version": 1, "name": "Name", "email": "pé@example.test"})


unittest.main()
