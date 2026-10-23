# ADR-0190: Native kernel provenance and fail-closed multi-OS admission

- ID: ADR-0190
- Date: 2026-10-17
- Status: accepted
- Implementation: partial
- Components: Nix guest builders, Protocol, Lilly, Lyra, Marshall, guest-images
- Supersedes: ADR-0180
- Superseded by: none

## Context

This decision replaces [ADR-0180](0180-multi-os-guest-image-contract.md). It
carries forward the foreign Linux families, native OS identities, firmware
metadata and shared Lilly boundaries, while replacing native capability
advertisement with kernel-provenance and recorded-runtime admission gates.
Stock FreeBSD 14.3 and OmniOS lack the required AF_VSOCK/virtio-vsock kernel
support, so their earlier advertised capability rows cannot establish support.

Overalls is expanding the Linux guest catalog beyond the standard NixOS and
Ubuntu images and is defining native non-Linux image contracts. The current
branch adds Arch Linux and AlmaLinux builders as foreign Linux variants. They
reuse the existing version-4 kernel image contract and carry deterministic
distribution markers so the two catalog entries have distinct identities.

The branch also extends the shared protocol for native FreeBSD and OmniOS
(represented by the `illumos` protocol family). Both use CloudHv firmware and
version-6 raw-GPT images; FreeBSD's published GPT disk contains the EFI system
partition and UFS root, while OmniOS carries its ZFS root. Pinned builders and
catalog entries now exist. FreeBSD 14.3 is fetched from a checksum-pinned
archive capture because the rolling `Latest` endpoint was retired. The native-kernel package keeps source receipts separate from experimental
outputs: the FreeBSD candidate now cross-builds a complete kernel, while the
illumos implementation includes a modern virtio backport and bounded socket
and transport sources. OmniOS candidate assembly removes an inherited standalone
`-s` from `/boot/transient.conf` while preserving the ZFS root, boot path and
console arguments; second boot rejects any remaining single-user argument.
Stock-image constructors still consume unavailable receipts and refuse before
copying a stock disk. The reviewed FreeBSD candidate now has exact
five-scenario native evidence and a separate immutable promotion path; unrelated
candidate builds and exploratory boots grant no admission. The current OmniOS
candidate has now satisfied the five exact-image service, growth, policy,
daemon-recovery and process-crash requirements. Its runtime receipts retain
`native_admission=false`; a separate immutable promotion and compiled registry
entry qualify that reviewed identity. The fleet aliases now select its exact
immutable promotion; unrelated candidates remain unadmitted. These records establish neither physical recovery,
broader isolation, reset stress nor fleet acceptance.

The existing NixOS, Ubuntu and Windows contracts must remain intact. OS names,
root formats, boot artifacts and agent capabilities must come from validated
protocol metadata. Lilly must not infer a guest family from a filename or
package contents, and Marshall must not grant a capability merely because an
image contains a tool.

The personal browser editor remains a version-4 Linux image capability under
ADR-0153. The version-5 Windows contract and version-6 native contracts do not
carry an editor descriptor or editor capability. Historical Linux package or
machine evidence does not establish the current source revision or a production
browser journey; those remain separately recorded acceptance obligations.

## Decision

1. **Foreign Linux variants retain the Linux contract.** Arch Linux and
   AlmaLinux use the existing version-4 kernel manifest and version-1 bundle
   shape, with the same Lilly kernel boot, guest agents and capability table as
   the standard Linux row. Their builders assemble distro-specific roots from
   pinned sources, add deterministic `arch` and `almalinux` identity markers
   and remain separate catalog entries.
2. **Native OS families use explicit version-6 metadata.** A version-6 FreeBSD
   manifest declares `os = freebsd`, firmware boot, virtio-pci, raw GPT root
   and `guest_agents = freebsd-v1`. A version-6 OmniOS/illumos manifest
   declares `os = illumos`, firmware boot, virtio-pci, raw GPT root and
   `guest_agents = illumos-v1`. Unknown OS values, cross-OS agent sets, extra
   keys and invalid artifact bounds are refused. Every native manifest carries
   a positive kernel byte count, SHA-256 digest, full source revision, patch
   hash, configuration hash and compiler identity. A source receipt or
   placeholder digest is not admission evidence.
3. **Bundle version 3 is closed.** Native FreeBSD and illumos firmware bundles
   carry the validated image ID, OS, matching agent set, kernel provenance and
   firmware size. Artifact file lists come from the protocol. Version-1 Linux
   and version-2 Windows firmware encodings remain byte-compatible.
4. **Capabilities stay explicit and fail closed.** The protocol's capability
   functions are the sole source for Lilly and Marshall. `freebsd-v1` and
   `illumos-v1` retain their OS-specific wire identities and host-only vsock
   transport shape. Their unqualified `capabilities/1` rows remain all false.
   `capabilities/2` may grant the reviewed native subset only when its agent
   set, image ID and complete normalized manifest or portable boot descriptor
   match the immutable native admission registry. Readiness, trust, terminal,
   workspace, flush, SSH and agent control are enabled for that exact image;
   editor and Inception remain false. The registry requires a cross-built
   kernel, complete agent closure and recorded native machine evidence.
   Unreviewed OmniOS candidates, retained stock images, changed descriptors and an image ID alone
   remain refused. `workspace_source_version = 2` alone grants no delivery.
   Reading the host's bounded serial boot log is a separately authorized
   diagnostic under [ADR-0083](0083-terminal-host-stream-and-registry.md), not
   a guest terminal capability or readiness claim. It may remain available for
   an exact current pending/failed boot even when guest capabilities are false.
5. **Lilly preserves shared boundaries.** Kernel bundles include an initrd only
   when the validated bundle declares one. Firmware bundles select the default
   CPU model for illumos and retain Hyper-V configuration only for Windows.
   Vsock is attached only when the agent set speaks the Lilly protocols. The
   jailer, seccomp observation, per-tap network guard, ZFS ownership and durable
   lifecycle remain shared boundaries.
