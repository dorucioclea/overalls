# Artifacts and thread tool review

Date: 2026-10-21. Scope: ADR-0253's Marshall Artifacts domain, ADR-0254's
isolated content origin and ADR-0255's Marshall-executed server tools and
Thread state machine, including the Lyra `artifact_stage` executor command,
Ziggy's `artifact_chunk` route, the HAProxy/ACME content host and three new
NixOS machine tests.

## Architecture impact

`Marshall.Artifacts` is a new Ash domain inside the existing Marshall
deployable; it adds no service. Postgres remains the only shared durable store:
blobs are content-addressed 1 MiB chunks covered by existing backups. Cedar
gains an `Artifact` entity and eight artifact actions; no existing policy
changes. Authority for agent calls is the prompting user (`Turn.actor_id`),
rechecked per call against Cedar and machine Access, so a guest cannot widen
its reach through the tool.

Marshall-owned tools (`thread` and `message_board` from ADR-0252, plus
`artifact`) move from a polling GenServer to Oban (`agent_tools`), and the guest
executor claim excludes them. This fixes a pre-existing hazard where the guest
could claim `thread` commands. Thread status becomes an AshStateMachine; callers
that assigned status directly now call named transitions, each writing one
LifecycleEvent.

## Merge with ADR-0252

This change was rebased onto the concurrently accepted ADR-0252 (profile boards,
thread subscriptions, receivers, delivery and path-based attachments). By the
user's decision ADR-0252's thread tool design is kept unchanged. This change's
separate feed table, subscription resource and thread tool rewrite were
dropped before commit, and ADR numbers moved to 0253–0255. The polling worker's
body became `ThreadToolDispatch`, executed per command by `ServerToolJob` in one
transaction with ADR-0252's lock order. `attachment` stays executor-run.

The content origin is a second Bandit listener in each Marshall replica and a
second HAProxy frontend name with its own certificate. With no content host
configured, the rendered proxy configuration is unchanged.

## Reviewed failure boundaries

- **Authorization:** every decision is evaluated fresh. Unreadable and unknown
  artifacts and threads are indistinguishable (`not_found`). Administrator
  moderation requires elevation and grants no content access.
- **Concurrency:** publishes lock the artifact row. A stale base is refused with
  the current version and no mutation. Replay by command id returns the original
  version.
- **Staged uploads:** chunks are accepted only from the started stage command's
  fenced executor, for declared files, in dense order and within limits.
  Promotion recomputes SHA-256 from stored chunks. Expiry refuses and releases
  the request and resumes the parent tool call.
- **Exactly once:** the server-tool job locks the command. `thread` and
  `message_board` claim, run and finish in one transaction. Duplicate jobs, and
  jobs that run after the command is terminal, are no-ops. The reconciler
  re-enqueues orphaned queued commands and marks stale server claims
  `uncertain` instead of re-running them.
- **Content isolation:** the CSP `sandbox` directive yields an opaque origin even
  on top-level visits. HAProxy strips credentials in both directions. Marshall's
  `__Host-` cookie never reaches the content host. Same-site exposure remains
  until a separate registrable domain is configured (ADR-0254 open question).
- **Diagnostics:** catalogued events carry closed atoms, integers and UUIDs only.
  Content, tickets, paths, keys and arguments are never logged. Audit rows are
  written in the mutation's transaction.

## Validation

Recorded on 2026-10-21 in `~/src/overalls-artifacts`:

- `nix build .#checks.x86_64-linux.artifact-origin` passed: all 8 subtests,
  and the Hegel property `artifact_escape_payloads_stay_isolated` passed
  (8 test cases).
- Repository checks passed: `scripts/check_adrs.exs` (239 decisions after the merge),
  `scripts/check_logging.exs` (Marshall and Ziggy), `scripts/hldd_views.exs --check`,
  `scripts/check_conflict_markers.exs` and `scripts/check_contracts.exs`.
- `elixir/diagnostics` precommit passed after regenerating `priv/trace-schema.json`.
- Lyra `cargo test` and `cargo clippy` passed, including `artifact_stage`.
- ruff format, ruff check and ty passed on the changed machine-test drivers.

Defects found by the machine tests and fixed in this change:

- Executor registration admitted at most three capabilities; Lyra advertises
  five after the merge, so every current guest registration was refused.
- The release `config/runtime.exs` replaced the Oban queue list without
  `agent_tools` or `artifacts`, so server-tool and purge jobs never ran.
- The redaction scanner read its profile through a compile-time path that
  does not exist in Nix releases.
- The VM-stop board purge passed uncast UUIDs to Postgrex.
- The fleet provider fixture labelled its Responses stream
  `application/json`, so Ziggy rejected every guest model response.
- Lyra's `artifact_stage` refused files above 16 MiB although Marshall's
  per-publish limit, which it sends as `max_file_bytes`, is 64 MiB.

On the merged tree (trunk `9d8ff1ee0` plus this change), on 2026-10-21:

- `nix build .#checks.x86_64-linux.{artifact-origin,artifact-agent-publish,thread-tool,agent-fleet}`
  passed with 8, 11, 8 and 9 subtests respectively.
- Focused Marshall suites for artifacts, agents, threads, message boards, state
  machines, contracts and the artifact and thread LiveViews passed (Dialyzer
  clean). Lyra clippy and tests passed. Ziggy `mix precommit` passed.
- Merging exposed fixture assumptions: a machine root may carry only one
  top-level agent thread and at most one user thread, and ADR-0252 reads accept
  only a genuine machine binding. The thread-tool fixture now makes the shared
  thread the owner's machine thread with the member as operator.

