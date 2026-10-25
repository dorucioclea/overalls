"""Publish the current Lilly Git attribution for the Inception guest.

The generic workspace receiver is intentionally disabled in Inception.  This
small boot unit keeps the Git identity capability useful for the guest-owned
checkout while accepting only the bounded value Lilly placed on this boot's
kernel command line.
"""

import base64
import binascii
import json
import os
import re
import secrets
import stat
import unicodedata
from pathlib import Path
from typing import TypedDict


class SetupError(Exception):
    """A fixed, secret-free identity setup failure."""


class GitIdentity(TypedDict):
    version: int
    name: str
    email: str


IDENTITY_PREFIX = "lilly.git_identity="
IDENTITY_DIRECTORY = Path("/run/overalls-workspace/git-identity")
MAXIMUM_CMDLINE = 4096
MAXIMUM_ENCODING = 2731
MAXIMUM_JSON = 2048
EMAIL = re.compile(
    r"[A-Za-z0-9!#$%&'*+\-/=?^_`{|}~]+"
    r"(?:\.[A-Za-z0-9!#$%&'*+\-/=?^_`{|}~]+)*@"
    r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
    r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*"
)


def _valid_name(value: object) -> bool:
    return (
        isinstance(value, str)
        and 1 <= len(value.encode()) <= 128
        and value.strip() == value
        and all(
            unicodedata.category(character) not in {"Cc", "Cf"} and character not in "<>"
            for character in value
        )
    )


def _valid_email(value: object) -> bool:
    if not isinstance(value, str) or EMAIL.fullmatch(value) is None:
        return False
    try:
        size = len(value.encode("ascii"))
    except UnicodeEncodeError:
        return False
    return 3 <= size <= 254


def validate(value: object) -> GitIdentity:
    """@cc [owner:ghuntley,label:security;protocol] inception-git-identity-grammar
    A boot Git identity MUST be exactly version 1 with a bounded UTF-8 name
    and ASCII mailbox. Controls, format characters, display-name delimiters,
    malformed mailboxes and unknown fields MUST fail closed.
    """
    if (
        not isinstance(value, dict)
        or set(value) != {"version", "name", "email"}
        or type(value.get("version")) is not int
        or value["version"] != 1
        or not _valid_name(value.get("name"))
        or not _valid_email(value.get("email"))
    ):
        raise SetupError("git identity invalid")
    return GitIdentity(version=1, name=value["name"], email=value["email"])


def parse_command_line(command_line: str) -> GitIdentity | None:
    """@cc [owner:ghuntley,label:security;recovery] inception-git-identity-cmdline
    The current boot command line MUST be at most 4096 ASCII bytes and contain
    at most one unpadded base64url `lilly.git_identity` value. Missing identity
    clears the runtime include; duplicate, malformed or oversized values MUST
    refuse without publishing a replacement.
    """
    try:
        size = len(command_line.encode("ascii"))
    except UnicodeEncodeError:
        raise SetupError("git identity invalid") from None
    if size > MAXIMUM_CMDLINE:
        raise SetupError("git identity invalid")
    values = [
        field.removeprefix(IDENTITY_PREFIX)
        for field in command_line.split()
        if field.startswith(IDENTITY_PREFIX)
    ]
    if not values:
        return None
    encoded = values[0]
    if len(values) != 1 or not 1 <= len(encoded) <= MAXIMUM_ENCODING:
        raise SetupError("git identity invalid")
    if "=" in encoded or re.fullmatch(r"[A-Za-z0-9_-]+", encoded) is None:
        raise SetupError("git identity invalid")
    if len(encoded) % 4 == 1:
        raise SetupError("git identity invalid")
    try:
        decoded = base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4))
    except (binascii.Error, ValueError):
        raise SetupError("git identity invalid") from None
    if len(decoded) > MAXIMUM_JSON:
        raise SetupError("git identity invalid")
    try:
        value: object = json.loads(decoded)
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise SetupError("git identity invalid") from None
    return validate(value)


def _directory(path: Path) -> None:
    path.mkdir(mode=0o755, parents=True, exist_ok=True)
    info = path.lstat()
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.geteuid()
        or info.st_mode & 0o022
        or path.resolve() != path
    ):
        raise SetupError("git identity directory invalid")
    path.chmod(0o755)


def install(identity: GitIdentity | None, directory: Path = IDENTITY_DIRECTORY) -> None:
    """@cc [owner:ghuntley,label:security;recovery] inception-git-identity-atomic
    The identity include MUST be root-owned, mode 0644 and atomically replaced
    under a validated runtime directory. Existing links, foreign ownership,
    writable parents and interrupted writes MUST fail without redirecting the
    privileged publication.
    """
    _directory(directory)
    path = directory / "gitconfig"
    if os.path.lexists(path):
        info = path.lstat()
        if (
            not stat.S_ISREG(info.st_mode)
            or info.st_uid != os.geteuid()
            or info.st_mode & 0o022
            or info.st_nlink != 1
        ):
            raise SetupError("git identity file invalid")
    if identity is None:
        content = b""
    else:
        name = identity["name"].replace("\\", "\\\\").replace('"', '\\"')
        email = identity["email"].replace("\\", "\\\\").replace('"', '\\"')
        content = f'[user]\n\tname = "{name}"\n\temail = "{email}"\n'.encode()
    temporary = directory / f".gitconfig.{secrets.token_hex(8)}"
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC
    descriptor = os.open(temporary, flags, 0o644)
    try:
        written = 0
        while written < len(content):
            written += os.write(descriptor, content[written:])
        os.fsync(descriptor)
        os.fchmod(descriptor, 0o644)
    finally:
        os.close(descriptor)
    try:
        os.replace(temporary, path)
        parent = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
        try:
            os.fsync(parent)
        finally:
            os.close(parent)
    finally:
        temporary.unlink(missing_ok=True)


def main() -> None:
    try:
        command_line = Path("/proc/cmdline").read_bytes().decode("ascii")
        install(parse_command_line(command_line))
    except (OSError, UnicodeDecodeError, SetupError):
        raise SystemExit("git identity setup failed") from None


if __name__ == "__main__":
    main()