6. **Evidence is scoped to what exists.** The Arch/Alma evaluation check proves
   builder command shape and distinct distribution markers only. Protocol tests
   and the Lilly jail test prove bounded metadata and the native firmware
   configuration only. The recorded native receipts prove only their named
   FreeBSD and OmniOS nested-KVM scenarios. The separate test-only FreeBSD
   fault-kernel receipt establishes FreeBSD kernel wrong-CID frame refusal and
   fencing under racing invalid resets only.
   They do not imply OmniOS wrong-CID refusal or reset safety, DMA safety, direct peer-VM or host isolation, physical durability,
   relocation or Marshall fleet acceptance.
7. **Native admission is boot-bound and fail closed.** Before credentials or
   readiness, Lilly requires an `attested` response from the jail-local probe
   matching the native OS, placement, execution epoch, boot challenge and
   manifest kernel digest, with a bounded boot ID. Missing, placeholder, stale
   or mismatched evidence refuses admission. The fixed host-only vsock path
   and bounded frames preserve the existing transport boundary. The later
   readiness response must carry the same boot ID as the kernel response.
8. **Native root growth precedes boot authority.** A root-only helper accepts
   no target argument and derives the actual mounted root. Before mutation it
   verifies both GPT copies, CRCs, pinned disk and partition identities, starts
   and physical capacity. FreeBSD preserves all nonroot entries while growing
   the UFS root; OmniOS additionally binds the assembly pool GUID and one
   whole-disk ZFS vdev, preserving the loader and reserved tail identity. Every
   boot requires a fresh volatile success receipt before identity or network
   bootstrap. Installation and pure parser tests do not establish native growth.
9. **Vendor initialization cannot share native authority.** OmniOS assembly
   disables all four stock cloud-init instances and stock SSH in the cloned
   root's offline SMF repository. Overalls MMDS bootstrap owns the static
   network and resolver, and its roster supervisor owns SSH startup. Fresh-boot
   verification must observe the vendor instances disabled and preserve exact
   installed payload bytes; a mutable resolver cannot bypass that verification.
   Native trust separately retains a recipe-pinned regular vendor CA snapshot
   for each boot's current host roots; the effective managed system path cannot
   become the next boot's vendor base. This preserves ADR-0113's replacement
   and root-removal semantics. Runtime file verification permits only the
   designated effective CA path to become a root-owned link into the fixed
   managed directory, with an exact vendor prefix and bounded public roots.
   Other payload hashes and modes remain exact; file structure alone does not
   establish current-boot trust authority.
10. **Promotion binds immutable artifacts and evidence.** A separate constructor
    verifies the exact native manifest/image ID, disk and firmware bytes, VMM
    digest, assembly receipt and all five service/growth/policy/daemon-recovery/
    SIGKILL-recovery evidence sets before publishing `manifest.json`. A manually
    assembled candidate enters Nix by a reviewed recursive NAR hash through the
    existing signature-verified cache; a cache miss refuses with publication
    instructions. Candidate constructors retain false admission flags. The
    published image contains only its declared artifacts and manifest, while
    the protocol registry independently controls runtime admission. This
    authorizes each reviewed immutable image without claiming reproducible
    native assembly, physical recovery or fleet rollout. The OmniOS identity
    recorded below now satisfies those existing promotion requirements;
    unrelated candidates remain closed.
11. **Editor admission remains Linux-only in this decision.** A version-4 Linux
    image may expose the personal browser editor only when its validated
    descriptor, package/broker release and existing ADR-0153 authority checks
    match. Version-5 Windows and version-6 FreeBSD/illumos manifests refuse an
    editor descriptor, and their agent rows remain editor-false. Terminal, SSH,
    workspace, native transport or workstation-client evidence cannot widen that
    capability. A future native or Windows editor requires a new reviewed image,
    agent/protocol contract, broker and browser acceptance record.

Authorization: the multi-OS guest-image implementation plan of 2026-10-16 and
the custom native-kernel plan of 2026-10-17, followed by the explicit instruction
to enable admission, continued by the autonomous implementation instruction of
2026-10-18. Activation is per reviewed immutable image; completing OmniOS's
existing exact service matrix authorizes its separate immutable promotion and
registry entry, without changing the admission rationale or capability subset.
The Windows decisions remain in [ADR-0169](0169-firmware-booted-windows-guests.md),
[ADR-0170](0170-lilly-firmware-guest-launch.md),
[ADR-0171](0171-windows-guest-agents.md) and
[ADR-0173](0173-windows-images-winget-desktop-experience.md).

## Alternatives

- **Infer the OS from a filename or package set.** Rejected because admission,
  artifact mounting and capability authorization would be ambiguous.
- **Give each new OS a separate Lilly lifecycle.** Rejected because it would
  duplicate fencing, ZFS ownership, network isolation and recovery logic.
- **Treat Arch/Alma as new protocol OS values now.** Rejected while their
  builders retain the Linux boot contract and only their root assembly and
  identity vary.
- **Claim native FreeBSD/OmniOS support from metadata alone.** Rejected because
  a manifest and unit test do not prove a boot, guest isolation or recovery.

## Consequences

- Arch and Alma can be built and cataloged through the established Linux path,
  while their identities remain distinct.
- Version-6 metadata and bundle version 3 provide a stable extension point for
  native FreeBSD and OmniOS without changing existing wire encodings.
- Native families add protocol, Lilly and Marshall branches. The reviewed
  FreeBSD image can enter the catalog through immutable artifact promotion.
  Reproducible native assembly and fleet rollout retain separate evidence gaps;
  neither is implied by the exact-image activation.
- The FreeBSD and illumos rows define a versioned transport contract only. The
  unqualified rows remain false. Callers must provide the complete validated
  identity to obtain the reviewed image's subset and must not treat an agent
  name, kernel digest or retained catalog row as authority. The implementation
  remains partial for the broader native and fleet requirements.
- The editor boundary is narrower than the guest-family boundary: Linux image
  packaging and historical browser evidence do not establish current-revision
  or production acceptance, while Windows, FreeBSD and illumos remain explicitly
  editor-false. No native or Windows editor implementation is accepted by this
  decision.

## Invariants and verification

