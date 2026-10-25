"""Real local crypto and workspace preparation in isolated temporary directories."""

import hashlib
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

source, openssl, git = sys.argv[1:4]
del sys.argv[1:4]
sys.path.insert(0, source)
spec = importlib.util.spec_from_file_location("prepare", str(Path(source) / "prepare.py"))
if spec is None or spec.loader is None:
    raise RuntimeError("prepare helper unavailable")
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class PreparationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def test_public_certificates_are_readable_despite_private_bootstrap_umask(self) -> None:
        public = self.root / "public"
        previous = os.umask(0o077)
        try:
            with patch.object(prepare, "PUBLIC", public):
                prepare.public_certificate("ca.crt", b"synthetic public certificate")
                self.assertEqual(public.stat().st_mode & 0o777, 0o755)
                self.assertEqual((public / "ca.crt").stat().st_mode & 0o777, 0o644)
                self.assertEqual([p.name for p in public.iterdir()], ["ca.crt"])
        finally:
            os.umask(previous)

    def test_tls_is_unique_per_instance_and_stable_across_retries(self) -> None:
        fingerprints = []
        for name in ["first", "second"]:
            state = prepare.private_directory(self.root / name)
            with (
                patch.object(prepare, "STATE", state),
                patch.object(prepare, "public_certificate") as public,
            ):
                prepare.certificates(openssl)
                before = {
                    p.name: hashlib.sha256(p.read_bytes()).digest()
                    for p in (state / "tls").iterdir()
                }
                prepare.certificates(openssl)
                after = {
                    p.name: hashlib.sha256(p.read_bytes()).digest()
                    for p in (state / "tls").iterdir()
                }
                self.assertEqual(before, after)
                fingerprints.append(before["ca.key"])
                for call in public.call_args_list:
                    self.assertEqual(call.args[0], "ca.crt")
                    self.assertIn(b"BEGIN CERTIFICATE", call.args[1])
                    self.assertNotIn(b"PRIVATE KEY", call.args[1])
                if name == "second":
                    (state / "tls" / "marshall.key").write_bytes(
                        (state / "tls" / "database.key").read_bytes()
                    )
                    with self.assertRaisesRegex(prepare.SetupError, "TLS identity mismatch"):
                        prepare.certificates(openssl)
        self.assertNotEqual(*fingerprints)

    def test_workspace_is_editable_git_and_never_overwritten(self) -> None:
        source = self.root / "source"
        source.mkdir()
        (source / "file.ex").write_text("original")
        (source / "file.ex").chmod(0o444)
        subprocess.run(
            [git, "-C", str(source), "init", "--initial-branch=main"],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        subprocess.run([git, "-C", str(source), "add", "."], check=True, stdout=subprocess.DEVNULL)
        subprocess.run(
            [
                git,
                "-C",
                str(source),
                "-c",
                "user.name=fixture",
                "-c",
                "user.email=fixture@example.test",
                "commit",
                "-m",
                "fixture",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        workspace = self.root / "workspace"
        with patch.object(prepare, "WORKSPACE", workspace):
            prepare.prepare_source(source.as_uri(), git)
            target = workspace / "overalls"
            self.assertTrue((target / ".git").is_dir())
            self.assertEqual(workspace.stat().st_mode & 0o777, 0o755)
            self.assertEqual(target.stat().st_mode & 0o777, 0o777)
            self.assertEqual((target / "file.ex").stat().st_mode & 0o777, 0o666)
            (target / "file.ex").write_text("developer edits")
            prepare.prepare_source(source.as_uri(), git)
            self.assertEqual((target / "file.ex").read_text(), "developer edits")
            status = subprocess.check_output([git, "-C", str(target), "status", "--porcelain"])
            self.assertEqual(status.strip(), b"M file.ex")
            # URL rewriting in an interactive repository-local config must not
            # change the bootstrap's raw canonical-origin validation.
            subprocess.run(
                [
                    git,
                    "-C",
                    str(target),
                    "config",
                    "--local",
                    "url.file:///wrong.insteadOf",
                    source.as_uri(),
                ],
                check=True,
                stdout=subprocess.DEVNULL,
            )
            prepare.prepare_source(source.as_uri(), git)
            subprocess.run(
                [git, "-C", str(target), "remote", "set-url", "origin", "file:///wrong"],
                check=True,
                stdout=subprocess.DEVNULL,
            )
            with self.assertRaisesRegex(prepare.SetupError, "development source origin invalid"):
                prepare.prepare_source(source.as_uri(), git)

    def test_existing_workspace_symlink_and_non_git_path_fail_closed(self) -> None:
        workspace = self.root / "workspace"
        workspace.mkdir()
        outside = self.root / "outside"
        outside.mkdir()
        with patch.object(prepare, "WORKSPACE", workspace):
            (workspace / "overalls").symlink_to(outside, target_is_directory=True)
            with self.assertRaisesRegex(prepare.SetupError, "development workspace invalid"):
                prepare.prepare_source("file:///unreachable", git)
            (workspace / "overalls").unlink()
            (workspace / "overalls").mkdir()
            with self.assertRaisesRegex(prepare.SetupError, "development workspace invalid"):
                prepare.prepare_source("file:///unreachable", git)

    def test_existing_workspace_ownership_and_permissions_fail_closed(self) -> None:
        workspace = self.root / "workspace"
        workspace.mkdir()
        target = workspace / "overalls"
        target.mkdir()
        (target / ".git").mkdir()
        with patch.object(prepare, "WORKSPACE", workspace):
            # The Nix sandbox permits the owner to set the sticky bit but
            # rejects setuid, so use a portable special mode here.
            target.chmod(0o1755)
            with self.assertRaisesRegex(prepare.SetupError, "development workspace invalid"):
                prepare.prepare_source("file:///unreachable", git)
            target.chmod(0o755)
            (target / ".git").chmod(0o1755)
            with self.assertRaisesRegex(prepare.SetupError, "development workspace invalid"):
                prepare.prepare_source("file:///unreachable", git)
            if os.getuid() == 0:
                os.chown(target, 65534, -1)
                (target / ".git").chmod(0o755)
                with self.assertRaisesRegex(prepare.SetupError, "development workspace invalid"):
                    prepare.prepare_source("file:///unreachable", git)

    def test_database_password_is_only_on_stdin_with_statement_logging_disabled(self) -> None:
        identity = prepare.identities(self.root)
        config = {"runuser": "/runuser", "psql": "/psql"}
        with patch.object(prepare, "command") as command:
            prepare.prepare_database(identity, config)
            prepare.prepare_database(identity, config)
            first, second = command.call_args_list
            self.assertEqual(first, second)
            self.assertNotIn(identity["database_password"], " ".join(first.args[0]))
            self.assertIn(b"SET log_statement = 'none'", first.args[1])
            self.assertIn(b"SET log_min_error_statement = 'panic'", first.args[1])


unittest.main()
