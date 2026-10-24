#!/usr/bin/env python3
"""Generate deterministic native localization bundles from Marshall PO catalogs.

The JSON intermediate is intentionally platform neutral; native build steps can
transform it into .strings, Android XML, gettext, or .resw resources.
"""

from __future__ import annotations

import argparse
import ast
import json
import re
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

LOCALE_RE = re.compile(r"^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$")
PLACEHOLDER_RE = re.compile(r"%\{([A-Za-z][A-Za-z0-9_]*)\}")
ARB_LOCALE_ALIASES = {"pt": "pt-BR", "zh": "zh-Hans"}


@dataclass(frozen=True)
class Message:
    context: str | None
    msgid: str
    plural: str | None
    forms: tuple[str, ...]


def _po_string(value: str) -> str:
    try:
        parsed = ast.literal_eval(value)
    except (SyntaxError, ValueError) as exc:
        raise ValueError(f"invalid PO string: {value}") from exc
    if not isinstance(parsed, str):
        raise ValueError("PO string is not text")
    return parsed


def parse_po(path: Path) -> list[Message]:
    fields: dict[str, str] = {}
    current: str | None = None
    messages: list[Message] = []

    def finish() -> None:
        nonlocal fields
        if "msgid" not in fields:
            fields = {}
            return
        if fields.get("__fuzzy") == "1":
            raise ValueError(f"fuzzy translation is not allowed: {path}")
        msgid = fields["msgid"]
        # Header entries are metadata, never user-facing messages.
        if not msgid:
            fields = {}
            return
        forms = tuple(v for key, v in sorted(fields.items()) if key.startswith("msgstr["))
        if not forms and "msgstr" in fields:
            forms = (fields["msgstr"],)
        messages.append(Message(fields.get("msgctxt"), msgid, fields.get("msgid_plural"), forms))
        fields = {}

    for raw in [*path.read_text(encoding="utf-8").splitlines(), ""]:
        line = raw.strip()
        if not line:
            finish()
            current = None
            continue
        if line.startswith("#,") and "fuzzy" in line:
            fields["__fuzzy"] = "1"
            continue
        match = re.match(r"(msgctxt|msgid_plural|msgid|msgstr(?:\[(\d+)\])?)\s+(.*)$", line)
        if match:
            key = match.group(1)
            current = key
            fields[key] = _po_string(match.group(3))
            continue
        if line.startswith('"') and current:
            fields[current] += _po_string(line)
            continue
        if line.startswith("#"):
            continue
        raise ValueError(f"unsupported PO syntax in {path}: {raw}")
    return messages


def parse_arb(path: Path) -> list[Message]:
    """Read a Mila ARB bundle for native localization generation.

    ARB message ids remain the stable source identity; metadata entries are
    ignored. ICU placeholders are preserved for the native generators.
    """
    values = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(values, dict):
        raise ValueError(f"ARB root is not an object: {path}")
    messages: list[Message] = []
    for key in sorted(k for k in values if not k.startswith("@")):
        value = values[key]
        if not isinstance(value, str):
            raise ValueError(f"ARB message is not a string: {path}: {key}")
        messages.append(Message(None, key, None, (value,)))
    return messages


def validate(messages: Iterable[Message], path: Path) -> None:
    identities: set[tuple[str | None, str, str | None]] = set()
    for message in messages:
        identity = (message.context, message.msgid, message.plural)
        if identity in identities:
            raise ValueError(f"duplicate message identity in {path}: {identity}")
        identities.add(identity)
        if not message.forms:
            raise ValueError(f"missing translation in {path}: {message.msgid!r}")
        for index, form in enumerate(message.forms):
            source = message.plural if message.plural is not None and index > 0 else message.msgid
            if not form:
                continue
            expected = set(PLACEHOLDER_RE.findall(source))
            if set(PLACEHOLDER_RE.findall(form)) != expected:
                raise ValueError(f"placeholder mismatch in {path}: {message.msgid!r}")


def generate(source: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    arb_files = sorted(source.glob("app_*.arb"))
    if arb_files:
        all_bundles: dict[str, dict[str, object]] = {}
        for arb in arb_files:
            locale = ARB_LOCALE_ALIASES.get(
                arb.stem.removeprefix("app_").replace("_", "-"),
                arb.stem.removeprefix("app_").replace("_", "-"),
            )
            parsed = parse_arb(arb)
            validate(parsed, arb)
            bundle = {
                "locale": locale,
                "domains": {
                    "mila": {
                        "messages": [
                            {
                                "context": m.context,
                                "id": m.msgid,
                                "plural": m.plural,
                                "forms": list(m.forms),
                            }
                            for m in parsed
                        ]
                    }
                },
            }
            if locale in all_bundles and all_bundles[locale] != bundle:
                raise ValueError(f"conflicting ARB aliases for locale {locale}: {arb}")
            all_bundles[locale] = bundle
        locales = sorted(all_bundles)
        for locale in locales:
            (output / f"{locale}.json").write_text(
                json.dumps(all_bundles[locale], ensure_ascii=False, sort_keys=True, indent=2)
                + "\n",
                encoding="utf-8",
            )
        (output / "manifest.json").write_text(
            json.dumps(
                {
                    "schema": 1,
                    "locales": locales,
                    "bundles": [f"{locale}.json" for locale in locales],
                },
                sort_keys=True,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        return
    locales = sorted(p.name for p in source.iterdir() if p.is_dir() and LOCALE_RE.match(p.name))
    if not locales:
        raise ValueError(f"no locale directories found under {source}")
    all_bundles: dict[str, dict[str, object]] = {}
    for locale in locales:
        domains: dict[str, dict[str, object]] = {}
        for po in sorted((source / locale / "LC_MESSAGES").glob("*.po")):
            domain = po.stem
            parsed = parse_po(po)
            validate(parsed, po)
            domains[domain] = {
                "messages": [
                    {
                        "context": m.context,
                        "id": m.msgid,
                        "plural": m.plural,
                        "forms": list(m.forms),
                    }
                    for m in sorted(
                        parsed, key=lambda x: (x.context or "", x.msgid, x.plural or "")
                    )
                ]
            }
        all_bundles[locale] = {"locale": locale, "domains": domains}
        (output / f"{locale}.json").write_text(
            json.dumps(all_bundles[locale], ensure_ascii=False, sort_keys=True, indent=2) + "\n",
            encoding="utf-8",
        )
    manifest = {
        "schema": 1,
        "locales": locales,
        "bundles": [f"{locale}.json" for locale in locales],
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, sort_keys=True, indent=2) + "\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path("marshall/priv/gettext"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    generate(args.source, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