- Version-4 Linux manifests and version-1 bundles remain byte-identical.
- Arch and Alma builder commands contain the reviewed version-4 kernel/root
  shape and their own deterministic distribution marker.
- Version-6 manifests and version-3 bundles reject unknown keys, OS/agent
  mismatches, malformed boot arguments, incomplete kernel provenance and
  out-of-bound artifact sizes.
- Kernel provenance binds every native image to positive kernel bytes, a
  digest, source revision, patch hash, configuration hash and compiler.
  Unavailable or placeholder kernel artifacts cannot enter image construction
  or native admission.
- Native FreeBSD and illumos firmware bundles retain the jail-local, host-only
  vsock transport shape; they never receive the Windows Hyper-V CPU template.
  If native capabilities are enabled in a later reviewed rollout, each daemon
  must bind host CID 2 to guest CID 3 and every response to the current boot
  before Lilly or Marshall grants the corresponding operation.
- Admission compares complete normalized identities, including the manifest's
  root and firmware descriptors or the portable descriptor's exact image ID.
  Missing, altered, foreign or unapproved native identities refuse before new
  Marshall allocation or Lilly launch effects. Linux and Windows keep their
  existing capability behavior.
- The current `foreign-linux-guests`, `native-os-guest-unit`, protocol
  validation, `Lilly.VM.JailTest` and `Lilly.Host.ImageTest` checks are
  structural evidence. Separate recorded FreeBSD execution covers the scoped
  transport, complete service, mounted-root growth, IPv4/router/TAP policy and
  same-boot daemon recovery boundaries described below. Exact OmniOS disk
  `45983bb7` separately binds all five service/growth/policy/daemon-recovery/
  process-crash scenario receipts and its own transport/reset evidence. These
  results do not establish broader capability acceptance, physical stable-media/
  power-loss durability, repeated reset/DMA safety, physical isolation or fleet
  availability.

## Implementation evidence

The [2026-10-18 OS matrix review](../reviews/2026-10-18-guest-os-matrix.md)
reconciles the seven declared families with seven source-selected catalog rows
and the opt-in explicit-image acceptance workflow. It records the exact OmniOS
immutable promotion, registry qualification and selected package aliases.
It now records all seven exact selected families' separately executed
create/readiness, strict CLI SSH, independent stopped checkpoints, same-VM
restart, repeated strict SSH and completed deletion. Its typed aggregate binds
49 stage receipts and four Arch/Alma read-only smoke receipts at their distinct
execution revisions; no simultaneous same-revision run is claimed. This closes
the scoped SSH/lifecycle milestone while this decision remains partially
implemented for the broader native/recovery/capability requirements below.

The implementation is partial. Arch and Alma builders are in
[`nix/domains/artifacts/guest/arch`](../../../nix/domains/artifacts/guest/arch),
[`nix/domains/artifacts/guest/alma`](../../../nix/domains/artifacts/guest/alma) and the shared
[`foreign-linux.nix`](../../../nix/domains/artifacts/guest/foreign-linux.nix), with the
[`foreign-linux-guests`](../../../nix/verification/tests/evaluation/foreign-linux-guests.nix)
evaluation and catalog entries in [`fleet/guest-images.nix`](../../../fleet/guest-images.nix).
The shared builder now preserves executable source modes, restores real
root-owned sticky temporary directories and selects the reviewed
`landlock,yama,bpf` guest LSM stack explicitly; these assembled roots do not
carry distro SELinux labels. Actual private-image offline checks and old-input
negative controls pass. Historical corrected-image create failures and later
helper-fixed runtime results remain distinct in the matrix review; host
isolation, wire contracts and capability authority are unchanged.
The exact Arch diagnosis additionally found vendor tmpfiles changed the mutable
root to 0555 at boot, refusing capability-free readiness writes. An Arch-only
higher-priority root policy preserves root 0755 without changing capabilities
or recursively changing ownership. Actual artifact checks and a pinned
tmpfiles/capability-free scratch execution pass; a fresh repaired-image
production lifecycle remains separate.
The private Alma image additionally carries the existing pinned resolver's
service, two sockets, D-Bus policy/activation and a scoped identity bootstrap.
That bootstrap runs only the exact resolver sysusers configuration before
sysinit/D-Bus/resolver startup, preserving vendor conditions and unrelated
accounts. Actual artifact, isolated sysusers and native unit-parser checks
pass; these do not establish a fresh guest boot or resolver/SSH readiness.

Later fresh Arch and Alma images reached readiness but refused personal SSH.
Arch's boot-bound probe isolated PAM account refusal and absent compiled
`/run/wrappers/bin/unix_chkpwd`. Alma shares that immutable helper omission;
its matching SSH symptom has no separate recorded PAM root probe. The shared builder now installs
only the pinned helper as a regular root-owned 04755 runtime copy before SSH;
its immutable source remains 0555. A root-only, argument-free installer refuses
unsafe parents or destinations. SSH requires successful helper installation.
The maintained isolated VM gate reproduces missing-helper status 9, succeeds
with status 0 on nosuid runtime storage, and preserves expired/password-change/
unknown-account refusals. Pinned PAM's root account caller sets real UID 0
before helper execution; no mount flags or unprivileged elevation are added.
Actual image and independent rebuild checks pass for Arch `99fa9876` and Alma
`473f9589`. Both exact images subsequently passed fresh strict personal-account
CLI SSH, read-only sudo/helper checks, independent stopped checkpoints, restart,
repeated strict SSH/checks and completed deletion in run `114223`. Runtime mounts
remained nosuid; these observations do not establish direct helper setuid
elevation, terminal/executor/workspace, revocation, isolation or physical recovery.
The matrix review binds exact artifacts, the VM fixture's source-ownership
overlay and independent lifecycle receipts.
This repairs the accepted owned PAM runtime without changing host isolation,
protocol identity, account policy or capability authority; implementation remains
partial.

The [cross-platform editor status review](../reviews/2026-10-18-cross-platform-editor-status.md)
records the current Linux evidence-freshness gap and the explicit native and
Windows blockers. It does not upgrade historical Linux browser records to the
current source revision or grant editor capability to another guest family.

