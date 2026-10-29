# Durable guest identity review — 2026-10-10

## Scope and decision

The authorized development change replaces email-derived Linux guest identities
with immutable `u<uid>` logins and `/home/u<uid>` homes. User UUID, GuestAccount
UUID and noncycling UID allocation remain durable authority. The same User's
email edit preserves its guest account; a fresh same-email User UUID acquires a
new identity. No user-selected username, profile page, onboarding or guest-disk
conversion is introduced. Deployment has not occurred. The user subsequently
gave separate explicit authorization to delete the four existing live guests as
cutover preparation; the execution scope below distinguishes that maintenance
from the feature's disposable acceptance tests and identity migration.

[ADR-0158](../decisions/0158-durable-guest-identities.md) replaces the affected
clauses in ADR-0125/0148/0153 and carries their remaining requirements forward.
ADR-0066's retirement/physical-cleanup boundary is unchanged. The old records keep
their rationale and historical native evidence. This is an architecture-impacting
change to identity persistence, mailbox admission and editor renewal semantics.

The feature evidence below applies to base
`63a1443cf490312df50b3a43af55d92fd7afc263` plus the durable-identity changes
subsequently committed as `f1bd0e05`. It precedes integration with incoming
`d4499c4c`, whose stopped-only relocation and editor package changes have their
own captured records. Those records do not establish this combined tree, and
neither explains the other snapshot's failed native stages.

## Findings and disposition

| Finding | Evidence and consequence | Disposition |
| --- | --- | --- |
| Email controls guest incarnation | `GuestAccounts` previously compared the current mailbox local part and retired the guest account on a local-part change. Existing homes and SSH setup consequently changed. | Replace email sourcing with the immutable User-to-GuestAccount allocation under ADR-0158. |
| Valid email syntax was restricted by Linux naming | `EligibleEmail` previously called `GuestUsername.from_email`; valid plus aliases, numeric-leading names and `root` local parts refused sign-in. | Keep bounded mailbox validation while deriving guest names only from allocated UIDs. |
| Editor had a separate email fence | `Editor.Authority.current_account!` previously checked today's local part against the account source, independently of allocation. | Retain current User, GuestAccount, login/write and execution fences; remove email as an incarnation discriminator. |
| Old guest disks are outside database migration | Guest reconciliation and editor broker consume the identity already present in the writable guest filesystem. Publishing a new image does not replace that disk. | Document a coordinated breaking release and compatible-image/recreation requirement; the migration performs no conversion or disk deletion. Separately authorized live deletion is recorded below. |
| Historical restore can regress reservations | A restored database/sequence can omit later allocations whose files still exist on retained disks. | Historical restore remains unsupported until reservations/sequence reconcile with retained state. No new registry or automatic repair is claimed. |

These are authorized decision changes, not justification for weakening existing
retirement, Cedar, boot-fencing or storage-custody requirements. Generated names
do not create a confidentiality boundary between sudo-capable writers.

## Evidence and checks

Source review covers the Accounts allocator/resource/mailbox boundary, SSH
discovery and roster, browser personal terminal allocation, Editor identity and
renewal, Lyra helper and guest editor broker. Tests are classified in the
scenario ledger (`marshall/priv/hldd/scenarios`, removed by ADR-0263); present fixtures
are not recorded native execution.

The pinned development runtime and disposable PostgreSQL test partition recorded
focused passing reruns on this worktree:

- `guest_accounts_test.exs`, `guest_identity_bounds_test.exs` and
  `personal_session_test.exs`: **12 checks passed (2 properties, 10 tests)**,
  seed `896760`, 2.6 seconds. This establishes generated same-User email histories,
  permanent reservation/refusal and personal terminal identity behavior at the
  database boundary.
- `editor_test.exs`, `guest_identity_distributed_test.exs` and
  `guest_roster_distributed_test.exs`, with `--include distributed`:
  **28 checks passed (1 property, 27 tests)**, seed `453719`, 19.0 seconds.
  Editor approval/exchange and existing credential/open/renewal preserve the
  account binding across email edits. Three independent local BEAMs and Repo
  pools retain allocation/retirement and roster lock/fence behavior; this does
  not establish independent physical-host availability.
