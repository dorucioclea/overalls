# ADR-0158: Durable guest identities independent of email

- ID: ADR-0158
- Date: 2026-10-10
- Status: superseded
- Implementation: partial
- Components: Marshall Accounts, SSH, terminal, Editor, Lyra, NixOS, Ubuntu, Arch and Alma guests
- Supersedes: ADR-0125, ADR-0148, ADR-0153
- Superseded by: ADR-0159

> Superseded by [ADR-0159](0159-remove-legacy-compatibility.md) only for inherited owner-less commands, the owner metadata endpoint and version-one roster bindings. ADR-0159 carries every other requirement of this record forward unchanged.

## Context

The email-derived guest names inherited by ADR-0125 couple mailbox changes to
Linux account retirement, a different UID and a different home. They also reject
otherwise valid email addresses because their local parts are unsuitable Linux
names. Browser editor origins already bind permanent GuestAccount UUIDs, but their
renewal additionally compares the current email local part.

After studying profile names and guest rename/restart alternatives, the user
selected immutable generated guest identities. This task authorizes the decision
and breaking development changes. It adds no user-selected username, profile
editor or onboarding step; Marshall continues displaying the email address.

## Decision

Replace the guest-name allocation and email-incarnation rules in ADR-0125,
ADR-0148 and ADR-0153. Carry forward their remaining authentication, retirement,
Cedar authorization, guest reconciliation, personal workspace and editor
requirements. Preserve the previous rationale and recorded evidence in those
records; their email-name behavior is historical.

Each User UUID receives a durable GuestAccount UUID and a globally unique,
noncycling UID in the existing range **200000 through 999999**. The generated
Linux login is exactly `u` followed by that UID in decimal; its home is exactly
`/home/u<uid>`. SSH, browser terminals, editor workers and both guest distributions
use this same stored identity. The guest UUID, UID, name and home remain unchanged
when the same User's email changes, including its local part or domain.

Retirement disables access and retains every guest identity reservation. A fresh
same-email registration has a different User UUID and acquires a fresh guest UUID
and UID/name/home; it inherits no old credentials, grants or guest identity.
Historical reservations and consumed sequence values must never be deleted,
reset or reassigned to recover allocation capacity. UID exhaustion refuses the
complete allocation transaction without retiring an existing identity.

Keep the bounded complete-batch allocator and canonical User-row locking. It
rechecks active stored User authority and reuses an existing active GuestAccount;
email is neither an allocation key nor an incarnation discriminator. PostgreSQL
constraints and the noncycling sequence remain durable authority. Discovery may
allocate before the user owns a VM, but grants no VM access.

Requests, invitations and verified-token sign-ins validate bounded ASCII mailbox
syntax independently of guest naming. Valid plus aliases, numeric-leading local
parts and local parts such as `root` are eligible mailbox identities. Malformed
mailboxes, header injection and unsupported input remain refused. The complete
case-insensitive email remains the login identity; email edits create no automatic
revocation exemption and introduce no public email-editing API.

Editor login, credentials and leases retain the exact GuestAccount UUID and
current User/login/write/execution authority. An email edit alone does not retire
that account, change its origin or refuse its renewable lease. Retirement,
revocation and changed execution or release bindings still refuse. Installer
configuration consumes the durable server-discovered name and never derives it
from email or a local operating-system username.

## Alternatives

Mutable Linux names require coordinated updates to running shells, offline and
shared machines, client SSH configuration and retained disks. Restarting every
affected machine also changes interruption authority for shared/team writers.
User-selected names add a distinct product capability that the user excluded
from this change. A mutable display handle with an immutable guest identity can
be decided separately later.

Email-local-part suffixes protect old homes but preserve the unwanted email
coupling and guest-name admission restriction. Per-machine identities would
complicate the existing global personal SSH/terminal/editor identity without a
requested benefit. Recycling UIDs or relying on email ownership after retirement
would allow retained guest files to attach to a different account.

## Consequences

Guest prompts and `whoami` display a generated name such as `u200001`; Marshall
account menus still display email. Same-user mailbox edits require no guest
rename, home move, reboot or client setup refresh. Authorized guest writers retain
passwordless sudo; separate UID/home allocation prevents accidental inheritance,
not confidentiality against another authorized sudo-capable writer.

This is a coordinated breaking development change. Updated Marshall and guest
images must agree on the generated identity. An existing writable disk is not
converted by publishing an image, updating a host or migrating PostgreSQL. Guests
with the old helper/accounts require updated compatible images or explicit
recreation. No retained-disk conversion or deployment has been performed.
Keep the original disk while copying and verifying selected data in a new guest
unless its deletion is separately authorized. The user subsequently authorized
deleting the four existing live guests as cutover preparation; the review records
their completed domain operations and native absence separately from migration
or deployment acceptance.
The database cutover canonicalizes current and retired rows without replacing
their UUIDs/UIDs or resetting the sequence. It retires surviving current rows of
already-deleted Users, removes the email-source column and closes old editor
leases without rewriting their immutable snapshots. Old client setup must be
refreshed to consume the generated login. Mixed old/new serving releases and
rollback to email-derived names are unsupported.

Restoring an older database alongside newer retained guest disks is unsupported
until guest UUID/UID reservations and the sequence are reconciled against all
retained state. Restored sequence state alone cannot establish that later UIDs
are unused. This decision adds no external reservation registry or automatic
historical-restore repair.

## Invariants and verification

- Same User UUID preserves the guest UUID, UID, generated name and home across
  local-part/domain/case email histories and repeated discovery.
- Fresh User UUIDs, including same-email replacement and different domains,
  receive distinct never-reused identities; retired authority stays refused.