Native builders and catalog entries are in
[`native.nix`](../../../nix/domains/artifacts/guest/native.nix),
[`freebsd/default.nix`](../../../nix/domains/artifacts/guest/freebsd/default.nix),
[`omnios/default.nix`](../../../nix/domains/artifacts/guest/omnios/default.nix),
and [`illumos/default.nix`](../../../nix/domains/artifacts/guest/illumos/default.nix),
[`native-os-guests.nix`](../../../nix/verification/tests/evaluation/native-os-guests.nix) and
[`fleet/guest-images.nix`](../../../fleet/guest-images.nix). The FreeBSD source
endpoint is retired and is replaced by an archived, checksum-pinned capture;
the explicit illumos constructor records `https://illumos.org/` as the upstream
project and uses OmniOS r151050 as its pinned downstream image because the
illumos project publishes source and documentation, not a canonical installable
guest image. The fleet's `OmniOS r151050` row consumes the explicit
`illumosGuest` constructor while retaining OmniOS as the display name. The
evaluation remains structural and records no native runtime acceptance.

Native metadata, bundle and kernel-attestation validation are in
[`image_manifest.ex`](../../../protocol/lib/overalls_protocol/image_manifest.ex),
[`workload_bundle.ex`](../../../protocol/lib/overalls_protocol/workload_bundle.ex),
[`kernel_attestation.ex`](../../../protocol/lib/overalls_protocol/kernel_attestation.ex)
and [`guest_agents.ex`](../../../protocol/lib/overalls_protocol/guest_agents.ex).
Lilly's conditional initrd, vsock and CPU configuration is in
[`jail.ex`](../../../lilly/lib/lilly/vm/jail.ex), with the focused
  [`jail_test.exs`](../../../lilly/test/vm/jail_test.exs) and source-artifact
  selection coverage in [`image_test.exs`](../../../lilly/test/host/image_test.exs).
  The latter verifies that manifest-declared `disk.raw` files
are selected as sources while Lilly retains its internal persistent destination
name; it does not realize an image or boot a guest.

The stock-input FreeBSD and OmniOS builders and
[`kernel receipts`](../../../nix/domains/artifacts/guest/native-kernels/default.nix)
evaluate in Nix, but the receipts mark kernel artifacts unavailable and image
builders stop before copying a stock disk. The protocol and Marshall projections
define the native rows and permit workspace source version 2; those declarations
alone prove only the versioned contract. Lilly's bounded kernel-attestation path and Lyra's source adapters
are covered by unit/type checks, while the FreeBSD candidate and native Lyra userland closure now link in Nix.
Separate target-native candidate assembly and scoped FreeBSD transport,
complete-service, growth, IPv4 policy and daemon-recovery execution have passed.
The exact source-qualified receipts are recorded in the
[review](../reviews/2026-10-17-native-kernel-attestation.md). The final reviewed
FreeBSD image also passed the scoped same-disk SIGKILL/recovery boundary. The
current source-qualified OmniOS image subsequently passed the complete native
service fixture over two clean boots, including current-boot identity, readiness,
trust, flush, workspace, terminal, SSH, executor fencing and retained-home checks.
Its receipt keeps admission false and explicitly excludes growth, network policy,
supervised daemon recovery, physical isolation and fleet admission. A separate
OmniOS crash receipt records same-disk restart after an observed Firecracker
SIGKILL, fresh MMDS/boot identity, stale-authority refusal, retained bytes and a
zero-error ZFS scrub; it does not establish physical recovery or admission. The
reviewed FreeBSD image has a separate
[promotion constructor](../../../nix/domains/artifacts/guest/native-promotion/freebsd.nix),
[artifact/evidence verifier](../../../nix/domains/artifacts/guest/native-promotion/verify.ex),
[reviewed manifest](../../../protocol/priv/native/freebsd-14.3.json) and
[runtime registry](../../../protocol/lib/overalls_protocol/native_admission.ex).
The [activation review](../reviews/2026-10-17-native-image-admission.md) records
its exact publication and validation scope. The matrix review separately binds
OmniOS disk `45983bb7` to image
`sha256:98b23b7931bc52d55b3c5b38cc20c97c1c967be96cf301940f88b01c715530d8`,
all five direct host-KVM scenario receipts, the signed immutable NAR and the
[OmniOS constructor](../../../nix/domains/artifacts/guest/native-promotion/omnios.nix).
Its exact artifact/evidence build and dual-family registry refusal property
passed. Historical narrower or failed candidate records remain distinct.
Physical power-loss acceptance and
Marshall-driven fleet execution remain unrecorded.

The [FreeBSD candidate](../../../nix/domains/artifacts/guest/native-kernels/freebsd/default.nix)
builds a static GENERIC amd64 kernel using pinned Clang 19.1.7. Its public
`sys/vsock.h` uses vendor family 45, BSD address length/family bytes and the
reviewed port/CID offsets. The bounded passive socket wrapper requires root,
accepts host CID 2 only, and fences all sockets on reset/configuration changes.
Its static interrupt lifetime requires a new VM after a transport reset; runtime
detach and unload are refused once interrupts exist.
A separate test-only Firecracker pause/full-snapshot/resume run passed actual
idle-identity fencing, pending accept/read/write wakeups and fresh-socket refusal
until a new VM. Exact image/token/firmware/VMM hashes are in the review; this
single transport event does not establish reset-race stress or DMA/physical safety.