- `guest_identity_canonical_migration_test.exs`, with warnings as errors:
  **1 migration test passed**, seed `205307`, 3.6 seconds. The populated real
  forward chain preserves conflicting-name histories, UUIDs/UIDs, timestamps,
  audit payloads and advanced sequence state, retires deleted-User current
  accounts and closes only old open editor leases without rewriting bindings.
  All foreign keys and constraints remain enabled; no guest disk is converted.
- `account_lifecycle_test.exs` and `ingress/sessions_test.exs`:
  **26 tests passed**, seed `167260`, 14.7 seconds. A real team-owner refusal
  after guest retirement begins rolls back its marker and audit, User state and
  deletion receipt. Existing SSH leases and key eligibility retain exact durable
  identity after an email edit, while actual key revocation still refuses access.

The complete Marshall `mix precommit` passed: **1,421 checks passed (235 properties,
1,186 tests)**, two exclusions, seed `916619`; ExUnit took 2009.4 seconds. Both
frontend suites passed, and forced Dialyzer reported **zero errors, zero skips and
zero unnecessary skips**, in 41.32 seconds. This includes the changed mailbox,
allocator, retirement, SSH, terminal and editor tests and independent local BEAM
schedules. The local execution record is `.devenv/durable-precommit.log`.

The final all-domain `ash_postgres.generate_migrations --check` passed after
regenerating the GuestAccount snapshot with the official `--snapshots-only` file
serializer. The initial direct JSON projection omitted reference metadata and
typed identity-key representation; the corrected snapshot preserves the existing
schema decision and introduces no further migration or production code change.
`mix contracts.check` and its **19 validator regression checks passed** in
`.devenv/durable-schema-contract-final.log`; contract extraction is structural
evidence rather than semantic proof.

ADR structure/local links, scenario validation/regeneration, source-derived Ash
and deployment views, generated option references and reviewed HLDD receipts
passed at earlier source checkpoints. Final local ADR structure/link,
coverage/regeneration, Ash/deployment-view and generated option-reference checks
also passed after both native results were recorded. The final all-files `prek`
static gate passed, including conflict markers, reviewed Events catalogs, HLDD
receipts, Ruff formatting/linting and `ty`; its local execution record is
`.devenv/durable-final-gates.log`. The corrected
NixOS pinned driver and both final witness composed drivers passed typing/linting.
The final logs are `.devenv/durable-lifecycle-witness-nixos-driver.log` and
`.devenv/durable-lifecycle-witness-ubuntu-driver.log`; their driver derivations are
`n11l3r34vbvm162f1q2caz84w7n4idxi` and `41vhh6p6n2syl2lphkb8n7avqkcar5wl`.
Pinned Ruff formatting/linting and whole-repo contract
format/discovery/enforcement also passed. The evaluated Nix `hldd` gate passed
with output `gydcaqq3hmjs64nl0bwqi1dh13la1f8i-overalls-hldd-check`; its local
execution record is `.devenv/durable-hldd-final.log`. Four additional
composed Nix driver checks passed for team resources, sharing surfaces, SSH
bootstrap and installer trust. Composition/type checks do not run their machines
or prove guest isolation.

## Current native execution

**Complete NixOS SSH journey passed** serially, with test-script completion in
894.52 seconds and normal cleanup. The immutable Nix output is
`ji1p3iqww4b8cg961bdwhwns6ll264rw`; its local execution log is
`.devenv/durable-native-ssh-nixos-serial.log`. Authenticated Porsche discovery,
client setup, CLI and browser personal shells checked the canonical login/home.
The same-User email-change subtest passed in **14.37 seconds**, preserving
GuestAccount UUID/UID/name, marker numeric ownership, the running guest boot, VM
fences and unchanged SSH configuration after real roster refresh. Key
revocation/re-registration, quoted/variable/token/relative agent forms,
certificate renewal, relocation, reboot and cloning also completed.

The **Ubuntu email-continuity subtest passed in 31.19 seconds** in
`.devenv/durable-native-execution.log`, including canonical shell/home and the
same account/configuration/boot checks. That Ubuntu SSH run later failed public-key
authentication in the environment-variable `IdentityAgent` case. It establishes
the completed identity subtest, not a full Ubuntu SSH journey or its later
relocation/reboot/clone stages.