## 2026-10-28 follow-up: feed and revocation jobs and missing properties

The plan's two remaining Oban jobs and its missing property tests were built on
trunk `f7b52cd21` ([ADR-0261](../decisions/0261-thread-feed-turn-notifications-and-subscription-revocation.md)):

- `Threads.FeedAppendJob` appends one `turn_finished` notification per finished
  ordinary top-level turn, enqueued in the turn-finish transaction; board
  cleanup and the job share `Agents.ThreadFeed` for dense sequencing.
- `Threads.SubscriptionRevokeJob`, enqueued by thread-grant, team-membership,
  SCIM cleanup and retirement changes, moves subscriptions whose owner lost
  current Cedar read to the new `revoked` state with one audit row each. The
  migration only widens the subscription state check.
- New Hegel properties: coordinator lifecycle, artifact authorization freshness
  (direct grants, team grants, membership, tickets), publish-request states,
  server-tool claims (executor exclusion, racing workers, reconciler), thread
  tool visibility and replay, feed-job revocation model and Oban idempotency
  (reruns, rolled-back runs, duplicate enqueues).

Defects found by the new properties and fixed here:

- `ServerToolReconciler` raised `Ecto.SubQueryError` on every run: its two
  schemaless `NOT EXISTS` subqueries had no `select`, so lost server-tool jobs
  were never re-enqueued and stale claims never finished `uncertain`.
- `provision_worker_property_test.exs` used StreamData syntax that Hegel lacks
  and did not compile, which stopped any Marshall run including the threads
  test directory.

New machine subtests:

- `artifact-agent-publish`: the owner's deletion stops a live viewer ticket and
  leaves a content-free tombstone with one `deleted` and one `purged` audit row;
  a purge of storage entries exceeding one 1,000-row batch (1,200 since
  2026-10-29), interrupted after one batch by stopping every Marshall replica,
  finishes after restart with no content rows; a server-tool command queued while the agent-tool queue is paused and every replica restarts
  runs exactly once and publishes exactly one version.
- `thread-tool`: revoking the member's share moves their subscription to
  `revoked`, deactivates its receivers and writes one
  `thread_subscription_revoked` audit row.

Defects found by the machine runs and fixed here:

- `fleet/scenarios/agent.py` asserted that a user thread's ID equals its agent
  thread's ID (trunk `4f262ee02`); the two are distinct identities, so every
  fleet check composing that subtest failed. It now checks that the user thread
  binds a top-level agent thread on its own machine.
- The fleet thread fixture's objective ("Report this machine's hostname") was
  not a scripted provider prompt, so the initial turn was refused with
  `prompt` and never completed once that subtest asserted completion. It now
  uses the scripted "Read this machine's hostname".
- `agent_revocation_history_test.exs` omitted the closed, content-free
  `context_captured` and `context_compacted` audit kinds from its receipt check.

Execution on 2026-10-28 (local, staged tree on `f7b52cd21`):

- `nix build .#checks.x86_64-linux.artifact-agent-publish` passed: all 15 subtests
- `nix build .#checks.x86_64-linux.thread-tool` passed: all 10 subtests
- Marshall agents, threads, transcript, sharing, message-board, state-machine,
  Oban-queue, teams, SCIM, accounts, contract and artifact suites passed
  (246 tests in the second run; the first run's only failure was the receipt
  check above). `mix dialyzer --force-check` reported 0 errors;
  `check_logging marshall`, `hldd_views --check` and `check_hldd` passed.

Architecture impact: ADR-0261 extends ADR-0252's subscription states and
notification kinds; ADR-0255's dispatch is unchanged. No machine test yet
exercises a `turn_finished` notification turn delivered to a subscribed agent;
that path is BEAM-only. Administrator deletion is covered by BEAM tests only,
because elevation cannot be held by an unattended fixture.

## 2026-10-29 follow-up: turn-finished delivery on the fleet

`thread-tool` gained the subtest "a finished turn notifies the subscriber once
and is not re-announced": the member's thread-tool turn appends exactly one
content-free `turn_finished` entry (keys `outcome` and `turn_id` only), the
member's receiver gets one completed `subscription_notification` turn with its
cursor acknowledged, no feed job remains and no entry names the notification
turn. The provider fixture now answers a trailing turn-finished notification
with a plain reply and refuses one carrying more than `thread_id`,
`notification_id`, `sequence` and `kind` (contract
`provider-turn-finished-notification`).

Defect found: the thread-seed fixture bound the shared user thread to a new
child agent thread instead of the root's top-level thread. Provisioning never
does that, and ADR-0261 never announces child threads, so no feed entry could
appear. The fixture now binds the top-level thread, as provisioning does.

Execution on 2026-10-29 (local, on `ab574b032`):

- `nix build .#checks.x86_64-linux.thread-tool` passed: all 11 subtests
- `nix build .#checks.x86_64-linux.artifact-agent-publish` passed: all 15
  subtests. The interrupted-purge subtest had timed out under host load with
  2,500 entries; it now fills 1,200 entries (still more than one 1,000-row
  batch), allows 600 seconds, and finished in 81 seconds.

Architecture impact: none; this adds evidence for ADR-0261 without changing a
decision. Remaining gap: delivery between two different machines' threads is
BEAM-only.

## Remaining gaps

- The stale-base `artifact-agent-publish` subtest failed intermittently with
  `provider_failed` before the merge and passed in every merged run;
  `agent.turn_preparation_failed` now names the preparation reason if it recurs.
- Native Chromium isolation (opaque origin, blocked storage and network) is
  asserted only by `artifact-origin`.
- Object-store offload and a dedicated content registrable domain are deferred.