The [illumos sources](../../../nix/domains/artifacts/guest/native-kernels/illumos)
use the exact stock-image OmniOS source revision
`6f87d0b5d63b957991dc9d4a01a7e6c95483282c`. They backport modern virtio and
its bounded correctness fixes, add public family 40 with a 16-bit family field,
and implement separate `drv/viosock` and `socketmod/sockvsock` wrappers. Creation
requires global-zone system-configuration privilege. The opt-in sockfs listener
failure path is required so transport resets can wake blocked accepts without
changing ordinary TCP listener behavior. The current transport allocates all
fallible queue/worker resources before `DRIVER_OK`, refuses runtime detach and
retains every activated DMA/interrupt-visible resource until VM disposal.
Unavoidable later attach failures fence readiness and retain a bounded unavailable
attachment because Firecracker's refused device reset cannot establish safe
reclamation. Source-extracted host fault injection covers all preactivation
allocation sites and both late-failure paths, with three lifetime mutants
rejected; it does not establish native reset/DMA safety. The separate direct
block request correction reserves each request's maximum data segments plus
header/status descriptors, clamps the scatter limit before DMA attributes and
preserves bounded indirect depth. Its extracted helper passed 265,596 generated
arithmetic/sanitizer vectors. These correct existing lifetime/capacity boundaries;
they do not prove the earlier ZFS EIO cause or replace exact native replay.
Completion returns the request and its descriptors before notifying blkdev,
which can synchronously resubmit. Cached transfer/error values survive immediate
reuse; external completions return submission success after one callback,
including polled errors, while internal transfers retain direct errors. This
source-reviewed correction preserves request ownership and avoids a duplicate
framework completion. Its extracted five-function regression passed 161
strict-C11/sanitized host histories and rejected four actual-source mutants;
corrected native execution remains separate evidence.
The native link/install helper verified
all 26 cross-objects and linked all nine modules with Solaris `ld -ztype=kmod`,
then installed them into an alternate scratch ZFS boot environment and rebuilt
its boot archive. A native loader failure exposed Clang's userland
`_XOPEN_SOURCE` default; the corrected build undefines it, checks actual ordinary
syscall exports and binds the Nix recipe into the compiled input token. The
corrected clone booted under QEMU and passed a native TCP bind and seven helper
boundary tests. Its linked/install receipts retain runtime validation and
native admission false. The complete OmniOS kit subsequently passed native
pool import/clone/link/install/boot-archive/export with all nine modules and its
full payload; fresh QEMU verification passed installed-file/Git/trust/resolver
and disabled-service checks. A diagnostic Firecracker boot passed complete
executing-AF40/file verification and the native Rust transport probe after a
debugger-only stock pseudo ISA override. The later 765-entry kit includes
persistent console settings and passed fresh native clean-export assembly.
Final exact-image runtime verification and complete service execution remain
separate requirements; diagnostic overrides grant no admission.
The first formal normal boot of that kit reached ordinary login with persistent
serial settings, then refused the service gate: stock physical networking
entered maintenance and all three Overalls manifests failed the SMF stability
enum. Decoded FMD logs show the first ZFS EIO before unsupported VMM reset
attempts; the disk-I/O cause remains under investigation. The correction removes
all four fixed stock vioif0 address/DHCP files from only the scratch clone,
binds their absence into assembly/verification, uses the valid `Unstable` enum
and runs native `svccfg validate` on the three exact installed manifests before
receipts. Actual native validation passed the corrected manifests and refused
the deliberate old-enum mutant; schema validity does not establish method
execution. Corrected-input service and storage replay remain required.
The final corrected token `985301b4` kit passed native nine-module linkage,
764-entry payload installation, all three native manifest validations and the
four exact network removals, then boot-archive rebuild and clean export.
Read-only receipt extraction and clean administration shutdown sealed disk
`24318238`; the review records complete artifact/receipt hashes. This recorded
target-native assembly does not establish a reproducibly Nix-built disk,
normal-boot services, isolation, recovery or production admission.
The later completion-corrected `76b8c1ad` build passed all 26 objects and four
host-test gates, followed by separate pristine native nine-module/764-entry
assembly with the same schema/network checks, read-only receipt extraction and
clean shutdown. Sealed disk `a49255bd` and complete hashes are in the review.
The paired direct-only QEMU diagnostic mounts root and reaches console login on
`76b8` under the same no-vsock settings where `9853` panics mounting root. Its
growth service enters maintenance; Firecracker service/transport/reset evidence,
original ZFS EIO causality and production admission remain separate gates. The
failed `9853` history remains preserved. The first corrected-image Firecracker
service attempt stays alive and reaches console login with growth in maintenance,
withholding network/identity and missing the 240-second fixture deadline.
Retained serial corrects the earlier wrapper-rendered blank-output impression.
A separate exact-image host-direct diagnostic isolates the sliced expansion
operand refusal. The corrected typed raw/whole-disk helper passed its Rust gates,
then fresh kit `d0rd` passed native assembly and clean shutdown, sealing disk
`bea32fe6`; the review binds complete kit/receipt/disk identities. Corrected
service/growth/transport/reset replay and production admission remain open.

Both wrappers share the allocation-free, little-endian frame and credit state
machine in [common](../../../nix/domains/artifacts/guest/native-kernels/common).
The generated malformed-frame/transition and sanitizer checks execute that C
implementation on Linux; they do not execute either operating-system wrapper.
Both support passive host-initiated streams only, with bounded sockets, windows
and DMA pools. Guest-initiated connect remains explicitly unsupported.