The NixOS editor run in `.devenv/durable-native-editor.log` completed browser
provisioning/canonical-account checks, personal editor/terminal and isolated
webview, guest policy/defaults/direnv, broker restart and editor-worker recovery.
It physically stopped and restarted the VM, then failed a browser edit assertion;
the complete stop/start recovery subtest did not pass. The Ubuntu editor run
stopped at `Real profile guest failed to start` during browser provisioning before
personal editor login. These are current partial results. No separate baseline
execution establishes the cause of either failure, and no native editor
email-change continuity is claimed.

## Lifecycle fixture and execution

The first NixOS and Ubuntu lifecycle attempts stopped during setup with a browser
Customer-create timeout and an `insufficient_capacity` refusal; neither completed
the generated-identity acceptance journey. The revised disposable fixture now
waits for real enabled/execution-ready host and pool reports less than five seconds
old before Customer creation. Other fixture provisions retry only the exact closed
capacity refusal, with the same request key and a bounded deadline. Accepted or
unknown outcomes are not retried, and the fixture does not write capacity,
readiness, telemetry or reservations. These helpers preserve admission authority;
initial creations require both provisioners, while fresh replacement creation
requires one live provisioner during the deliberate owned-host outage. The helper
accepts only those one/two-host requirements.

The next serial NixOS and Ubuntu lifecycle attempts passed canonical guest
identity/home setup but stopped before retirement: the owned and shared guests
were co-located, so deliberately stopping the owned provisioner also prevented
the intended shared live-stream setup. The corrected
`separate_shared_guest` fixture uses the authorized public relocation action,
waits for terminal `complete` plus `finished_at`, running state and the exact
destination placement, and asserts distinct hosts before recording shared
GUID/PID witnesses or injecting the owned-host fault. Native host enrollment now
includes the actual canonical `eth2` IPv4 listener and validated Ed25519 public
key after its transfer service starts, then checks exact persisted endpoint
equality. These fixtures do not forge placement, workflow state, transfer
authority, capacity or readiness.

The subsequent pinned NixOS attempt in
`.devenv/durable-native-lifecycle-nixos-pinned.log` completed canonical identity
setup and browser retirement. The already-open invited guest stream's close wait
completed in **0.098 seconds after the browser reported retirement**, with
successful client-unit completion rather than its timeout. The running shared
guest reconciled the retired account's
shadow expiry and removed sudo authority while retaining old UID home ownership.
The **fresh same-email/no-inheritance subtest passed in 53.88 seconds**: a fresh
User UUID received another canonical login/UID, inherited no roles, keys,
passkeys, grants, team membership or machines, and opened its own real SSH and
browser terminal home without the retired marker while old cleanup remained
pinned. The next subtest completed resize, old-User cleanup, owned VM archival,
hold release and physical owned dataset/service absence, and checked the shared
VM remained owned by the survivor, running and nonarchived. It then failed the
existing assertion that the shared VM's total lifetime delete count was zero:
the newly authorized setup relocation legitimately creates deletion intent for
its former source placement. The later shared GUID/PID, explicit fresh re-sharing
and packaged managed-SSH stages were not reached; no complete lifecycle pass is
claimed.

The final `assert_no_shared_retirement_deletion` oracle captures the whole-VM
delete count after setup relocation completes, before retirement. It requires
that total to remain unchanged and independently requires zero delete operations
for the retained current placement. It includes all historical setup cleanup
rather than excluding rows, and retains the subsequent GUID/PID, storage, fresh-VM
and home/refusal checks. Independent source review found no weakened retirement
boundary. Both witness composed drivers passed pinned typing/linting.

