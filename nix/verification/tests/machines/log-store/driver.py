import json
import shlex

INSERT = "fixture-insert-a94f8c2b51d7406e9b3c2f1a7d5e8f00"
READER = "fixture-reader-3c5128f9a04b47de88c1e5f02a6b94d77"
URL = "https://logs.fleet.internal:8443"
CA = "/run/logstore-fixture/ca.crt"


def read(query: str) -> str:
    return (
        "curl -fsS "
        f"-u reader:{READER} --cacert {CA} -G "
        f"--data-urlencode 'query={query}' '{URL}/select/logsql/query'"
    )


def check_operations_dashboard(api: str) -> None:
    """@cc [owner:ghuntley,label:verification] grafana-operations-provisioned-inventory
    Grafana's actual provisioned operations dashboard MUST contain the complete
    reviewed fleet, logging, custody, SDK-health and runtime panel inventory,
    with stable IDs, titles, visualization types and Prometheus query bindings.
    """
    expected: list[tuple[int, str, str]] = [
        (1, "Fleet measurements · numeric observations with bounded dimensions", "table"),
        (2, "Backup and updater state · unknown and failures remain visible", "table"),
        (3, "Logging queue bytes", "timeseries"),
        (4, "Oldest pending log chunk", "timeseries"),
        (5, "Log records dropped by destination", "timeseries"),
        (6, "Logging delivery retries", "timeseries"),
        (7, "Logging source validity and output budgets", "table"),
        (8, "Current infrastructure alerts", "table"),
        (9, "Trace custody · source validity, backlog and retained storage", "table"),
        (10, "SDK producer health · fresh local counters by host and unit", "table"),
        (11, "SDK health observation age · stale remains visible", "timeseries"),
        (12, "SDK queue refusals", "timeseries"),
        (13, "SDK export failures", "timeseries"),
        (14, "BEAM memory · fresh runtime observations", "timeseries"),
        (15, "BEAM run queue · fresh runtime observations", "timeseries"),
        (16, "Stuck agent turns", "timeseries"),
        (17, "Marshall page refresh · mean duration by view", "timeseries"),
        (18, "Marshall page refresh · mean database queries by view", "timeseries"),
        (19, "Marshall database · mean query time", "timeseries"),
        (20, "Marshall database · mean connection pool wait", "timeseries"),
        (21, "Marshall LiveView callbacks · mean duration by phase", "timeseries"),
        (22, "Marshall LiveView callbacks · mean database queries by phase", "timeseries"),
        (23, "Deployed source revision by host", "table"),
        (24, "Marshall database · callers waiting for a pool connection", "timeseries"),
        (25, "Marshall database · failed queries per minute", "timeseries"),
    ]
    store.succeed(
        api
        + "/api/dashboards/uid/overalls-fleet-operations | jq -e --argjson expected "
        + shlex.quote(json.dumps(expected, ensure_ascii=False))
        + " '.dashboard.panels | (map([.id, .title, .type]) == $expected)"
        ' and all(.[]; .datasource.type == "prometheus"'
        ' and .datasource.uid == "overalls-prometheus" and (.targets | length > 0)'
        ' and all(.targets[]; (.expr | type == "string") and (.expr | length > 0)))\''
    )


store.start()
worker.start()
store.wait_for_unit("victorialogs.service")
store.wait_for_unit("logstore-entry.service")
store.wait_for_unit("grafana.service")
worker.wait_for_unit("overalls-logging.service")

# Transport preconditions: name resolution, listener, TLS and path authority.
worker.succeed("getent hosts logs.fleet.internal | grep -q '^192.168.1.1 '")
store.succeed("ss -ltn | grep -q ':8443 '")
# The insert path is a separate authority: an insert credential posting an
# empty batch proves reachability, verified TLS and insert authority (200).
worker.wait_until_succeeds(
    f"curl -fsS -u insert:{INSERT} --cacert /run/logstore-fixture/ca.crt "
    f"-o /dev/null -w '%{{http_code}}' -X POST '{URL}/insert/jsonline' "
    "| grep -q 200",
    timeout=60,
)

