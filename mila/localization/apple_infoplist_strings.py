#!/usr/bin/env python3
"""Write localized InfoPlist.strings for the Apple app from the Mila ARB catalogs.

iOS refuses Face ID without NSFaceIDUsageDescription. The text reuses the
existing `lockExplain` message, so no new source string is introduced.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ARB_NAME_RE = re.compile(r"^app_([a-z]{2,3})(?:_([A-Z]{2}|[A-Z][a-z]{3}))?\.arb$")
USAGE_KEYS = {"NSFaceIDUsageDescription": "lockExplain"}


def lproj_name(arb: Path) -> str | None:
    """Return the Apple `.lproj` locale for a catalog file, or None for a non-catalog file."""
    match = ARB_NAME_RE.match(arb.name)
    if match is None:
        return None
    language, subtag = match.groups()
    return f"{language}-{subtag}" if subtag else language


def _strings_literal(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{escaped}"'


def render(catalog: object) -> str | None:
    """Render InfoPlist.strings for one decoded ARB catalog; None when it has no usage text."""
    if not isinstance(catalog, dict):
        raise ValueError("ARB catalog is not a JSON object")
    lines: list[str] = []
    for plist_key, message_id in USAGE_KEYS.items():
        value: object = catalog.get(message_id)
        if value is None:
            continue
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"{message_id} must be non-empty text")
        lines.append(f"{plist_key} = {_strings_literal(value)};")
    return "\n".join(lines) + "\n" if lines else None


def generate(source: Path, resources: Path) -> list[str]:
    """Write `<locale>.lproj/InfoPlist.strings` under resources; return the locales written."""
    written: list[str] = []
    for arb in sorted(source.glob("app_*.arb")):
        locale = lproj_name(arb)
        if locale is None:
            raise ValueError(f"unexpected catalog name: {arb.name}")
        content = render(json.loads(arb.read_text(encoding="utf-8")))
        if content is None:
            continue
        directory = resources / f"{locale}.lproj"
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "InfoPlist.strings").write_text(content, encoding="utf-8")
        written.append(locale)
    if "en" not in written:
        raise ValueError("the English catalog must provide the usage text")
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source", type=Path, required=True, help="directory of app_<locale>.arb catalogs"
    )
    parser.add_argument(
        "--resources", type=Path, required=True, help="app bundle resources directory"
    )
    arguments = parser.parse_args()
    source: Path = arguments.source
    resources: Path = arguments.resources
    generate(source, resources)


if __name__ == "__main__":
    main()