**Complete NixOS generated-identity lifecycle passed in 484.07 seconds**, followed
by normal cleanup in 3.41 seconds and process exit zero. The captured root is
`brqhh2rdzgwl3is858irl3k30mki1fwv`, with output
`d5x6pp5y3dh5cx4c50g8a6v9ynjmc0kh`; the local execution record is
`.devenv/durable-native-lifecycle-nixos-witness.log`. The stream-close wait
completed in **0.086 seconds after the browser reported retirement**; this is
not a measured database-commit-to-close latency. Fresh same-email/no-inheritance
passed in 52.32 seconds, resize/owned physical reclamation plus retained shared
GUID/PID in 39.17 seconds, and reserved old-home/explicit fresh re-sharing in
10.04 seconds. The latter verified old numeric home ownership and marker,
retired-account expiry/no sudo policy, old/fresh unshared refusal, a fresh home
without inherited files after explicit sharing, and refusal of the old login for
that fresh actor. Packaged Lyra configuration then installed the newly discovered
canonical identity and reached its home in 6.71 seconds. The final oracle proved
no added whole-VM deletion intent and zero retained-current-placement deletes.
**Complete Ubuntu generated-identity lifecycle passed in 541.14 seconds**,
followed by normal cleanup in 3.43 seconds and process exit zero. Its captured
root is `zjz1n7pkf7kq2c08jl1ldc4286laxnj3`, output
`mm3vsz0ykil0hxmlm8xql2k7lhs7pi3f`, with execution record
`.devenv/durable-native-lifecycle-ubuntu-witness.log`. The same real generated
identity/retirement/storage/home/refusal/managed-client assertions passed. Its
post-browser-retirement stream-close wait was **0.075 seconds**, fresh
same-email/no inheritance took 41.79 seconds, resize/reclamation/shared retention
99.06 seconds, old-home reservation and explicit re-sharing 9.20 seconds, and
packaged Lyra setup/home 4.01 seconds. **Both generated-identity lifecycle journeys passed**.
Both guest-family results establish these
disposable nested-KVM/ZFS journeys, not deployment or independent physical-host
availability.

Final all-files static and evaluated Nix handbook gates passed. Passing both lifecycle journeys
does not establish the complete Ubuntu SSH/agent matrix, native editor email
continuity or the retained-disk/restore cutover. No
deployment or retained-disk conversion was performed. Historical ADR-0125 native
results retain their original email-derived scope.

## Separately authorized live cutover preparation

On **2026-10-10 at 15:59:26 UTC**, trusted root maintenance on Overalls admitted
the four explicitly authorized live guest deletions through the deployed
release's public `Marshall.Compute.lifecycle` action. A fresh inventory had to
match the reviewed VM, actual owner, placement and profile scope exactly. Each
request used a freshly loaded current stored owner as the domain actor and its
own stable request UUID. A standalone release `eval` used operator mode to keep
normal persistence, authorization and job insertion available while preventing
another listener or queue consumer; the serving release executed the accepted
operations. No authorization was disabled, no elevated User authority was
fabricated and no lifecycle or reservation ledger was directly rewritten.

The domain requests are attributed to the actual stored owners. Separate
operator-initiation evidence records `ghuntley` and the durable-identity-cutover
maintenance purpose; these were root-initiated maintenance requests, not owner
browser actions. The local admission record is
`.devenv/durable-live-cutover-admission.log`. Admission establishes accepted
intent, not physical cleanup.

By approximately **16:01 UTC**, all four operations were completed, each VM had
desired and observed state `deleted` and was archived, every compute/disk/startup
hold was false, temporary allocation was zero and no nonarchived VMs remained.
The local database completion record is
`.devenv/durable-live-cutover-completion.log`. Subsequent native inventory
inspection found no `lilly-vm-*` services or `vm-*` datasets on either Overalls or
Dungarees; service/cache/template inventory remained retained. This records
completed, separately authorized live deletion only. No feature deployment,
identity database migration, retained-disk conversion or historical-restore
reconciliation has occurred, and no broader scenario acceptance is inferred.

## Feature semantic assessment before main integration

The source and contract review of base `63a1443c` plus the durable feature
reconciled the active-User/sorted-lock
allocator, permanent UUID/UID constraints, transactional retirement, current
SSH/terminal/editor authority and immutable editor bindings with ADR-0158.
Mailbox validation no longer interprets a Linux name; login/key/write/boot and
release refusals remain enforced. The populated forward migration preserves
reservations, sequence, timestamps and audit/lease snapshots while closing old
leases, and the official Ash snapshot agrees with that schema. That feature diff
changed no Lilly, protocol or guest service production code. Native admission, transfer,
relocation and deletion fixtures observe actual authority and compare both
whole-VM and retained-placement deletion intent without synthetic readiness.
The inspected durable-feature diff had no unresolved implementation or
code-contract defect. This conclusion does not cover later incoming source.
This assessment is separate from structural contract extraction and the
explicit uncompleted acceptance below.