The [official OmniOS SDK](../../../nix/domains/artifacts/guest/illumos_sdk)
and [native Lyra package](../../../nix/domains/artifacts/infrastructure/lyra-native.nix)
provide hash-verified target headers/libraries and twenty production native
executables, ten per OS including mounted-root growth, plus separately packaged
test probes. The earlier eighteen-executable build remains historical evidence.
The SDK records archived-source TLS acquisition limits separately
from exact content integrity. Linker/interpreter and closure checks establish
userland packaging only. The [review](../reviews/2026-10-17-native-kernel-attestation.md)
records passing kernel/userland/terminal build scopes, exploratory boots and
remaining image assembly, loaded-build identity and machine requirements.
The FreeBSD test-only transport listener and nested-KVM machine gate are now
present. An exploratory candidate Firecracker run passed token/CID2/3,
oversized-length refusal, partial-disconnect recovery and nine exact echo sizes
through 1 MiB. The newer nested-KVM machine gate passed in 139 seconds, including
native ABI, immutable buffer and capacity refusal checks; later candidate input changes require their own
recorded execution. This scoped transport result grants no production service
or fleet admission. Separate FreeBSD two-boot candidate assembly passed; the
OmniOS kit builds immutable full installation inputs and has passed native pool
assembly. A diagnostic Firecracker clone subsequently passed complete file/token
verification and the native Rust transport probe through 1 MiB under a
debugger-only stock pseudo ISA setting. The assembler now binds persistent
pseudo ISA and loader/kernel serial settings while preserving original files;
final exact-image replay and complete OmniOS services were later recorded in a
separate receipt; growth, policy, supervised daemon recovery and isolation remain
pending. A native
FreeBSD vendor-base image passed complete service and daemon-recovery variants
over two clean boots each, including actual certified SSH/account/sudo/refusals,
trust, private-HTTPS Git checkout bytes, managed PTY input/resize/replay, fenced
execution, rotated host keys and retained home data. The subsequent
canonical-roots/SSH image passed those complete service oracles within its
three-boot growth and two-boot policy variants. Those earlier records predate
the blocking UFS flush correction. The final reviewed image SHA256
`5022d714b94032253bc44b706b37426f8a247debd155fbe223fde28000228f55`
subsequently passed all five service/growth/policy/daemon-recovery/abrupt-crash
variants, with complete per-boot service oracles, exact artifact hashes and
admission false. The review records the immutable output paths and scope.

The current source-qualified OmniOS service fixture then passed two clean boots
using image SHA-256
`4709cc444055528f53326d2e0c943b5ef002396008920f1940a0a06591a992cb`, kernel
SHA-256 `c56dc5c19523ef29511e2bfe4b98a6544b786a089b55b654c30ea32e821bdd21`,
firmware SHA-256
`261c6d43a4d74e6e7f4ea98390b35b6e0d90c511cf961e4b7abb60410b1c24a2` and patched
Firecracker SHA-256
`ba91e85a7af3f96d02f845df543daec07353ed6bff4aaee0abf524c751476b68`. Its
receipt records current-boot identity, readiness, trust, flush, workspace,
terminal, SSH, executor fencing and retained-home checks, with both boots ending
cleanly. The test-only manifest and receipt retain `native_admission=false`;
growth, network policy, supervised daemon recovery, physical isolation and fleet
admission remain separate requirements. The separate OmniOS crash receipt
records process SIGKILL and same-disk recovery only.

The [root-growth helper](../../../lyra/src/native_growth.rs),
[GPT validator](../../../lyra/src/native_growth/gpt.rs) and
[service ordering](../../../nix/domains/artifacts/guest/native-growth.nix)
implement mounted-root-only preflight and per-boot receipt gating. Twelve pure
tests and cross-target Clippy passed. Three native FreeBSD QEMU boots passed an
unchanged root followed by two 2-GiB expansions, retained home bytes, unchanged
nonroot GPT entries and a separate foreign disk. The later exact
canonical-roots/SSH FreeBSD image passed 334-second Firecracker composition:
three distinct clean boots, two expansions, complete service oracles, root
capacity increases, retained home data, protected GPT/partition identities,
foreign-disk preservation and caller/nonroot refusals. The strict EFI oracle
preserves every directory/file path and file bytes except the pinned firmware's
root regular `NvVars` store bounded to 1 MiB. The final blocking-flush image
passed the same three-boot/two-expansion boundary. The later source-qualified OmniOS
three-boot/two-expansion replay is recorded below; interrupted expansion still requires execution. The
[isolation fixture](../../../nix/verification/tests/machines/native-isolation/driver.py)
uses packaged Lilly router/TAP policy and positive-control TCP sinks. Its
composed NixOS driver and real Linux nft rule/counter smoke check passed. The
later native FreeBSD policy variant passed 280 seconds over two clean boots:
all sinks reachable before policy, public traffic and private SSH retained,
forbidden targets refused, foreign-source guard drops observed and assigned
source recovered. Its sibling is a Linux sink behind the peer uplink; direct
native peer-VM/TAP, jail, physical-host and multi-host isolation remain
gaps. The final blocking-flush image also passed that same two-boot policy
boundary. The original candidate receipts retain admission false; the later
exact-image approval is recorded separately from those execution results.

The [daemon-recovery oracle](../../../nix/verification/tests/support/native_recovery.py)
records actual kill/reap, three live readiness refusals, exact executable
restoration to a new supervised PID and same-boot protocol recovery on each of
two clean FreeBSD boots, including the final reviewed image. The
[abrupt-crash oracle](../../../nix/verification/tests/support/native_crash_recovery.py)
instead exposed scheduled-only FreeBSD UFS sync: acknowledged managed-home and
marker writes were lost after real SIGKILL/fsck. The corrected adapter waits
for native UFS suspension and soft-dependency drains through `/dev/ufssuspend`,
then immediately resumes before acknowledgement. The final reviewed image
passed observed SIGKILL, same-disk/new-identity restart, exact retained bytes,
stale-authority refusal, native UFS snapshot fsck and final clean shutdown.
Pinned OmniOS ZFS sync already blocks on `spa_sync_allpools`; its complete
crash scenario still requires execution. Process-SIGKILL evidence does not
establish physical stable-media or host power-loss durability.

The [host fixture gate](../../../nix/verification/tests/evaluation/native-fixtures.nix)
passed 59 parser/refusal/cleanup/Git/FAT tests with pinned tools. It is host
verification, separate from all native machine results above. Exact image,
kernel, firmware, VMM hashes and execution records remain in the linked review.

The local MAC-normalization `sis8` kit subsequently passed fresh native
nine-module/764-entry assembly, native SMF validation, clean export, read-only
receipt extraction and administration shutdown, sealing disk `1e095659`.
It retains false runtime/admission flags; complete services and recovery remain
unqualified. A later native command lease/stop correction changes the current
userland again. Its source and pending exact-image replay are recorded in the
[admission review](../reviews/2026-10-17-native-image-admission.md); neither the
prior OmniOS assembly nor the sealed admitted FreeBSD image covers those new
executable bytes.

