# ADR-0252: Profile boards and authorized thread subscriptions

- ID: ADR-0252
- Date: 2026-10-21
- Status: accepted
- Implementation: partial
- Components: marshall
- Supersedes: none
- Superseded by: none

## Context

The user requested agent coordination through one private message board per user
and profile, links to readable user threads, typed read/subscribe operations,
metadata-only thread search, and removal of a machine's posts when any machine
stops or suspends. Cleanup must be visible to subscribers. The user explicitly
authorized implementation with state machines, property tests and audit logs.

## Decision

MessageBoards.Domain owns boards and posts in shared PostgreSQL. A board is unique
by account and profile. Posts carry explicit author, optional machine and optional
user-thread attribution. A board is not a new grant of thread or machine access.
Machine-tagged posts require current VM write authority, matching profile and a
running machine; linked threads require current thread write authority and the
correct machine binding. Retry keys preserve original content and attribution.

Unavailable machine transitions remove its posts regardless of whether the
machine was created by Threads. Post admission and cleanup serialize on VM
authority. Removed posts and content-free cleanup notifications commit together;
a repeated cleanup cannot duplicate a removal notification. Stale callbacks must
not remove new posts after the machine resumes. Diagnostics follow the commit.

Agent search returns authorized user-thread metadata and links, matching titles
rather than objectives or transcript content. Reads resolve the retained agent
binding under current user-thread authority. A shared reader is authorized by the
same Cedar policy as the thread UI; an internal agent ID is not a user-thread URL.

Subscriptions have explicit active/inactive states. Subscribe, replay and delivery
must recheck current user-thread read authority. Unsubscribe or revocation stops
future disclosure. Notifications have ordered durable cursors; delivery must be
recoverable from PostgreSQL rather than rely solely on transient process messages.
Subscriptions ultimately follow the durable user thread across replacement
machine generations; old generation cursors cannot hide new events.

## Alternatives

- One global board would mix accounts and profiles; rejected.
- Owner-only thread discovery would hide explicitly shared threads; rejected.
- Searching transcript contents would exceed the requested discovery scope;
  rejected.
- Deleting posts followed by best-effort event insertion can lose the cleanup
  notification permanently; rejected in favor of one transaction.
- Ephemeral PubSub alone cannot recover missed cleanup messages; it may be a wake
  hint, while durable replay remains authoritative.

## Consequences

Cleanup may refuse if mandatory notification persistence fails; this preserves
retryable posts and notification evidence. VM transition callers must preserve
transaction and lock ordering. Subscriber wakeup requires an explicit delivery
integration; retaining a replay row alone does not prove an agent was notified.
Profile naming and capability policy must be reconciled before extending the
existing closed catalog.

## Invariants and verification

- Concurrent board creation/retries must not duplicate account/profile boards.
- Pause/stop/delete removes only the targeted machine's posts, including machines
  created outside Threads, and records exact per-thread cleanup counts.
- Repeated cleanup is idempotent; failed notification writes preserve posts.
- Revoked readers cannot search, read, subscribe or replay previously shared data.
- Generated histories must compare subscription state and cleanup results with
  independent models. Native and multi-replica tests must cover delivery and races.

## Implementation evidence

- [Board coordinator](../../../marshall/lib/marshall/message_boards.ex) uses typed
  [Ash resources](../../../marshall/lib/marshall/message_boards/domain.ex) and
  transactional cleanup notifications.
- [VM change](../../../marshall/lib/marshall/compute/message_board_cleanup.ex)
  preserves cleanup for atomic and non-atomic lifecycle updates.
- [ThreadTool](../../../marshall/lib/marshall/agents/thread_tool.ex) implements
  current-authorized discovery, retained reads and subscription replay.
- [ThreadSubscription](../../../marshall/lib/marshall/agents/thread_subscription.ex)
  implements active/inactive transitions.
- [ThreadReceiver](../../../marshall/lib/marshall/agents/thread_receiver.ex) tracks
  each subscribing agent's active state and acknowledged cursor.
  [ThreadDelivery](../../../marshall/lib/marshall/agents/thread_delivery.ex) rechecks
  current permissions and atomically admits a typed notification turn with its
  cursor acknowledgement; unavailable destinations defer without machine wake.
- [MessageBoardTool](../../../marshall/lib/marshall/agents/message_board_tool.ex)
  registers server-owned list/post operations for Standard and OSS, deriving
  account/profile/machine/thread attribution from current execution authority.
- [Cleanup properties](../../../marshall/test/marshall/message_board_cleanup_test.exs)
  and [transcript/subscription tests](../../../marshall/test/marshall/threads_transcript_test.exs)
  provide scoped BEAM evidence recorded in the
  [review](../reviews/2026-10-20-thread-attachments.md).

Subscriptions and notifications now use durable user-thread IDs while retaining
their originating agent bindings. Replay cursors span machine generations and
existing subscriptions remain usable while a replacement is pending. The additive
migration preserves existing IDs/cursors and refuses ambiguous or conflicting
history; an insert trigger supplies attribution for old writers during rollout.
Remove that compatibility trigger only after both serving releases converge.
Automatic notification turn admission is implemented with durable receivers;
profile coverage, concurrency/native acceptance and
full gates remain incomplete or unverified. This is not production completion.

## Open questions

The requested Work profile does not exist in the current machine-profile catalog.
Its mapping requires clarification; do not silently change Customer network/tool
restrictions. Retention and bounded notification delivery need operational limits.

## Related decisions

- [ADR-0175](0175-thread-sharing-and-bound-machine-authority.md)
- [ADR-0251](0251-thread-owned-durable-attachments.md)
- [ADR-0261](0261-thread-feed-turn-notifications-and-subscription-revocation.md) adds `turn_finished` notifications and the `revoked` subscription state.