## Main integration review

Integration preserves accepted/partial ADR-0155 and ADR-0158 separately. Current
relocation uses one stopped full copy with fresh probe-gated stop for running
guests, one destination disk reservation, no temporary headroom, current fenced
handoff and destination readiness before source cleanup. Permanent guest
UUID/UID/name/home reservations and same-User email continuity remain the
durable-identity design; relocation does not derive or rename those identities.
The merged scenario ledger retains both decisions and exact historical package,
standalone, Firecracker family and feature execution scopes.

Source-to-handbook review identified obsolete pre-copy conditional text in the
evacuation downtime confirmation and a SnapshotIndex contract still requiring
removed temporary headroom. The confirmation now describes stopping, copying and
restarting every running workload; the snapshot contract and adjacent export
lineage wording match stopped-only admission. These corrections preserve the
accepted decision and do not establish new native execution.

The same review found that removal of a retired legacy `lilly-a` tombstone
could rewrite a v2 SnapshotSet envelope without retaining its original bytes.
The correction validates its resource/payload under the live pool lock, archives
exact v2 bytes before the same-state transition and refuses an unsafe or different
existing archive; v1 retains loader archival. Added regressions inspect both
envelope versions, identity/state/binding preservation, revision advance,
unchanged retry bytes, no snapshot expectations and conflict refusal. Both
regressions passed in the merged Lilly gate below; unsafe-archive refusal retains
source/callee review rather than a separately executed regression. No new native
migration execution is claimed. This fixes an implementation mismatch within
accepted ADR-0155.

The incoming `TransferJournalMigration` bounded-scan requirement remains a
documented implementation/contract gap: candidate discovery enumerates paths
and reads marker bytes before the 16,384 count check. The limit bounds rewrites,
not discovery; the [incoming integration review](2026-10-10-browser-editor.md)
and handbook storage chapter preserve it. No over-limit native acceptance or
automatic historical-restore repair is inferred. The merged execution below is
separate from the passing pre-integration evidence and incoming native captures.

The merged-source documentation checkpoint passed conflict-marker scanning
(**4,296 files**), ADR structure/local links (**154 decisions**), all seven
explicitly reviewed HLDD receipts/references, coverage regeneration/check, Ash
and evaluated deployment views, generated options and whitespace checks through
the pinned Elixir executable. No development shell or Nix build was started for
these checks; view/option checks performed their own read-only Nix evaluation.
These structural results do not establish the component/native execution below
or final all-files static and evaluated Nix `hldd` publication gates, which are
tracked separately at publication.

## Merged execution on incoming d4499c4c

The initial merged Lilly suite completed with one failure in an ambient-host
inventory assertion; its archive regressions and forced Dialyzer passed, but no
full pass is credited to that attempt. The assertion expected unknown resources without
creating them and correctly received `:ok` for the cleaned host's readable empty
inventory. Removing that invalid assertion leaves production Ownership and
Runtime fencing unchanged. The historical 24-check capture remains historical;
it establishes no controlled physical-inventory refusal. Runtime initialization
composition of inventory refusal into the
host-wide fence remains source-inspection evidence, separately scoped in the
[historical-authority review](2026-09-26-historical-authority-characterization.md).

The following captures cover feature `f1bd0e05` integrated with incoming
`d4499c4cdbb840e0097be6ebf6476ba3e95496db`, including the reviewed source and
fixture corrections above. They precede later incoming browser-launcher and
shared-observability integration and do not establish that later tree.

- **Merged Protocol gate passed 259 checks**: 100 properties and 159 tests,
  seed `770953`, ExUnit 412.1 seconds, with zero-error forced Dialyzer.
  Capture: `.devenv/durable-merged-protocol-precommit.log`.
- **Merged Lilly gate passed 555 checks**: 109 properties and 446 tests,
  seed `367395`, ExUnit 65.6 seconds; forced Dialyzer reported zero errors,
  skipped warnings and unnecessary skips. This includes the retired SnapshotSet
  v1/v2 exact-byte archive regressions. Capture:
  `.devenv/durable-merged-lilly-precommit-retry.log`.
