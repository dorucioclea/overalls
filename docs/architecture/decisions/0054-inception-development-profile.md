# ADR-0054: Inception development profile

- ID: ADR-0054
- Date: 2026-09-18
- Status: superseded
- Implementation: partial
- Components: Marshall Compute, Lilly VM, protocol, Nix guest and deployment
- Supersedes: ADR-0052
- Superseded by: ADR-0064, ADR-0085

## Context

[ADR-0064](0064-customer-workspace-isolation.md) replaces Customer networking and
sharing policy while carrying forward all unrelated decisions below.

Developers need to run Overalls inside Overalls, including a local PostgreSQL,
Marshall and Lilly that can manage real Firecracker guests. The user approved
the implementation plan and selected `inception` as the profile identifier.
All users allowed to create VMs may select this profile. A separate developer
allowlist is not required.

## Decision

Carry forward ADR-0052 and its inherited decisions except the exhaustive list
of three profiles. Add Inception at 10.40.0.0/16 with the same slot reservations,
anti-spoofing, egress, address retention and direct guest isolation. Extend the
reserved VM UID/GID range through 1,262,142, retaining existing profile identities.

Use Firecracker at both levels. Schedule Inception only on hosts verified for
nested Firecracker execution; neither CPU flags alone nor a QEMU-based test
establishes this capability. The default and minimum shape is 16 vCPUs, 32 GiB RAM, a 64 GiB
ext4 root and one additional sparse 256 GiB disk. Inner Lilly uses a native ZFS
pool on the additional disk. These minima cover the fixed embedded service
budgets and inner VM slice; shrinking below them is refused. Admission accounts for both disks; their logical
capacity does not imply physical allocation or free-space credit.

The execution and VM record's `disk_bytes` continues to mean root capacity.
The immutable profile determines the additional drive; peers cannot select
drive names, paths or data-disk size. The shared disk-layout helper supplies
the exact logical total for reservations and the host's persistent drive list.

The reproducible Nix image contains pinned tools,
PostgreSQL, Marshall, Lilly and an ordinary inner guest image. Per-instance
bootstrap creates unique database passwords, application secrets, local TLS
identities and Lilly enrollment credentials. Bootstrap retries and restarts
preserve identities, database contents, source edits and both disks. Never format
unexpected existing storage or replace developer edits during automatic startup.
The source-delivery portion of this decision is amended by
[ADR-0256](0256-inception-development-checkout.md): first boot clones the
canonical Overalls repository into the durable workspace instead of bundling a
source snapshot in the image.

Only SMTP credentials are shared between instances. Deliver an operator-managed
Inception SMTP bundle at runtime over a private placement-bound channel, never
in the immutable image, Nix store, execution record, process arguments or logs.
Guest administrators can read those shared credentials; the user explicitly
authorized that trust boundary for all VM creators. Support bundle refresh and
use current credentials on restart. Missing configuration is a visible setup
failure, not permission to substitute fixture mail or disable authentication.

Expose the profile only after its image, bootstrap, credentials and supported
placement path are connected. Preserve existing image choices for other
profiles. Keep Inception relocation unavailable until the multi-disk transfer
path is verified; [ADR-0072](0072-multi-disk-workload-transfer.md) accepted
that verified path on 2026-09-19 and lifted this exclusion for relocation,
evacuation and cloning. Its additional disk remains fixed at 256 GiB.

Acceptance requires one development layer creating ordinary inner guests, not
unbounded recursion. Inception-level Audi/Porsche deployment and browser ingress
are explicitly outside this change; the outer authenticated terminal remains
available for administration. Do not claim an inner browser URL is usable.

## Alternatives

An outer QEMU VM and a remote Lilly were rejected: Firecracker must run at both
levels. A prepared image requiring manual deployment was rejected in favor of
an automatically running stack. Shared internal credentials and captured fake
SMTP were rejected in favor of independent deployment identities and real mail.

## Consequences

The fourth profile changes protocol enums, local guest identity and native
network validation. The data disk requires owned multi-disk lifecycle and
capacity accounting. Deploy compatible consumers before enabling selection.
Nested execution expands the guest-visible virtualization surface and needs
explicit host eligibility and native acceptance. SMTP credentials are trusted
to every Inception guest administrator and must be scoped accordingly.

## Invariants and verification

- Preserve existing profile addresses and assign Inception slots injectively.
- Reject local accounts and subordinate ranges overlapping any VM identity.
- Test both disk accounting and sparse physical allocation; stop/start and
  provisioner restart must retain content, while fenced deletion removes both.
- Test interrupted bootstrap, substituted data disks and unique instance secrets.
- Create an outer guest through Marshall and use its running Marshall/Lilly to
  create, stop, restart and delete an ordinary inner Firecracker guest.