Direct `sis8` diagnostics identified a separate supervisor path error:
`/usr/lib/ssh/sshd` is absent in the pinned OmniOS root. A live stock boot and
the native SMF method confirmed `/usr/sbin/sshd`; both native supervisors now
use that path. OmniOS assembly and booted verification additionally require its
safe root-owned regular executable ELF and record
`native_ssh_executable_checked`. This closure check grants no SSH configuration
or runtime readiness claim. OmniOS also rejects explicit `UsePAM yes` because
its downstream PAM policy is always on. Omitting that directive only for
OmniOS passed native `sshd -t` and `sshd -T` with synthetic volatile host-key
prerequisites, retaining effective PAM and public-key-only authentication.
The previously reported `wz4r` kit subsequently passed native assembly and clean
shutdown, sealing the 8,589,934,592-byte disk SHA256
`e7fc0c04bccb4b443dd4bea2edcdabfa2d1481fee6b683891f4338b399625a41`.
Its 158,319-byte assembly receipt SHA256 is
`512a112f910a3ce65c5f3f791a91aecbdcc20c8e428af6f9f9702ee904320180`.
The receipt binds nine modules, 764 payload records, all three native SMF
validations and the safe native SSH executable check. The native workspace
receiver binds OmniOS Git ownership to one validated checkout path. Its
immutable native Git configuration includes the
root-controlled `/run/overalls-workspace/gitconfig`; the receiver writes one
exact `/workspace/<repository>` entry atomically before its durable `done`
marker and recreates it after volatile runtime loss. The include is outside the
writable checkout, and unrelated root-owned repositories remain refused. This
native-only closure is required because pinned OmniOS Git 2.44 does not support
the `/workspace/*` prefix form; it establishes checkout ownership only, not
native service or admission. The sealed `wz4r` disk was later found to contain
a stale cached kit with the former wildcard config and pre-fencing receiver, so
it does not evidence this current source behavior. The source-derived kit
`/nix/store/w5mg2jw3c2sispdkfg1r9ys5vxm41a97-overalls-omnios-native-image-candidate-kit`
then required fresh target-native assembly and replay.
That earlier kit includes
the executor lease/stop correction and both SSH fixes. Runtime, complete
services, growth, recovery and admission were false or pending at that point;
the matrix review preserves that history separately from final qualification.

Follow-up [matrix review](../reviews/2026-10-18-guest-os-matrix.md) evidence
separates source corrections from fresh-image qualification. OmniOS root
growth discovers read-only device labels with the persisted userland pool cache
disabled, retaining the assembly GUID, single canonical whole-disk vdev and
GPT/capacity gates; a disposable same-boot missing-cache fault case passed.
Native agent SMF keeps contract duration and ignores only signal failures so
the existing child supervisor can replace one killed daemon; exact-policy host
refusals passed. Listener close also wakes pending accept children under the
socket lock; host sanitizers and a missing-wake mutant check passed. Fresh native
assembly passed for the combined sealed `45983bb7` disk. That exact disk then
passed all five direct host-KVM service/growth/policy/daemon-recovery/SIGKILL
scenarios, ordinary transport and one reset event. Its immutable promotion,
signed-cache custody and exact registry qualification passed separately. Core,
hardware and empty-contract failures retain outer restart authority. A killed
shell supervisor with surviving children remains an explicit recovery gap.
The source corrections preserve this decision's existing boundaries; the later
per-image qualification enables only its previously authorized native subset.
The selected exact OmniOS `98b23b79` image subsequently passed an ordinary
Marshall-driven 16 GiB create, strict CLI SSH identity, terminal stop, restart,
repeat strict CLI identity and terminal deleted cleanup at healthy `b17d6beec`.
The original failed release-label oracle is retained. Stop has a terminal
receipt rather than a separate physical checkpoint. The matrix review records
the immutable lifecycle summary separately from native scenarios.
Fresh exact-image run `122228` then separately passed the same full lifecycle
with an independent current-owner stopped-state checkpoint and completed
deletion. Its immutable checkpoint/deletion receipts close that owner-observation
gap without adding a physical absence, capability or recovery guarantee to
either journey. The original `091638` result and failed release-label oracle
retain their own scope.

The [GitHub integration checkpoint](../reviews/2026-10-18-github-com-integration.md)
records new attribution-capable native artifacts separately from the existing
promotions. Fresh FreeBSD image `0150b6d1` passed all five exact-artifact scenarios
with 26 named service checks and actual-byte structural verification. Fresh
OmniOS image `679f5f8b` passed direct two-boot services with 26 checks and exact installed
payload verification; its separate nested-NixOS matrix is pending at that
checkpoint. The verifier's 23-test gate preserves old 22/25-check sets and requires
all 25 current baseline checks plus attribution only for explicitly validated
Git identity v1 images. Those checkpoint results did not publish, admit or activate
new images.

The original two-file selected registry made admission-history maintenance a
prerequisite to changing defaults: Lilly repeats exact native admission on
retained boot bundles during restart. The [registry](../../../protocol/lib/overalls_protocol/native_admission.ex)
now keeps explicit per-OS immutable history and validates each selected default
against it. [Retained staging](../../../fleet/staged-guest-images.nix) keeps exact
old promotion packages alongside selected packages for in-flight original
provisioning; ordinary retained restart does not load catalog artifacts.
Nine focused protocol tests and the Nix native-OS evaluation gate initially
passed without changing selected identities; the latter simulated a selection
change and verified retained staging.
Both histories use current v6/v3 codecs, so this is immutable authorization data
rather than an older-format compatibility reader under ADR-0159.

FreeBSD image `0150b6d1` subsequently passed all five unchanged scenarios against
current VMM `f0d9275b`, followed by structural verification, signed publication
and independent empty-store substitution/content/signature verification. The
fresh-downloaded bytes passed the production verifier. Its
[current-VMM promotion](../../../nix/domains/artifacts/guest/native-promotion/freebsd-14.3-db752667-f0d9275b.nix)
is now the source-selected default and its exact manifest is appended to
admission history. Old manifest/bundle identities, original promotion and worker
staging remain intact without Git capability relabelling. Nine focused Protocol
checks and the selected package/promotion/native-OS Nix targets passed, including
production `verify_approved!`. OmniOS selection remains unchanged. Native memory
continuation, new live deployment and a Marshall-owned journey through the new
FreeBSD artifact remain separate obligations. The earlier OmniOS growth pass
and four failures retain their old-VMM scope in the
[GitHub review](../reviews/2026-10-18-github-com-integration.md).

