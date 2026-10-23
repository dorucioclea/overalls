# 2026-10-23: Host-row lock convoy behind /threads and /machines 5xx

## Scope

This review covers the production incident on panterloons (2026-10-23 ~05:20 UTC)
and its fix, across three dimensions:

- concurrency: compute host row locks;
- capacity: the Marshall database pool;
- reliability and observability: LiveView failure handling and span reasons.

The fix touches:

- `Marshall.Compute.Ledger.lock!/2` and `lock_history!/2`;
- `ThreadsLive` and `MachinesLive` refresh;
- `MarshallWeb.LiveObservability`;
- the production `poolSize`.

The deployment revision work is recorded in
[ADR-0259](../decisions/0259-deployment-revision-telemetry.md).

## Observations

Taken from the journal, HAProxy, `pg_stat_activity`, the PostgreSQL log,
Prometheus and Tempo:

- **Page failures.**
  - Failed `marshall.live.callback` spans for `threads_live` (mount and
    handle_params, 11–586 queries, up to 10 s), `machines_live` refresh and
    `terminal_live`.
  - HAProxy logged 500s and 503 NOSRV bursts.
- **Pool saturation.** With `POOL_SIZE=10`, the summed pool checkout wait was
  about 500 s per minute for 14+ hours, at roughly 70k queries/min.
- **Lock queue.** 6–7 of the 10 connections queued on
  `SELECT … FROM compute_hosts WHERE id = $1 FOR UPDATE`, and only two host rows
  exist.
- **Deadlocks.** PostgreSQL reported deadlocks between that lock and
  `INSERT INTO agent_model_calls`. The insert's foreign key takes `FOR KEY SHARE`
  on `compute_hosts`, which conflicts with `FOR UPDATE`.
- **Background loops.** Scheduler, notification and web-search loops failed every
  ~10 s.
- **Misleading dashboard.** The "mean connection pool wait" panel showed ~7 ms,
  which hid the saturation.

## Findings

1. **High, resolved. The host lock conflicted with every foreign-key check.**
   - **Problem.** `Credentials.with_host/2` locks the host on every Lilly exchange
     (one per second per host). Placement, model calls and operations insert rows
     referencing `compute_hosts`. With `FOR UPDATE`, each of those inserts queued
     behind (or deadlocked with) an exchange.
   - **Fix.** `Ledger.lock_mode(Host)` is now `FOR NO KEY UPDATE`. Host keys are
     immutable, so exchanges, rotation and placement still serialize with one
     another, while `FOR KEY SHARE` no longer conflicts.
   - **Guard.** Contract `ledger-host-lock-no-key`;
     `test/marshall/compute/ledger_host_lock_test.exs`.
2. **High, resolved. Guest RPCs held `FOR SHARE` across their work.**
   - **Problem.** After the first fix deployed, `pg_stat_activity` still showed
     15 of 22 connections queued on the host rows. The holders were
     `idle in transaction`, running user, thread and agent-root reads.
     - Inference, Galileo and Peach authentication held the host `FOR SHARE`
       across the whole RPC.
     - Each exchange's `FOR NO KEY UPDATE` waited for those readers.
     - New `FOR SHARE` readers then queued behind the exchange.
   - **Fix.**
     - Those readers take `Ledger.share_host!/1` (`FOR KEY SHARE`).
     - Writers that change what the readers check take `Ledger.fence_host!/1`
       (`FOR UPDATE`): admin enable/disable, drain, retire, and the credential
       issue, rotation and revocation paths.
     - `FOR UPDATE` waits for and excludes every reader, so the fence is
       preserved.
     - Ingress readers keep `FOR SHARE`, because they also check connection
       liveness fields that exchanges update.
   - **Guard.** Contract `ledger-host-guest-fence`; tests in
     `ledger_host_lock_test.exs`.
3. **High, resolved. LiveViews crashed instead of degrading.**
   - **Problem.** Bang reads and Ash generic actions re-raise database errors, so
     the `{:error, _}` fallbacks never ran.
   - **Fix.** `ThreadsLive` and `MachinesLive` refresh rescue Ash, DBConnection
     and Postgrex errors. They fail closed: they clear selected details,
     permissions and grants, and a machine page leaves for the list.
     `MachinesLive` backs its timer off to 5 s after a failure. `ThreadsLive` no
     longer refreshes in both `mount` and `handle_params`.
   - **Guard.** Contracts `threads-refresh-fails-closed` and
     `machines-refresh-fails-closed`.
4. **Medium, resolved. Failure cause was not observable.** Failed callback spans
   now carry a closed `reason` attribute, never a message. Contract
   `live-callback-exception-reason`; tests in `live_observability_test.exs`.
5. **Medium, resolved. Pool undersized for one replica.** The production
   `poolSize` rises from 10 to 20. The budget is 1 × (20 + 3) + 10 = 33 of 64
   PostgreSQL connections.
6. **Medium, open. `ModelCalls.queue/3` holds the turn, thread and VM locks
   during CPU-heavy context projection.** The projection reads under those locks
   on purpose. Moving it out needs a recheck design, so it is deferred.
7. **Low, open.**
   - Threads authorization still runs one Cedar decision per row without the
     `DecisionSnapshot` memoization used by `Compute.Views`.
   - No PostgreSQL lock/deadlock exporter feeds Grafana yet.

## Architecture impact

- No accepted decision changes.
- Host serialization (single writer per host row) is preserved; only the lock
  strength changes. It remains strong enough to exclude every other host
  mutation.
- ADR-0259 records the new telemetry provenance.

## Verification

- Focused Marshall tests: ledger host lock, live observability, threads,
  machines, machine pins, database wait, model calls and credentials.
- Spool and Lyra Rust tests.
- `otelcol-contrib validate` on the generated production collector config.
- Known Inception failure: `machines_live_test.exs:492` fails identically on the
  baseline.
- After deployment, confirm all of:
  - no `compute_hosts` lock waiters in `pg_stat_activity`;
  - no `deadlock detected` in the PostgreSQL log;
  - no failed `marshall.live.callback` spans in Tempo.
