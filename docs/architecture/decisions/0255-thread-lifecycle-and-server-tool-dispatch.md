# ADR-0255: Thread lifecycle state machine and Oban server-tool dispatch

- ID: ADR-0255
- Date: 2026-10-21
- Status: accepted
- Implementation: partial
- Components: Marshall agents, threads, executor sessions, Oban
- Supersedes: none
- Superseded by: none

## Context

[ADR-0252](0252-profile-boards-and-thread-subscriptions.md) defines the `thread`
and `message_board` tools, durable subscriptions and receivers. Their commands
were executed by a 500 ms polling GenServer started on every replica, beside
Oban, which already provides retry, uniqueness and recovery for Marshall's other
background work. The guest executor's claim query could also claim
Marshall-owned commands. `Threads.Thread.status` was written directly by several
callers, so no single definition of legal lifecycle edges existed. The user asked
for state machines, property-based tests, audit logs and Oban where appropriate.

## Decision

`Threads.Thread.status` becomes an AshStateMachine with the transitions
`begin_provisioning`, `mark_ready`, `mark_failed`, `requeue`, `replace_generation`,
`reopen`, `mark_deleting` and `mark_archived`. No action accepts `status`. Every
committed transition writes exactly one `LifecycleEvent` through
`Compute.LifecycleAudit` and synchronizes the current generation in the same
transaction. A database check constraint bounds the stored states. Coordinator,
provisioning and archive workers call the named transitions.

`Marshall.Agents.ServerToolJob` (Oban queue `agent_tools`, unique on command id)
replaces the polling worker. Queuing any Marshall-owned command (`thread`,
`message_board`, `artifact`) enqueues the job in the same transaction. For
`thread` and `message_board`, the job runs `ThreadToolDispatch.run_locked/1` in one
transaction; it preserves ADR-0252's lock order, authority checks, dispatch and
result shape unchanged. Typed server tools implementing `Marshall.Agents.ServerTool`
(currently `artifact`, [ADR-0253](0253-artifacts-domain.md)) are claimed under the
command lock with a server claim id after fresh turn, capability, actor, VM-access
and Cedar checks, then executed and finished with one audit row.

A `ServerToolReconciler` cron re-enqueues queued server-tool commands with no
live job and finishes stale server claims `uncertain` with one audit row. The
executor claim query excludes `web_search` and every `ServerTool.tools/0` entry, so
guest executors never claim Marshall-owned work. `attachment` remains
executor-run under ADR-0252.

## Alternatives

Fixing the polling worker in place keeps a second scheduler beside Oban and
duplicates retry and uniqueness logic. Replacing ADR-0252's subscription design
with a separate feed table was considered and rejected so one delivery model
remains. Validating transitions in callers instead of the resource leaves illegal
edges reachable from new code.

## Consequences

Server-owned commands no longer wait for a poll interval and survive replica
crashes through Oban retries and the reconciler. Thread lifecycle edges are
defined in one place and audited exactly once. Callers that wrote `status`
directly must use the named transitions.

## Invariants and verification

The executor never claims a Marshall-owned tool; a command finishes at most once
with one finish audit row; a rejected thread transition changes nothing; an
accepted one writes one lifecycle event and keeps the generation status in step.
Evidence: the Thread state-machine Hegel property test, the state-machine action
check, server-tool and executor-session tests, and the NixOS machine tests
`thread-tool`, `agent-fleet` and `artifact-agent-publish`.

## Implementation evidence

- [Thread resource](../../../marshall/lib/marshall/threads/thread.ex) and [state-machine property test](../../../marshall/test/marshall/threads/thread_state_machine_property_test.exs).
- [ServerToolJob](../../../marshall/lib/marshall/agents/server_tool_job.ex), [ThreadToolDispatch](../../../marshall/lib/marshall/agents/thread_tool_dispatch.ex) and [reconciler](../../../marshall/lib/marshall/agents/server_tool_reconciler.ex).
- [Executor claim](../../../marshall/lib/marshall/agents/executor_session.ex).

## Open questions

None.

## Related decisions

Builds on [ADR-0252](0252-profile-boards-and-thread-subscriptions.md);
[ADR-0253](0253-artifacts-domain.md) adds the `artifact` server tool.
[ADR-0261](0261-thread-feed-turn-notifications-and-subscription-revocation.md) adds the feed-append and subscription-revocation jobs.