- **Merged Marshall gate passed 1,429 checks**: 236 properties and 1,193 tests,
  two excluded, seed `204043`, ExUnit 1,483.5 seconds. Frontend/TypeScript gates
  passed; forced Dialyzer reported zero errors, skipped warnings and unnecessary
  skips in 53.79 seconds. The initial attempt stopped before tests because the
  disposable task cluster's `template1` was SQL_ASCII while the application
  requested UTF8. Correcting that task-cluster template required no source or
  production database change. Capture:
  `.devenv/durable-merged-marshall-precommit-retry.log`.

**Both merged generated-identity lifecycle journeys passed all eight subtests**:
NixOS in 438.33 seconds and Ubuntu in 574.18 seconds. Captures are
`.devenv/durable-merged-native-nixos.log` and
`.devenv/durable-merged-native-ubuntu.log`. Real authenticated admission,
retirement/live-stream closure, fresh same-email identity/no inheritance,
physical owned cleanup, retained shared storage/process/home, permanent old-home
reservation, explicit fresh re-sharing and packaged Lyra discovery/managed SSH
passed on each guest family. These lifecycle runs do not establish the complete
Ubuntu SSH/agent matrix or complete native editor acceptance.

The initial merged `native-zfs` build failed **before VM boot**, with 14 composed
driver `ty` diagnostics because `dict[str, object]` did not narrow nested or
numeric observation fields. The fixture repair validates structured byte counts,
optional quota and compression diagnostics before physical assertions, including
rejecting a raw `allocations` key before projecting the typed observation. The
test-only probe preserves actual local `logical_used_bytes` and
`compression_ratio`; the production wire encoder intentionally omits them and is
unchanged. Production Ownership and Runtime are unchanged. No native inventory
execution is credited to that failed build or source review. Initial capture:
`.devenv/durable-merged-native-zfs.log`.

The corrected rerun passed composed-driver lint/types and the real ZFS scenarios,
including the 400-dataset bounded response frame. **Native unit inventory passed
in 8.22 seconds**: 56 real sleeping systemd units/cgroups exceeded verbose
framing, compact ID-only inventory accepted, and an omitted live placement and
unknown child cgroup refused. This is inventory-helper evidence, without
Firecracker or complete Runtime initialization-fence acceptance.

The **complete native-zfs rerun failed, exit 1**, at the final unrelated
auto-update resource-tuning subtest. The unchanged fixture writes
`enrollment.json` as `{"storage": receipt}`, while
`resources.py`'s `storage_receipt` requires exactly `storage` and a string
`revision`; it raised `TypeError: invalid resource receipt` at line 317.
No resource-tuning repair or complete native suite pass is claimed. Capture:
`.devenv/durable-merged-native-zfs-retry.log`; VM derivation
`irlxdddgh2grabn43vrgia5dhg629944`, driver derivation
`ladd6rngv606mb40mkd7g5yagyz440p0`.

## Later incoming bee03919 integration

The next integration combines committed `0826666c` with incoming
`bee03919faef20135aff5a787f07045a6d0367f6`. Published ADR-0156 browser distribution
and ADR-0157 source2/authentication resume keep their numbers; the durable
decision becomes ADR-0158 without changing its accepted identity rationale.
Source2/manifest4 image capability and shared observability remain their own
boundaries. Repository launch binds the User/actor and current stored login;
neither launch nor the shared metric library derives or renames a guest account.
Current source eligibility for a retained start does not waive generated-identity
disk recreation or permanent reservation/history reconciliation requirements.

The incoming historical-fence test now uses deterministic unknown-unit/failed-scan
utility fixtures in a child BEAM, with child-only PATH. Its original focused
incoming unit capture stays separate from the d449 native inventory result and
unexecuted complete Runtime startup-fence composition. Incoming browser native
captures retain frozen feature scope and establish no latest combined acceptance.
The latest combined warnings-as-errors Marshall compile and all-domain Ash schema
agreement passed in `.devenv/durable-latest-compile-schema.log`. Full component
and generated-identity lifecycle reruns are still awaiting execution; prior
passing counts, durations and source scopes above remain unchanged.

## Remaining acceptance

The complete Ubuntu SSH journey,
complete editor recovery and native
editor email continuity remain gaps. Retained-disk conversion, reconciled
historical restore and deployment are separate unverified work.