- Verify inner egress and isolation, including profile ranges overlapping the
  outer guest network. Do not infer isolation from nested boot alone.
- Exercise SMTP through fixtures and separately record real delivery acceptance.
- Run all changed application gates, native Nix checks and ADR validation.

## Implementation evidence

[Address allocation identities](../../../protocol/lib/overalls_protocol/address_pool.ex),
[guest identities](../../../lilly/lib/lilly/network/guest.ex) and
[UID reservation checks](../../../lilly/lib/lilly/host/uid_reservation.ex) now
recognize the fourth profile. The
[address property test](../../../protocol/test/address_pool_test.exs) and
[network identity property test](../../../lilly/test/network/identity_test.exs)
cover distinct identities across all four profiles.

[Shared disk layout](../../../protocol/lib/overalls_protocol/disk_layout.ex) now
defines the fixed data drive, and [reservations](../../../protocol/lib/overalls_protocol/vm_shape.ex)
include it. [Disk preparation](../../../lilly/lib/lilly/vm/disk.ex),
[jail mounts](../../../lilly/lib/lilly/vm/jail.ex) and
[owned ZFS lifecycle](../../../lilly/lib/lilly/host/zfs_dataset.ex) now handle
the additional file without changing root-size semantics. The
[native storage scenario](../../../nix/verification/tests/machines/zfs-guest/driver.py) includes
sparse allocation, restart, missing-disk refusal and cleanup. The expanded native
check passed before SMTP integration; its updated fixture requires another run.
It exercises the ordinary image with the Inception disk layout, independently
of the new application's bootstrap. Unit checks do not establish native storage
durability.

The [public profile policy](../../../marshall/lib/marshall/compute/profiles.ex)
binds the configured image, minimum service budget and native host proof. The
[creation form](../../../marshall/lib/marshall_web/live/machines_live.ex) and
[SSH creation action](../../../marshall/lib/marshall/ssh/commands.ex) select the
profile defaults. [Admission tests](../../../marshall/test/marshall/compute/inception_test.exs)
cover ordinary users, missing proof, exact image binding and both-disk reservation.

The [host preflight](../../../nix/domains/artifacts/guest/nesting-probe/host.py) runs a
trusted temporary Firecracker-in-Firecracker boot without networking or SMTP.
Its private receipt binds the current host boot, image, probe artifact and VMM.
[Eligibility](../../../lilly/lib/lilly/host/inception_proof.ex) also requires
currently enabled nesting and valid private SMTP configuration. The native check
passed the real probe and rejected tampered receipt fields. This is single-host
AMD evidence, not Intel or fleet-wide qualification.

The [Inception image](../../../nix/domains/artifacts/guest/inception/default.nix) builds
successfully with PostgreSQL, tools and both application releases; ADR-0256
records the first-boot source checkout.
[Bootstrap preparation](../../../nix/domains/artifacts/guest/inception/prepare.py) and
[runtime identity tests](../../../nix/verification/tests/evaluation/inception-runtime.py)
cover independent credentials and preserved workspace edits. The
[guest SMTP receiver](../../../nix/domains/artifacts/guest/inception/credentials.py) and
[host sender](../../../lilly/lib/lilly/vm/credentials.ex) use a private, boot-bound
vsock channel; local socket and runtime tests cover rejection and rotation.
The [execution coordinator](../../../lilly/lib/lilly/vm/executor.ex) requires
stack readiness before the first Inception running outcome. The basic
[native stack check](../../../nix/verification/tests/machines/inception/driver.py) passed
PostgreSQL/Marshall/Lilly readiness, native ZFS setup, retained enrollment and
source edits across stop/start, and deletion of both disks. The expanded check
for real outer admission and inner lifecycle is still in progress.

An exploratory local run booted NixOS under Firecracker 1.16.1 inside another
Firecracker guest on AMD. It used temporary disks and no production networking;
it establishes basic nesting on that host only. It is not application or fleet
acceptance. The bespoke application image has since passed its basic native lifecycle;
expanded nested lifecycle and network acceptance remain in progress. All three
application precommit gates passed: 98 protocol, 279 Lilly and 542 Marshall tests,
including their compiler, contract, ADR and Dialyzer checks.

## Open questions

Operational SMTP configuration and a real-delivery recipient must be supplied
for live acceptance. No further product decisions are pending.

## Related decisions

[ADR-0085](0085-inception-public-ingress.md) carries forward this profile and adds public ingress.

[ADR-0052](0052-fenced-local-guest-ingress.md),
[ADR-0035](0035-zfs-only-provisioning.md),
[ADR-0048](0048-single-host-service-deployment.md),
[ADR-0045](0045-declarative-lilly-enrollment.md),
[ADR-0040](0040-host-local-smtp-relay.md),
[ADR-0011](0011-nixos-guest-and-console.md).