worker.succeed("logger overalls-logstore-fixture")
worker.sleep(20)
print(
    "DIAG OUTPUTS:",
    worker.succeed(
        "python3 -c \"import json; d=json.load(open('/run/overalls-logging/fluent-bit.yaml'));"
        " print([(o.get('alias'), (o.get('logs_uri') or '')[:45]) for o in d['pipeline']['outputs']])\""
        " || true"
    ),
)
print(
    "DIAG ROUTES:",
    worker.succeed(
        "python3 -c \"import json; d=json.load(open('/run/overalls-logging/fluent-bit.yaml'));"
        " print([len((i.get('routes') or {}).get('logs', [])) for i in d['pipeline']['inputs']])\""
        " || true"
    ),
)
print(
    "DIAG STORED:",
    store.succeed(
        f"curl -fsS -u reader:{READER} --cacert {CA} -G --data-urlencode 'query=*' "
        f"--data-urlencode limit=3 '{URL}/select/logsql/query' || true"
    ),
)
store.wait_until_succeeds(
    f'{read("overalls-logstore-fixture")} | grep \'"origin.hostname":"worker"\'',
    timeout=240,
)

# Grafana's production datasource receives only reader authority through
# systemd credentials; its browser/API projection must never reveal it.
grafana: str = "curl -fsS -u fixture:fixture-private-grafana http://127.0.0.1:3000"
store.wait_until_succeeds(
    grafana
    + "/api/datasources/uid/overalls-victorialogs | jq -e '.basicAuth and .basicAuthUser == \"reader\" and .jsonData.tlsSkipVerify == false and .secureJsonFields.basicAuthPassword'"
)
store.fail(grafana + f"/api/datasources/uid/overalls-victorialogs | grep '{READER}'")
store.succeed(
    grafana
    + "/api/dashboards/uid/overalls-fleet-logs | jq -e '.dashboard.panels[0].datasource.uid == \"overalls-victorialogs\"'"
)
check_operations_dashboard(grafana)
worker.succeed(
    'logger \'{"event":"trace-correlation-fixture","trace_id":"1234567890abcdef1234567890abcdef","span_id":"1234567890abcdef"}\''
)
store.wait_until_succeeds(
    grafana
    + '/api/datasources/proxy/uid/overalls-victorialogs/select/logsql/query?query=trace-correlation-fixture | grep \'"trace_id":"1234567890abcdef1234567890abcdef"\'',
    timeout=240,
)
store.succeed(
    # Grafana converts the fleet entry's reader-authority 401 into proxy 400.
    "test $(curl -s -u fixture:fixture-private-grafana -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:3000/api/datasources/proxy/uid/overalls-victorialogs/insert/jsonline) = 400"
)
store.fail("runuser -u nobody -- cat /run/credentials/grafana.service/logstore-reader.password")
store.wait_until_succeeds(f"{read('source:system')} | grep overalls-logstore-fixture", timeout=60)

# Structured records without a payload message must surface a synthesized
# store message (stable event name), not a missing-field placeholder.
worker.succeed('logger \'{"event":"logstore_fixture_no_message","status":200}\'')
store.wait_until_succeeds(
    f'{read("*")} | grep \'"_msg":"logstore_fixture_no_message"\'',
    timeout=240,
)

# Entry authority: each credential is path-scoped and unknown requests are refused.
store.succeed(
    f"test \"$(curl -s -o /dev/null -w '%{{http_code}}' -u insert:{INSERT} --cacert {CA} "
    f"'{URL}/select/logsql/query?query=*')\" = 401"
)
store.succeed(
    f"test \"$(curl -s -o /dev/null -w '%{{http_code}}' -u reader:{READER} --cacert {CA} "
    f"-X POST '{URL}/insert/jsonline')\" = 401"
)
store.succeed(
    f"test \"$(curl -s -o /dev/null -w '%{{http_code}}' --cacert {CA} "
    f"'{URL}/select/logsql/query?query=*')\" = 401"
)
store.fail(f"curl -fsS -u reader:{READER} --capath /var/empty '{URL}/select/logsql/query?query=*'")

# The collector config keeps credentials private (root-only runtime file), and
# the Nix-store descriptor passed to the preparer holds paths, never values.
worker.succeed('test "$(stat -c %a /run/overalls-logging/fluent-bit.yaml)" = 600')
descriptor = worker.succeed(
    "systemctl show -p ExecStart --value overalls-logging.service"
    " | grep -o '/nix/store/[^ ;]*overalls-logging.json'"
).strip()
worker.succeed(f"test -f {descriptor}")
worker.succeed(f"! grep -q '{INSERT}' {descriptor}")
worker.succeed(f"grep -q '_credential_files' {descriptor}")

# Entry outages must not lose queued events: delivery resumes after restart.
store.succeed("systemctl stop logstore-entry.service")
worker.succeed("logger overalls-logstore-backfill-fixture")
worker.sleep(5)
store.succeed("systemctl start logstore-entry.service")
store.wait_until_succeeds(
    f'{read("overalls-logstore-backfill-fixture")} | grep \'"origin.hostname":"worker"\'',
    timeout=240,
)
