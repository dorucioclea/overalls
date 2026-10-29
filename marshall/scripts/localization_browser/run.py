"""@cc [owner:ghuntley,label:security;verification] localization-probe-private-custody
Context and trace files MUST remain owner-private. Printed results MUST contain
only coverage counts and booleans, never fixture URLs, credentials or page data.
Browser observations MUST NOT imply native guest or independent linguistic review.
"""

from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

ROUTES: frozenset[str] = frozenset(("/overview", "/machines", "/docs", "/docs/quickstart"))

LOCALES: frozenset[str] = frozenset(
    [
        "en",
        "zh-Hans",
        "hi",
        "es",
        "ar",
        "fr",
        "bn",
        "pt-BR",
        "pt-PT",
        "ru",
        "ur",
        "id",
        "de",
        "ja",
        "pcm",
        "mr",
        "te",
        "tr",
        "ta",
        "vi",
        "ko",
        "fil",
        "et",
        "fi",
        "sv",
        "arz",
        "sw",
        "ha",
    ]
)

MATRIX: frozenset[str] = frozenset(
    f"{locale}:{theme}:{width}"
    for locale in LOCALES
    for theme in ("light", "dark")
    for width in (390, 1440)
)


def mapping(value: object) -> dict[str, object]:
    if not isinstance(value, dict) or not all(isinstance(key, str) for key in value):
        raise ValueError("Expected a JSON object")
    return {str(key): item for key, item in value.items()}


def locale_set(value: object) -> set[str]:
    if not isinstance(value, str):
        return set()
    return {part for part in value.split(",") if part in LOCALES}


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: run_deterministic.py PRIVATE_CONTEXT NEW_OUTPUT_DIRECTORY")
        return 2
    os.umask(0o077)
    context_path = Path(sys.argv[1])
    if stat.S_IMODE(context_path.stat().st_mode) & 0o077:
        raise ValueError("Fixture context must be owner-readable only")
    context = mapping(json.loads(context_path.read_text()))
    origin, owner = context.get("origin"), context.get("owner")
    if not isinstance(origin, str) or not isinstance(owner, str):
        raise ValueError("Fixture origin/owner fields are missing")
    endpoint = urlsplit(origin)
    if (
        endpoint.scheme not in {"http", "https"}
        or endpoint.hostname not in ("localhost", "127.0.0.1")
        or not owner.startswith("/magic_link/")
    ):
        raise ValueError("Only the isolated local fixture is accepted")
    output = Path(sys.argv[2])
    output.mkdir(mode=0o700, parents=False, exist_ok=False)
    log = output / "private-run.log"
    with log.open("x") as stream:
        result = subprocess.run(
            [
                os.environ.get("BOMBADIL_BIN", "bombadil"),
                "browser",
                "test",
                origin.rstrip("/") + owner,
                str(Path(__file__).with_name("probe.ts")),
                "--header",
                "Accept-Language=ja-JP,ja;q=0.9,en;q=0.5",
                "--headless",
                "--no-sandbox",
                "--time-limit",
                "900s",
                "--exit-on-violation",
                "--output-path",
                str(output / "artifacts"),
            ],
            stdout=stream,
            stderr=subprocess.STDOUT,
            check=False,
        )
    require_machines = isinstance(context.get("vm_id"), str)
    route_coverage: set[str] = set()
    rtl_mixed_data: set[str] = set()
    pin_coverage: set[str] = set()
    clone_coverage: set[str] = set()
    covered: set[str] = set()
    reloaded: set[str] = set()
    matrix: set[str] = set()
    reset = False
    completed = False
    repeated_save = False
    authenticated_states = 0
    violations = 0
    trace = output / "artifacts" / "trace.jsonl"
    if trace.exists():
        with trace.open() as stream:
            for line in stream:
                record = mapping(json.loads(line))
                failures = record.get("violations")
                if isinstance(failures, list):
                    violations += len(failures)
                snapshots = record.get("snapshots")
                if not isinstance(snapshots, list):
                    continue
                for raw in snapshots:
                    snapshot = mapping(raw)
                    value = snapshot.get("value")
                    if not isinstance(value, dict):
                        continue
                    observation = mapping(value)
                    if observation.get("authenticatedSettings") is True:
                        authenticated_states += 1
                    raw_routes = observation.get("routeCoverage")
                    if isinstance(raw_routes, str):
                        route_coverage.update(
                            part
                            for part in raw_routes.split(",")
                            if part
                            in {f"{locale}:{route}" for locale in LOCALES for route in ROUTES}
                        )
                    rtl_mixed_data.update(locale_set(observation.get("rtlMixedData")))
                    pin_coverage.update(locale_set(observation.get("pinChecks")))
                    clone_coverage.update(locale_set(observation.get("cloneChecks")))
                    raw_matrix = observation.get("matrix")
                    if isinstance(raw_matrix, str):
                        matrix.update(part for part in raw_matrix.split(",") if part in MATRIX)
                    covered.update(locale_set(observation.get("covered")))
                    reloaded.update(locale_set(observation.get("reloaded")))
                    repeated_save |= observation.get("repeatedSaveVerified") is True
                    reset |= observation.get("resetVerified") is True
                    completed |= observation.get("completed") is True
    passed = (
        result.returncode == 0
        and violations == 0
        and covered == LOCALES
        and reloaded == LOCALES
        and matrix == MATRIX
        and repeated_save
        and reset
        and completed
        and authenticated_states > 0
        and rtl_mixed_data == {"ar", "arz", "ur"}
        and len(route_coverage) == len(LOCALES) * len(ROUTES)
        and (not require_machines or (pin_coverage == LOCALES and clone_coverage == LOCALES))
    )
    print(
        json.dumps(
            {
                "passed": passed,
                "route_locale_combinations": len(route_coverage),
                "required_route_locale_combinations": len(LOCALES) * len(ROUTES),
                "pin_locales": len(pin_coverage),
                "rtl_mixed_data_locales": len(rtl_mixed_data),
                "clone_form_locales": len(clone_coverage),
                "machine_fixture_required": require_machines,
                "exit_code": result.returncode,
                "authenticated_states": authenticated_states,
                "locales_observed": len(covered),
                "locales_persisted_after_reload": len(reloaded),
                "theme_viewport_combinations": len(matrix),
                "required_theme_viewport_combinations": len(MATRIX),
                "browser_reset_verified": reset,
                "repeated_save_from_fragment_verified": repeated_save,
                "completed": completed,
                "violations": violations,
            }
        )
    )
    return 0 if passed else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130) from None
    except Exception:
        print("Localization browser probe failed; inspect the private artifacts.", file=sys.stderr)
        raise SystemExit(1) from None
