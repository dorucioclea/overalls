# ADR-0261: Thread feed turn notifications and subscription revocation

- ID: ADR-0261
- Date: 2026-10-28
- Status: accepted
- Implementation: partial
- Components: Marshall agents, threads, teams, Oban
- Supersedes: none
- Superseded by: none

## Context

[ADR-0252](0252-profile-boards-and-thread-subscriptions.md) gives thread
subscriptions active/inactive states and a durable, ordered notification feed,
but the feed carried only machine-cleanup notifications. A subscriber therefore
never learned that work finished in a thread it followed. Lost read authority
was noticed only lazily, when delivery next found a pending notification, so a
subscription whose owner had lost access stayed `active` indefinitely and was
indistinguishable from a deliberate subscription. The approved artifacts and
thread-tool plan asked for a `turn_finished` feed event appended by an Oban job
enqueued in the turn-finish transaction, and a revocation job enqueued in the
grant-revocation or team-change transaction (plan §2 and §8b, authorized by the
user's instruction to implement the entire plan).

## Decision

The notification feed gains a `turn_finished` kind. Finishing an ordinary turn
of a top-level agent thread (in `TurnCoordinator.finish/3` or when a queued
turn fails) inserts `Marshall.Threads.FeedAppendJob` in the same transaction,
unique on agent thread and turn. The job appends one content-free notification
(turn ID and closed outcome) to the bound user thread under the feed's advisory
lock with the next dense sequence (`Marshall.Agents.ThreadFeed`, now shared with
board cleanup). It re-checks for an existing notification of that turn, so
retries and duplicates append nothing. Maintenance turns, including
subscription-notification turns, and child threads are never announced, so two
mutually subscribed threads cannot wake each other indefinitely.

Subscriptions gain a `revoked` state (`active | inactive -> revoked`). Thread
grant changes, team-membership changes (including SCIM cleanup) and account
retirement insert `Marshall.Threads.SubscriptionRevokeJob` in their own
transaction, scoped to the user thread or to the affected account. The job
re-evaluates current Cedar read under the user-thread lock for each
non-revoked subscription in bounded pages, revokes only those whose owner lost
read, deactivates their receivers and records one
`thread_subscription_revoked` agent audit row each. A later authorized
`subscribe` may leave `revoked`; subscribe, replay and delivery still recheck
authority themselves, so revocation is recorded state, not the only guard.

## Alternatives

Keeping only lazy deactivation at delivery leaves revoked subscriptions marked
active and never records the loss. A separate feed table was rejected by
ADR-0255. Appending the feed notification after commit, best-effort, loses it
on a crash between commit and append. Announcing maintenance turns would let
notification turns trigger further notifications.

## Consequences

Subscribed agents receive a notification turn when followed work finishes.
Revoked subscriptions are visible and audited. Authority changes enqueue one
unique job per thread or account, so bursts collapse. Turn-finish transactions
insert one more Oban row for top-level threads.

## Invariants and verification

- A committed terminal ordinary turn yields exactly one `turn_finished`
  notification; maintenance and child turns yield none.
- After review, a subscription is `revoked` exactly when its owner lacks current
  read; each revocation has one audit row; revoked subscriptions cannot replay.
- Feed sequences stay dense under duplicate and crashed job runs.

Evidence: `feed_jobs_test.exs` (unit and Hegel model over grant, team and
subscribe histories), `oban_idempotency_property_test.exs` (runs, rollbacks and
duplicate enqueues) and `thread_tool_property_test.exs` (visibility and replay).

## Implementation evidence

- [FeedAppendJob](../../../marshall/lib/marshall/threads/feed_append_job.ex),
  [ThreadFeed](../../../marshall/lib/marshall/agents/thread_feed.ex) and the
  [turn coordinator](../../../marshall/lib/marshall/agents/turn_coordinator.ex).
- [SubscriptionRevokeJob](../../../marshall/lib/marshall/threads/subscription_revoke_job.ex),
  [ThreadSubscription](../../../marshall/lib/marshall/agents/thread_subscription.ex)
  and the enqueue sites in [thread sharing](../../../marshall/lib/marshall/threads/sharing.ex),
  [team membership](../../../marshall/lib/marshall/teams/coordinator.ex),
  [SCIM team cleanup](../../../marshall/lib/marshall/scim/team_cleanup.ex) and
  [account retirement](../../../marshall/lib/marshall/accounts/account_lifecycle.ex).
- [Feed job tests](../../../marshall/test/marshall/threads/feed_jobs_test.exs) and
  [Oban idempotency property](../../../marshall/test/marshall/oban_idempotency_property_test.exs).

- [`thread-tool` machine test](../../../nix/verification/tests/machines/thread-tool/scenario.py):
  revoking a share revokes the member's subscription, deactivates its receivers
  and writes one audit row across the three-replica fleet (all 10 subtests
  passed on 2026-10-28, recorded in the
  [review](../reviews/2026-10-21-artifacts-and-thread-tool.md)).

Remaining gaps: no NixOS machine test yet delivers a `turn_finished`
notification turn to a subscribed agent; that path is BEAM-only.

## Open questions

Retention of feed notifications remains the open question recorded by ADR-0252.

## Related decisions

Extends [ADR-0252](0252-profile-boards-and-thread-subscriptions.md) and
[ADR-0255](0255-thread-lifecycle-and-server-tool-dispatch.md).