- Allocation batches retain their size bound, sorted User locks, atomic refusal,
  sequence-exhaustion behavior and independent-Marshall concurrency checks.
- Mailbox validation accepts safe syntax without interpreting a Linux name;
  malformed input, stale links and header injection still refuse before authority.
- Editor origin, cookie and lease continuity survive a same-user email edit while
  retirement, stale login, cross-account, execution and release refusals persist.
- Real NixOS and Ubuntu Firecracker SSH/browser journeys must establish the
  generated login, exact home, UID ownership, restart/clone/relocation continuity
  and retirement isolation. Database/unit checks do not prove these boundaries.
- Migration must preserve retained guest UUID/UID reservations and a sequence
  above all retained allocations. It must not claim old guest disks were converted.

## Implementation evidence

The [GuestAccount resource](../../../marshall/lib/marshall/accounts/guest_account.ex),
[allocator](../../../marshall/lib/marshall/accounts/guest_accounts.ex) and
[mailbox validator](../../../marshall/lib/marshall/accounts/eligible_email.ex)
are the implementation boundaries for this change. Existing
[SSH discovery](../../../marshall/lib/marshall/ssh/commands.ex),
[personal terminals](../../../marshall/lib/marshall/terminal/authority.ex),
[Editor authority](../../../marshall/lib/marshall/editor/authority.ex) and
[guest helper](../../../lyra/src/bin/overalls-ssh-authorize.rs) consume the durable
identity. The [editor broker](../../../nix/domains/artifacts/vscode-web-broker/src/main.rs)
checks its exact UID/name/home before worker launch.
The [cutover migration](../../../marshall/priv/repo/migrations/20261010110000_durable_guest_identities.exs)
preserves UUID/UID reservations and the sequence, canonicalizes database names,
removes the source column and closes pre-cutover leases. This is database evidence,
not a guest-disk conversion.

The [review](../reviews/2026-10-10-durable-guest-identities.md) records evidence
from base `63a1443c` plus the durable feature, before stopped-only relocation and
incoming editor-package integration. It records the full
Marshall gate, **1,421 checks including 235 properties**, zero-error forced
Dialyzer, populated migration/schema agreement and structural contract checks.
Complete real NixOS and Ubuntu generated-identity lifecycle journeys passed,
including live-stream retirement, fresh same-email isolation, physical owned
cleanup, shared storage/process retention, reserved old homes, explicit fresh
sharing and packaged Lyra discovery/home. The complete NixOS SSH journey and
Ubuntu email-continuity subtest passed unchanged identity/home/client setup;
Ubuntu's run later failed its agent-authentication matrix. Editor authority email
continuity passed at the application/database boundary, while current native
editor runs remain partial. The scenario ledger (`marshall/priv/hldd/scenarios`, removed by ADR-0263)
retains each assertion and execution scope. Separately authorized live preparation
on 2026-10-10 completed deletion of all four scoped guests through normal lifecycle
authority, released their holds and confirmed native service/dataset absence on
both provisioners. This does not establish the identity migration or deployment.
Implementation stays partial for
the remaining complete Ubuntu SSH and native editor acceptance; no deployment,
retained-disk conversion or historical-restore repair is claimed.
Incoming ADR-0155 relocation and editor package results retain their own source
and execution scopes. A separate capture after integration with incoming
`d4499c4c` passed Protocol **259 checks**, Lilly **555 checks** and Marshall
**1,429 checks including 236 properties**, with zero-error forced Dialyzer in
each component. Both merged eight-subtest generated-identity lifecycle journeys
passed: NixOS **438.33 seconds**, Ubuntu **574.18 seconds**. This does not establish
later browser-launcher/shared-observability integration or the remaining complete
Ubuntu SSH/editor boundaries. Native unit inventory passed in 8.22 seconds within
a failed complete native-zfs run; unrelated resource-tuning receipt acceptance
and complete Runtime startup fencing remain separate gaps.

The [foreign Linux editor review](../reviews/2026-10-18-foreign-linux-browser-editor.md)
applies the existing personal editor identity and immutable release boundaries
to Arch and AlmaLinux. Their earlier CLI lifecycle passes do not establish
editor support. New image packaging and native browser acceptance are recorded
separately: Alma passed all twelve isolated native browser subtests, both new
production images passed complete CLI lifecycles, and Arch's captured diagnostic
replay passed all twelve stages. Its earlier broker-restart 502 remains unexplained.
Retained guest
disks receive no manifest or identity conversion; implementation stays partial.

## Open questions

Complete Ubuntu SSH/agent/relocation/reboot/clone acceptance, complete current
editor recovery and native editor email continuity remain unverified. Both guest
families' generated-identity retirement journeys are recorded as passing.
Historical restore reconciliation remains an explicit unsupported boundary;
production rollout and retained guest conversion are outside this task.
No profile username capability is introduced.

The combined release also includes ADR-0157 source2/manifest4 and the shared
observability library. Source capability for a retained start does not establish
that its old writable disk satisfies this generated-identity cutover. Prior
feature, `d4499c4c` and incoming browser-feature native captures remain separate;
latest combined component and generated-identity lifecycle execution is pending.

## Related decisions

[ADR-0066](0066-account-retirement.md),
[ADR-0157](0157-multi-provider-authenticated-repository-launch.md),
[ADR-0110](0110-cedar-guest-ssh-accounts.md),
[ADR-0115](0115-ssh-roster-boot-authority.md),
[ADR-0117](0117-personal-terminal-machine-workspace.md),
[ADR-0123](0123-remembered-browser-authority.md).