The unchanged OmniOS candidate `679f5f8b` subsequently passed services, growth,
crash recovery and daemon recovery against current VMM `f0d9275b`. Isolation
failed at the first boot's bounded SSH `shutdown-send` operation with
`subprocess-timeout`, before the separate VMM wait. The runner completed
authority and VMM cleanup but produced no second boot or complete
isolation/service receipt. This four-pass/one-failure matrix does not qualify
publication, admission or selection; the failure cause remains unestablished.

The manual OmniOS link/install procedure now also runs as the `kvm`-feature Nix
derivation [`omnios/assembly.nix`](../../../nix/domains/artifacts/guest/omnios/assembly.nix)
(`omnios-image-candidate`). The pinned stock guest's Solaris `ld` links the nine
modules and `native_image.py assemble` installs them into a scratch copy, which
the loader cannot select because only the administration disk is bootable.
Two executions produced the identical assembly receipt `b3acafb4`, stock `unix`
`c56dc5c1` and seven modules byte-identical to the promoted `45983bb7` receipt;
the changed viosock/sockvsock sources produce new digests. Raw disks still
differ between executions (ZFS GUIDs, transaction groups, timestamps, SMF
repository and boot archive), so deterministic guest linkage is recorded but
bit-reproducible native disk assembly is not. The test-only output keeps
`native_admission=false` and replaces no promotion. It feeds the formal
`native-omnios-reset` gate, which passed in 721.76 seconds, and the
`native-omnios-transport` gate, which passed both clean boots in 761.59 seconds
and, on the final formatted source, 681.84 seconds, with loaded viosock/sockvsock
file digests bound to the assembly receipt. A prior
transport run on the same inputs failed at `shutdown-send` with
`subprocess-timeout`, matching the unexplained `679f5f8b` isolation failure above.
Exact hashes are in the [matrix review](../reviews/2026-10-18-guest-os-matrix.md).

[ADR-0243](0243-native-guest-durability-verification.md) adds native durability
evidence beyond same-host SIGKILL. The promoted OmniOS `omniosGuest` image passed
interrupted growth, dm-log-writes power-cut replay and two-host ZFS relocation.
A pre-fix FreeBSD candidate lost an acknowledged marker after the power-cut
replay because UFS never flushes the virtio write cache. The FreeBSD agent now
sends `DIOCGFLUSH` before a flush receipt, and the corrected candidate passed
all three scenarios. The currently promoted FreeBSD image predates that fix and
is not durability-qualified; promotion of a fixed image remains a separate
obligation under this decision. The [matrix review](../reviews/2026-10-18-guest-os-matrix.md)
records the receipts.

A second OmniOS promotion selects Nix-assembled disk `a96f291b`, image
`sha256:6dc1a0840e50e508c964c2890e805c919b78c2cddb3e1e8e9d379e001c28617d`.
It carries the `vioif` receive descriptor budget and the growth helper's
synchronous disk-link creation. All five required scenarios ran as Nix machine
checks on its exact bytes with one VMM; the sealed candidate was published to
the signed cache and substituted into a fresh store with signatures required.
The [constructor](../../../nix/domains/artifacts/guest/native-promotion/omnios-r151050-a96f291b.nix)
passed `verify_approved!` against the
[registry](../../../protocol/lib/overalls_protocol/native_admission.ex), which
keeps `98b23b79` in reviewed history; fleet staging retains its promotion.
The selected image passed the ADR-0243 power-loss and interrupted-growth
checks. Live Marshall-driven lifecycle on the new image is not yet recorded.

## Open questions

- Which further signed FreeBSD and OmniOS/illumos inputs should be accepted. OmniOS is
  the installable downstream image and `illumos` is the stable protocol label.
  A direct illumos.org image source is unavailable: the upstream project
  identifies OmniOS, OpenIndiana and Tribblix as downstream distributions.
- The exact OmniOS five-scenario matrix, individual daemon replacement and two
  separately recorded ordinary 16 GiB fleet lifecycles have passed. The later
  journey includes an independent stopped-owner checkpoint. Readiness under fleet load and
  shell-supervisor death with surviving children still need independent records.
- Reproducible native full-disk assembly remains unrecorded; OmniOS Nix KVM
  assembly reproduces its receipt and unchanged module bytes, not its raw disk.
  The intermittent OmniOS `shutdown-send` timeout is undiagnosed. The exact FreeBSD
  and OmniOS artifacts are promoted by reviewed immutable bytes and hash-bound native
  evidence; candidate manifests alone remain insufficient.
- OmniOS wrong-CID injection, valid-reset races and DMA safety, physical
  recovery and broader isolation retain separate gaps. The one reset receipt
  and exact image promotion do not establish those broader guarantees or admit
  unrelated members of either native family.
- A fresh current-revision Linux browser journey remains open. Native and
  Windows editor support would require separate package, broker, descriptor,
  authority and browser-machine evidence; existing terminal/SSH and native
  service receipts are insufficient.

## Related decisions

- [ADR-0011](0011-nixos-guest-and-console.md), [ADR-0068](0068-nix-built-ubuntu-guests.md): existing Linux image contracts.
- [ADR-0113](0113-guest-trust-at-boot.md), [ADR-0154](0154-guest-boot-profile.md): boot-bound guest evidence.
- [ADR-0146](0146-standby-guest-disks.md), [ADR-0159](0159-remove-legacy-compatibility.md): standby and convergence ordering.
- [ADR-0243](0243-native-guest-durability-verification.md): native flush durability, interrupted growth, power loss and relocation evidence.
- [ADR-0169](0169-firmware-booted-windows-guests.md), [ADR-0170](0170-lilly-firmware-guest-launch.md), [ADR-0171](0171-windows-guest-agents.md), [ADR-0173](0173-windows-images-winget-desktop-experience.md): Windows decisions.
