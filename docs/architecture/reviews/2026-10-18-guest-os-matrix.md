# Guest OS matrix evidence review (2026-10-18)

## Scope and architecture impact

This review reconciles the seven declared guest OS families with the evaluated
fleet catalog, current image evidence and opt-in Porsche acceptance tooling.
It also corrects foreign-Linux ext4 construction, adds evaluation assertions for
the native SSH supervisor's temporary PID cleanup and reconciles the Windows
evaluation's shared VMM patch inventory.
The next checkpoint repairs Windows profile/bootstrap ordering, foreign-root
LSM and temporary-directory construction, and the exact OmniOS release probe;
it preserves diagnostic failures and separate source/build/native/live scopes.
The following checkpoint restores Arch's boot-time root policy, normalizes
actual Hegel lock identities and refreshes all eight dependency snapshots. It
records completed OmniOS and fresh NixOS lifecycles while preserving failed
foreign-Linux and then-pending repaired-Windows acceptance. The later checkpoint
records the exact repaired Windows full CLI lifecycle and preserves the foreign
Linux PAM refusals. The helper-fixed checkpoint subsequently records fresh
Arch and AlmaLinux lifecycle passes with read-only sudo/helper checks before
and after restart. The final OmniOS checkpoint journey completes the scoped
seven-family SSH/lifecycle milestone. Earlier failed image attempts retain
their failed scope; the broader custom-kernel plan remains partial.

The matrix-specific repairs add no Ash domain/resource, deployment host/service, persistence shape,
authorization grant, wire protocol or guest capability kind. Exact-image
qualification enables only the previously reviewed native subset. The work preserves
[ADR-0190](../decisions/0190-native-kernel-provenance-and-admission.md),
[ADR-0171](../decisions/0171-windows-guest-agents.md) and
[ADR-0173](../decisions/0173-windows-images-winget-desktop-experience.md).
The new Hegel frontend checkpoint preserves
[ADR-0191](../decisions/0191-elixir-hegel-property-verification.md), including
its incomplete compatibility and separate execution evidence.
Their recorded decision and implementation statuses remain unchanged.
The existing domain and deployment views require no inventory change.
Windows publication enforces ADR-0171's existing built-once distribution through
the signed cache of ADR-0188. The illumos accept fix preserves ADR-0190's existing
host-only transport while making successful accept wait for RESPONSE publication.

## Findings

The [shared image list](../../../fleet/guest-images.nix) declares NixOS, Ubuntu,
Arch Linux, AlmaLinux, FreeBSD, OmniOS and Windows. Native entries are filtered
by the selected package's `nativeAdmission` flag. Both exact promoted FreeBSD
and OmniOS packages now pass that filter. `omniosGuest` and `illumosGuest`
select the same reviewed OmniOS promotion; stock constructors and candidate
kits retain false admission/runtime flags. The
[current matrix](../../guests/os-matrix.md) separates these seven source-selected entries
from recorded native machine and live fleet execution.

FreeBSD admission remains bound to image
`sha256:d141e4266c29da00a1378157b1d39369b1d48e577bca4ce7375e8ff6d399557b`
and its complete validated manifest or portable descriptor. The compiled
registry, immutable promotion and ordinary current-boot attestation remain the
authority. Changed candidates, stock native identities and an OS name alone
remain refused; editor and Inception remain false. The existing
[admission review](2026-10-17-native-image-admission.md) records the approved
five native scenarios and their limits.

The promotion verifier now compares the exact named service-oracle set, rather
than its length. The immutable FreeBSD approval retains its 22 reviewed checks.
OmniOS requires 25: the shared set plus workspace Git ownership/unrelated-root
refusal, executor current-heartbeat withdrawal and whole-process-group
cancellation with fresh-fence completion. Missing, extra, renamed or incorrect
clean/crash-ending checks refuse, including equal-length substitutions and an
OmniOS receipt using FreeBSD's narrower set. The current promotion unit gate and
actual sealed FreeBSD package build passed; this strengthens evidence validation
without itself admitting an OmniOS image or executing a new native scenario.

Earlier source-qualified OmniOS receipts cover complete services over two clean
boots, three boots with two root expansions and separate process-SIGKILL
same-disk recovery. Those receipts retain `native_admission=false`. No claim of
supervised daemon recovery, formal policy gates, current wrong-CID/reset/DMA safety, direct
native peer-VM or physical-host isolation, interrupted growth, physical
durability, relocation or live fleet acceptance follows. Historical failed
assemblies and service attempts remain in the
[native kernel review](2026-10-17-native-kernel-attestation.md).

The current illumos socket repair makes `sd_accept` wait until the connection
RESPONSE has been submitted, preventing an immediate application close from
overtaking that handshake. Reset, listener closure and an interrupted wait
refuse instead of returning an unestablished child. The extracted production
downcall passed 256 forced pthread schedules under ASan/UBSan; a forced old-code
mutant failed. Strict cross-compilation, native helper/shim checks and 24 image
helper tests passed for kit
`ir4bn13n5yhfs143jh94rv1kpp0355h4`, transport build identity
`cc5b0bd0d40375a5364cbd7a5650fbf14f8fd02c8e3ab8652f1e690e13e7b2d4`.
This host regression verifies ordering, not native interrupt or DMA safety.

The new exact test-only image SHA-256
`aa669e51a6b68b623d432c317c9527367697455fac1e53612cc1b8f3f66c3bbb`
retains kernel SHA-256
`c56dc5c19523ef29511e2bfe4b98a6544b786a089b55b654c30ea32e821bdd21`.
Direct host-KVM execution of maintained scenario runners passed ordinary
transport over two clean boots, the API pause/full-snapshot/resume reset
fixture and two-boot Lilly-policy isolation. The latter service receipt names
all 25 current service checks plus five policy checks per boot. These are
manual direct-host fixtures with unique netns/TAPs, exact sealed disk clones,
pinned Firecracker and synthetic authority; they are not the formal NixOS
nested-KVM gates. Supervised daemon recovery still fails its first
readiness-withheld connection after daemon replacement. Separate current-image
service, growth and process-crash runners passed. Services records 25 checks
across clean boots `29757d82-d279-48be-8459-3d265df77ed0` and
`7089b0e6-5df1-4dfd-9697-d8e841af55a2`; growth records all 25 service checks
across three clean boots `638d6d06-5d6e-4a7a-8e9e-76114ef79ca0`,
`58f92a5d-c269-40d7-ab31-4ab3c1a2af03` and
`cfbf73bb-194d-4fb3-ba42-ad26c8a3ca2c`, with two expansions; crash records 25 service and eight
recovery checks with endings `sigkill,clean` across boots
`1fbe9a12-3c50-41db-bba1-5530a4b7f1dc` and
`68f89a41-217e-4c25-aa97-dc0e7bb4b771`. Earlier image results are not
transferred to these bytes. Admission remains false. No peer-native,
jail/physical-host, multi-host or power-loss guarantee is established.

The follow-up source correction keeps the native agent SMF service's contract
duration and sets `ignore_error` to `signal` only. This lets the shell supervisor
replace an individually killed child without SMF killing the other listeners;
core dumps, hardware errors and an empty contract still use the outer restart
boundary. Assembly and boot verification reject missing, duplicate, broader or
instance-overriding policies. The 25-test native-image suite passed, including
ten refusal mutations for the new semantic gate; Ruff formatting/lint, ty and
contract checks passed. Listener close additionally publishes its closed state
and wakes same-port pending-handshake children under the socket lock, so accept
can refuse without another interrupt or completed connection callback. The
extracted production close/accept regression passed ASan/UBSan and caught a
missing-wake mutant. A killed shell supervisor with surviving children remains
an explicit unverified recovery case.

The combined kit subsequently passed fresh native assembly, including nine
modules, 764 payload records, native SMF validation, clean export, read-only
receipt extraction and administration shutdown. Its 8,589,934,592-byte disk
SHA-256 is `45983bb74f9064f7aeea7d4f934094bd8c4c0efb4e8a2ad7f4bf0a8ee6390554`;
the 158,362-byte assembly receipt SHA-256 is
`aaf9aeeee25b73c6454a395b69b78eb4a207b59dcbcd363b088e8839592edb04`.
Its test-only manifest SHA-256 is
`aac2c4d67684f9e77d1fc7b6b2207b6ae4fc4a3800cfd32170608c9d607d6be8`.
Those assembly records alone granted no admission; the exact-image runtime and
immutable promotion records below were collected separately.

The unchanged `45983bb7` disk subsequently passed all five maintained direct
host-KVM scenario runners: complete services, three-boot/two-expansion growth,
two-boot Lilly router/TAP policy, same-boot supervised daemon replacement and
same-disk process-SIGKILL recovery. Ordinary transport and the API
pause/full-snapshot/resume reset fixture also passed independently. Every
service-bearing receipt records the exact 25-check OmniOS oracle. The final
services receipt SHA-256 is
`b8fc867e0d1e5484c05da231bb5012ae00411937320ae91e0764be296efb30de`,
with clean boots `eba79645-1cd5-479d-a035-9b2aa24bcd4f` and
`8620cb2b-a7ac-4aed-9f9a-547458f740f4`. Recovery observed real daemon death,
three withheld-readiness probes, an exact supervised replacement and restored
current-boot flush without changing the guest boot identity. Growth preserved
the pinned pool/vdev and foreign-disk identities. The crash receipt records
`sigkill,clean`, fresh authority/boot identity, exact retained bytes and native
ZFS integrity checks. All candidate execution receipts retain
`native_admission=false`; qualification is the separate immutable review step.

The final reset receipt SHA-256 is
`02f0ed8e2c0a7146d16a93a5e0f5f7fe9887174c784df1b603d0d4a62a64fb1d`,
boot `c3e2cf85-4e50-4e2e-ac48-5037628e052f`. All three API operations returned
204; pending read, accept and idle operations refused with 131 and the blocked
write with 32 after 262,144 bytes. The current CID was revalidated. This is one
transport-reset event, without service-restoration or DMA-safety evidence.

The reviewed version-6 manifest is
[`protocol/priv/native/omnios-r151050.json`](../../../protocol/priv/native/omnios-r151050.json),
image ID
`sha256:98b23b7931bc52d55b3c5b38cc20c97c1c967be96cf301940f88b01c715530d8`.
The manually assembled input is sealed at
`/nix/store/9r92hvbj5zch8r0xdv4wsw7rhhwg6as7-overalls-native-omnios-r151050-45983bb7`,
recursive NAR hash `sha256-JrTq1siY+meAVhpqYBdddLVgs+eagD79taqn+wZivsU=`,
with no references. Local exact-NAR comparison, public signed-cache import and
independent Dungarees substitution/content/signature verification passed. The
[OmniOS promotion constructor](../../../nix/domains/artifacts/guest/native-promotion/omnios.nix)
passed its exact artifact/evidence verifier and produced
`/nix/store/8lckqimfchbk5p21n3qb3s09byx4dr1q-lilly-omnios-r151050-x86_64-promoted`,
containing only `disk.raw`, `firmware` and `manifest.json`. The compiled registry
now qualifies that complete immutable identity and its normalized descriptor;
changed identities, cross-family descriptors and stock agent names still refuse.
The unqualified native capability rows, editor and Inception remain false.
The later source activation points both fleet aliases at that exact promotion;
it does not admit unrelated candidates or establish a deployed live guest.
The catalog evaluation, 15-check promotion gate and actual exact promoted
package build passed for that source activation. Evaluation binds image
`98b23b79` and true promotion flags, identical OmniOS/illumos aliases and false
candidate-kit flags. The existing promoted output is unchanged. The record is
`/tmp/overalls-osmatrix-omnios-catalog-gates.log`; selected-release host builds,
deployment and live CLI acceptance retain independent records.
These records satisfy the existing per-image promotion requirements without
claiming reproducible native assembly, formal nested-NixOS execution, a direct
native peer VM, jail/physical isolation, interrupted growth, shell-supervisor
death with surviving children, physical power loss, relocation or live OmniOS
fleet acceptance.
The promoted output has recursive NAR hash
`sha256-qKv00aAEuM+ObUg2GpzEvepykgDpn3EE9aoG3EKWAhs=` and no references.
The published candidate contains no test probes, synthetic keys, logs or runtime
clones; probes were installed only in owned disposable clones. Its declared
minimum is 2 GiB memory and 16 GiB disk. Recorded growth is the deterministic
8-to-10-to-12 GiB expansion history, separate from a live 16 GiB launch. The
kernel digest identifies the kernel executable; the assembled disk digest binds
the nine installed modules.

The final runner uses an explicit owned Firecracker `--log-path`: the default
logger writes stdout even when stderr is redirected, so splitting only stderr
could mix VMM text into the guest JSON stream. Startup stderr and serial stdout
now have separate files. The reset parser waits for a newline before accepting
even a valid final JSON fragment; malformed or duplicate complete events still
refuse. Four focused reset regressions and an old-parser mutant established the
boundary. Native terminal verification now closes the completed initial control
before PTY work and gives resize/retire fresh authenticated 15-second controls;
the data channel keeps its own 15-second limit. A controlled-clock healthy
18-second history passed, a 16-second data timeout still refused and the actual
old-helper mutant failed. Retirement failures fail otherwise successful probes;
secondary cleanup failures preserve the original failure without payloads.
These fixture fixes change no guest bytes and do not classify the preserved
earlier PTY failure. The final native-fixture gate passed 87 checks, 31 additional
focused checks passed, promotion tests passed 15 checks, and pinned Ruff
format/lint plus ty passed on all Python files. Six focused protocol checks,
including the 64-case identity-substitution property, passed; full exact-source
protocol and consumer gates retain separate records.
The exact-source protocol full precommit is recorded below; the five-scenario
native execution scope remains separate from that BEAM validation.

The follow-up mounted-root helper also removes dependence on an early-boot
persisted ZFS userland cache. Read-only label discovery uses
`zdb -C -e -U /dev/null -p /dev/dsk` for the fixed root pool. Assembly pool GUID,
the exact single whole-disk vdev, canonical device path, raw-device custody,
capacity and both GPT copies remain prerequisites before mutation. Three natural
failures stopped at the old `zdb` child exit before mutation. A controlled
missing-cache diagnostic on a disposable clone removed only its root-owned
regular cache: the old query failed with the missing-file class and no pool
configuration; the revised helper passed preflight, native expansion, post-GPT
preservation and the volatile success receipt. This is one same-boot diagnostic
fault case, separate from fresh-image three-boot growth, interrupted expansion,
physical recovery and admission. The full Lyra Nix gate also passed in 224
seconds; its host tests, lint and target checks do not establish native growth.

Arch/Alma evaluation checks establish their separate pinned root sources,
version-4 identity and installed offline agent/service closure. They do not
establish either distribution's Firecracker boot or runtime behavior. An audit
found differing foreign-Linux ext4 bytes at the same declared Nix paths on the
two hosts. The construction now derives sizing from regular-file/symlink content
instead of host-dependent directory sizes and fixes source times, filesystem
hash seed and filesystem mutation clocks. Image construction and
`foreign-linux-guest-unit` evaluation passed. Actual rootfs
`nix-store --realise --check` rebuilds also passed for both outputs, separately
from an image-wrapper-only rebuild:

| Rootfs | Bytes | SHA-256 |
|--------|-------|---------|
| `/nix/store/1w979vhp7ql5bdlbfawggaw9rqvixycd-ext4-fs.img` (Arch) | 2,289,811,456 | `f5ea8703eb558211b65939e0121e84699edc5a4f85995ce2db2be0a6d54b3376` |
| `/nix/store/abvfphcmdf8wsl7kzf7zv9hhkf1hgy12-ext4-fs.img` (AlmaLinux) | 2,555,826,176 | `8811a0a08ea2a9a9c181310fd9df7cef78f2284160b659532c4af8c99a846eb2` |

These historical comparisons precede the final copy and SSH-policy changes.
A later cross-host Arch comparison failed: store optimisation had changed
incidental hardlink topology, which changed ext4 inode allocation despite the
same source paths. Both base-root and closure copying now explicitly discard
hardlink topology. The final fleet-context cross-host comparison passed on
Dungarees after signed Overalls Cachix substitution and actual local rebuilds:

| Family | Rootfs derivation | Compared output |
|--------|-------------------|-----------------|
| Arch | `/nix/store/b95hz1ikv93rc4nlfv0s3yz43vk8s9r3-ext4-fs.img.drv` | `/nix/store/galrn1ln1arp3c539dvkr535flfp2q6w-ext4-fs.img` |
| AlmaLinux | `/nix/store/6a376plmpddg8mhh02q1w2cim46iad9k-ext4-fs.img.drv` | `/nix/store/nxmyvyg5s43r7nicbz69rzdnvqnnh40y-ext4-fs.img` |

`nix-store --realise --check` returned exit 0 for both actual rootfs outputs.
Arch measures 2,325,372,928 bytes, SHA-256
`750e1bcbb607e0d96aeb270c27172713d44ec29b53d2ce01a8d72c9c06aa6662`;
AlmaLinux measures 2,684,354,560 bytes, SHA-256
`21e62216428509310cefd13f2d992a5fba926c83e9eed8c88c380f5eb5b77682`.
This historical comparison covers those fleet-context construction inputs, including
the copy and SSH-policy corrections below. Native guest execution remains a
separate requirement.

The foreign-Linux audit also replaces vendor-dependent SSH includes and PAM
stacks with a complete owned key-only policy and pinned absolute PAM modules.
Opening an SSH session requires the private current login receipt. Dedicated
locked `sshd` and `overalls-ssh` identities are allocated without UID/GID
collisions; NSS account lookup uses local files. Reconciliation has explicit
pinned account tools and PATH. Sudo is a root-owned regular mode-4755 image copy,
with per-user policy supplied only by the existing roster reconciler; a
non-setuid Nix-store symlink cannot provide that behavior. Vendor sshd service
enablement resolves to the same readiness-gated listener. Account-allocator unit
coverage, evaluation and inspection of both actual ext4 outputs passed. The
filesystem inspection verified regular root-owned mode-4755 sudo, distinct locked
service identities, pinned executable tools, SSH/PAM policy, private login
receipt requirement and unit PATH; its digest/outcome record is
`/tmp/foreign-linux-final-filesystem-audit-20261018.json`. These checks do not
establish a successful Arch/Alma boot, PAM session or sudo invocation.

A subsequent six-image artifact audit checked every manifest, native admission
result and actual file length/SHA-256, including the 64 GiB Windows disk. The
then-current Arch and Alma roots also passed independent Dungarees rebuilds with
Nix 2.34.8, empty builders/substituters and `nix-store --realise --check`:

| Family | Compared rootfs output | Bytes | SHA-256 |
|--------|------------------------|-------|---------|
| Arch | `/nix/store/g8ll63iw4fqhvwbiak0z0pp92wv19xfp-ext4-fs.img` | 2,325,372,928 | `424736943bee56855eddc242b24ccdb56b35bd3ec548b6f0dda678bdcfc50539` |
| AlmaLinux | `/nix/store/03l6nbi3ni4dqbfc7q615slj3nc09ifb-ext4-fs.img` | 2,684,354,560 | `46c98944ee61cd042e02f61ca1eff46c13b3c9f97da1629822f6513bdb89e1ce` |

The receipt is
`/tmp/overalls-final-fleet-images-20261018/cross-host-reproducibility-receipt.json`.
These exact-byte comparisons did not establish a bootable distribution root:
live creation of both images subsequently reached `/sbin/init: Permission denied`.
The shared upstream-root copy discarded source modes, leaving systemd, its ELF
loader and bash at 0644. The original failed VM identities and diagnostic
receipts remain retained. A narrow correction preserves upstream executable
modes and grants staging write access only to the build owner. The actual
private-fleet filesystem gate passed in 58 seconds, inspecting both
init/bash/loaders at 0755, release data at 0644, sudo at 04755, shadow/gshadow
at 0600 and root ownership. Both original images separately failed this gate at
bash mode 0644. The corrected Arch image ID is
`sha256:fc437aea09e700c617afa6d45a7c76c94fbf071b60c5a7d9d44477847ed68778`,
root SHA-256 `4a12184a5c207ea8d1fa003f7b8e39e7bb236de50ddb0e3e16837a19831a000a`,
2,325,372,928 bytes. Alma's image ID is
`sha256:f91eaf37e427c28e3529ef9f26ec0e3bb4b4134d1bd2268add1f31fb4d6cac7b`,
root SHA-256 `8cc93fb7ace0889cfeb6518590aa2248e80494941a61fc8368b35ff6709b7b05`,
2,684,354,560 bytes. Evaluation and contract checks passed. Corrected-image
cross-host rebuild and runtime acceptance remain separate; prior rebuild
results do not transfer to these corrected roots. The corrected images then
passed fresh actual file SHA-256/length and complete offline policy audits,
plus forced Dungarees `--check` rebuilds with independently matching remote
hashes. Records are under `/tmp/overalls-corrected-fleet-images-20261018/`.
Their later failed live creates are recorded below and do not inherit offline
success. The next source repair explicitly selects `lsm=landlock,yama,bpf`,
matching the evaluated NixOS manifest (the Ubuntu manifest does not currently
declare an LSM parameter). The assembled foreign roots lack the distribution's
SELinux labels, so the distro policy must not activate against that root.
This selects the guest stack without changing host jailer, network, protocol
or capacity authority. After general write-mode normalization, the builder
also restores real root-owned `/tmp` and `/var/tmp` directories to 01777;
accounts can create temporary files while the sticky bit protects other
accounts' entries.
The actual private Arch/Alma artifact gate passed in 57 seconds, inspecting
the final manifest and ext4 directory/file modes and ownership. A manifest
without the selection failed the LSM check; substituting the previous Arch
ext4 while preserving a valid new manifest failed the `/tmp` directory-mode
check. The evaluation and contract/format checks passed; logs are
`/tmp/overalls-foreign-linux-boot-{check,contracts,old-alma-negative,old-arch-tmp-negative}.log`.
These are offline artifact checks, without a repaired-image boot or readiness
claim. The exact Arch readiness sandbox diagnosis remains in progress.
The combined final source, including the Windows repair and current Hegel
pin, then passed both actual private Linux filesystem/manifest and evaluation
gates in 167 seconds; log
`/tmp/overalls-osmatrix-final-foreign-linux-artifact-checks.log`. That combined
artifact result remains separate from repaired-image runtime acceptance.

Windows
has a current 64 GiB Desktop Experience catalog image and 96 GiB template
budget; its latest recorded stop attempt hung, so a complete current-image
stop/restart/delete pass remains open. The Windows guide now distinguishes
that image from the historical agentless spike.

The audit also observed different Windows bytes at the same input-addressed
source-derivation path on the two hosts. The fleet selector now uses
`windowsGuestPublished`, a recursive-hash fixed-output directory sealed from the
existing registered `windows-v1` image. The source installer stays available for
development. The selected directory has exactly dereferenced regular `disk.raw`,
`firmware` and unchanged `manifest.json`, with no references. The fixed-output
fallback only prints publication guidance and exits 1; it cannot reinstall,
read a host-local image or weaken signature checks. The
[Windows guide](../../guests/windows-guests.md) records the exact path, NAR/root
hashes and update procedure. Package resolution, artifact/file custody,
declaration and fallback refusals passed. The public Overalls Cachix narinfo is present for the
exact `nh6wfp35zm8wpdjgkvms7dlwkr1pwbgr` path, signed by the reviewed cache key;
its compressed NAR is 17,099,050,377 bytes. Both hosts now hold the exact sealed
path with the same recursive NAR hash, NAR size 68,723,672,224 bytes and no
references. Both imported the public cache signature and passed
`nix store verify --no-contents --sigs-needed 1`. This establishes signed cache
publication and cross-host custody, separately from runtime acceptance.
This is an artifact-identity correction and grants no new
Windows runtime guarantee.

The [Porsche acceptance guide](../../acceptance/porsche-acceptance.md) describes
the explicit-image matrix workflow. The runner retains private resumable
evidence and exact fixture ownership. Its implementation and host-side tests
cannot substitute for a live guest execution record. At this initial checkpoint
no live seven-OS pass was recorded, and the runner could not bypass unavailable
OmniOS admission to obtain one. Later exact-image lifecycle evidence is recorded
below. Inception is known broken and outside this work.

The first NixOS, Ubuntu and FreeBSD matrix creates in the private
`/tmp/porsche-20261018-071500` run failed with `template_quarantined` before guest
execution. The NixOS failure exposed a runner-ledger gap: accepted creation identity now persists
before polling, and failed/superseded terminal receipts remain available for
owned reconciliation and cleanup. Read-only reconciliation retained the original
VM/request rather than issuing another creation. A failed retry-start was
superseded by successful `failed-create-cleanup` receipts for all three original
fixtures. This failed creation run establishes no guest execution.

The separate private `/tmp/porsche-20261018-072900` run created NixOS
`b4e446ac-d45e-4a82-8a83-4b043da5e305`, Ubuntu
`79d8e4c5-ad65-4838-8ec8-0b740adec9b9` and FreeBSD
`7f99f396-dd70-4b57-a8e4-4446c7ab3d57`. Each passed `matrix-ssh --stage initial`
through the installed Overalls CLI with the exact OS oracle, then passed
`matrix-stop --stage orderly-stop`; durable state confirmed stopped generation
2. `matrix-start --stage restart` and `matrix-ssh --stage after-restart` then
passed for all three. `matrix-cleanup --stage final-cleanup` then returned deleted
receipts for all three owned fixtures.
An unrelated existing VM received a read-only SSH probe only. No complete
seven-OS lifecycle, all-capability, revocation or independent physical cleanup
claim follows from these subset results.

The later `/tmp/porsche-20261018-075200` six-image run used deployed revision
`f5ce1e6c67593040d0523ecc81b8b84c8977cdcb`; its 09:11:49 UTC structured
snapshot is `acceptance-ledger-snapshot-091149.json` in that private directory.
NixOS `226555b3-1fb5-47cf-b9d2-cd238135a36d` and Ubuntu
`45f93d2c-b354-4696-8b84-0a795761974e` passed create, initial exact-OS CLI
SSH, orderly stop with stopped-state checkpoint, restart, repeated exact-OS SSH
and terminal deleted cleanup receipts. The NixOS restart reconciled the original
request after a transport failure. Original Arch
`cfb76a7d-e67b-4a0f-aa4e-2b2f700d4c72` and Alma
`f1196e0a-c3c6-4531-a5f2-5f72a338dc4a` failed before init on the mode-stripped
images; their later stages were not run, and their original identities and
failed receipts are retained.

That run's FreeBSD `cbf81155-470c-407e-a0f0-5132f2a03daa` passed through
restart and repeated exact-OS CLI SSH. Its original cleanup request first
remained unsettled: desired state was deleted, observed state unknown and the
failure was `cleanup_failed` while the maintained ZFS destroy namespace sweep
could not confirm absence. The reconciliation poll ended with a management
`transport_error`, rather than a successful deleted receipt or deadline
exhaustion. Investigation found the exact dataset retained in a rootless
Podman mount namespace. Retirement was initially refused while unrelated
containers were active. After fresh proof of zero active work, normal idle
context retirement released the namespace; `SendSIGKILL=no` prevented forced
termination and the pause process exited naturally. The external storage
container remained intact. The unchanged cleanup helper then reconciled the
original request to `succeeded`/`deleted`; the VM was archived at 09:38:41 UTC
with no failure reason. The private `matrix-final-six-cleanup-freebsd.json`
receipt records that terminal outcome. No forced unmount, migration, database
repair or replacement intent was used. This closes the recorded fixture's
lifecycle after operational recovery, without establishing independent
physical cleanup or automatic recovery for other namespace holders.
The inspected transient context started at 08:55:11 UTC; it explains the
later observed blocker, not necessarily the earliest 07:52 cleanup failures.
Its private manual operational audit is
`/tmp/overalls-osmatrix-freebsd-cleanup-recovery-audit.json`, SHA-256
`fbec957e7ca328cd39423e48d30d935ecc98d281b7f294fda7a2db07b8841084`.
The audit records zero active runtime processes/API clients, nine mounted
storage paths with zero process users/errors, preserved storage records,
normal service retirement and an exact post-retirement namespace inventory
with zero matches/errors and confirmed dataset absence. It is not a native
machine-test receipt. Existing recursive-private propagation does not remove
already copied mounts; preventive pool-free rootless namespace creation
remains unimplemented.
The terminal receipt SHA-256 is
`1996c8eaca49b2053f625cf722c94f365cd58065d0c35a84547d7f23815506ba`.

Windows `c8149dc5-eff4-4bed-8ab0-2f6965edb025`, image
`sha256:e9ed22f19485315066bc5527ebd207fce8cd7d7fa4c0854a963c58ffa5361d73`,
created and reported running with `guest_ready=true`, but its initial CLI SSH
attempt exited 255 before a remote banner. Read-only diagnosis found sshd
stopped with no TCP/22 listener and SSH-sync reporting `pass_failed`, despite
an existing roster account and enabled inbound TCP/22 rule. The owned fixture
was retained for diagnosis; later lifecycle stages were unrun. That ready flag
does not establish SSH access. A later owned-fixture native diagnostic isolated
`CreateProfile`: the original 4,096-unit output buffer returned HRESULT
`0x800706f7` (Win32 1783) without registering a profile; the `MAX_PATH`-sized
260-unit call returned `S_OK` and created the SID-bound profile. The existing
agent then enabled the account, installed one key file, started sshd and
retired the bootstrap Administrator. The private
`windows-profile-diagnostic-receipt.json` marks `fixture_mutated=true` and
`unchanged_image_lifecycle_acceptance=false`. This is a manual API diagnosis,
not an unchanged-image SSH or lifecycle pass; a rebuilt, sealed image still
requires its own acceptance.
The diagnostic receipt SHA-256 is
`e0a1225693a09e5a1a9d4eca1e52bf5b89f07205f480dd3d25cb98c821ab3239`.
The integrated Windows repair uses the bounded profile call and verifies the
SID-bound registered directory before activation. Its shared
[`ssh_bootstrap`](../../../lyra/src/guest/ssh_bootstrap.rs) coordinator clears
prior keys before first listener startup, requires a verified current-boot
host-certificate receipt and publishes bootstrap readiness before ordinary key
delivery. Every readiness response also requires the two current receipts and
live sshd. Same-boot retries preserve current keys. The four-field running-VM
and completed provision/start key-delivery authority is unchanged; neither
the roster nor host-certificate bootstrap route acquires key authority.
This implements ADR-0171's existing boundaries without a replacement decision.
The frozen source patch SHA-256 is
`8946bd954ca2b3a716cb46dfe1d13707a5cd3a7b04ef41c7591e9d74d0661455`.
Its sandboxed Lyra gate passed in 197 seconds with 223 portable tests,
Linux Clippy, Windows all-binary type checks and FreeBSD/illumos checks and
Clippy; log `/tmp/overalls-windows-profile-bootstrap-frozen-lyra-check.log`.
The portable cases cover actual readiness answers, pre-completed-start key
refusal followed by successful retrieval, stale-key cleanup refusals and
same-boot preservation. They do not execute Windows SCM/profile APIs or a
fresh sealed image. The new Windows installation and its full live lifecycle
retain separate evidence.
A separate 64-second sandbox mutation gate caught both retaining prior keys
and allowing a readiness answer without the current marker, log
`/tmp/overalls-windows-bootstrap-negative-check.log`. The mutation build did
not change frozen production or image inputs.
The combined final source's multi-target production Lyra release also built
successfully in 318 seconds, log
`/tmp/overalls-osmatrix-final-lyra-release-build.log`. A linked release does
not establish execution of the new Windows installation.
The subsequent actual installation passed in 1,834.2 seconds with QEMU/result
zero and all required markers. Readback of the three repaired executables from
immutable NTFS matched the reviewed payloads. The sealed exact image is
`sha256:8ca0a11fd0063dc3f3bb7e4eb928dcb7083da08be4e72ba8ef9e56de911c5d5c`,
with recursive NAR hash
`sha256-MTpVti0Mc+c3FzqjUJLfBAfEIW+plgP+HheZnVdPlUo=`,
68,723,672,224 bytes and no references. Private installer, installed-custody,
manifest and seal receipts are under
`/tmp/overalls-windows-profile-bootstrap-*`. Scoped signed publication then
passed in 418.446 seconds, followed by public narinfo retrieval and actual
Ed25519 verification of the exact NAR fingerprint, including store path, hash,
size and empty references. Receipt
`/tmp/overalls-windows-profile-bootstrap-publication-receipt.json` has SHA-256
`eed8f20592a39abc7a99c77e8ef3bc70ae3a515fa9f0582aa8c529e2be65f442`.
The first urllib fetch returned a client-specific 403; bounded TLS curl fetch
passed with the same signature checks. Independent Dungarees substitution then
began with the exact sealed path absent, used the reviewed trusted cache key
and passed full NAR content/signature verification. It independently checked
the exact three regular files, manifest hash/canonical image identity and
complete disk/firmware hashes. Receipt
`/tmp/overalls-windows-profile-bootstrap-dungarees-receipt.json` has SHA-256
`1b069d4f268781d0c2d0d96223e90d41cff5b86036089650c8075f9eda18f9ad`.
The source selector now pins that exact reviewed name, NAR hash and manifest.
Selected-image deployment and clean physical lifecycle acceptance remain
pending; the old mutated fixture does not verify these new bytes.
The separate corrected Arch/Alma qualification
ledger `/tmp/porsche-20261018-085815` later created Arch
`10ce2f77-7be8-4dea-9f8c-3171dac34b0c` from image `fc437aea` and Alma
`746ad956-f800-4e32-80bc-cf98af6c57c4` from image `f91eaf37`. Both original
create requests ended `failed`/`execution_failed`. Arch reached running units
and an SSH listener, then failed the readiness budget; Alma encountered
SELinux policy and `/run` mount-context denials. Their corrected mode and
artifact-custody checks do not establish readiness or any later lifecycle
stage. Further source/image repairs require separate runtime results.
OmniOS is outside the six-image ledger. No complete six- or seven-OS pass
follows.
The separate `/tmp/porsche-20261018-091638` OmniOS ledger completed its original
create request for `b04f2400-fc7a-4fe5-8a92-dd7c441e98f2` after both consumers
converged healthy to `b17d6beec`, using exact promoted image `98b23b79`.
The original `matrix-ssh-omnios-promoted-initial-omnios.json` recorded actual
CLI transport exit zero but failed the OS oracle: the probe omitted the real
`OmniOS v11 r151050` label and produced only `SunOS`. That failed attempt is
retained. A narrow probe correction normalizes the pinned `v11` label to the
existing canonical `OmniOS r151050`, preserving exact revision refusal.
Its executable shell regression refuses the wrong revision, version and
vendor. The updated suite passed 24 checks; narrowed Ruff/ty/contracts and
all-files pinned Ruff, Ruff format and ty passed. Logs are
`omnios-oracle-source-checks.log` and `python-all-files-static.log` in that
private ledger.
The same VM's explicit `initial-v11` stage then passed the exact OS oracle
through actual CLI SSH, exit zero, 21 output bytes and SHA-256
`2c45e839af8de414f3acdb6b514c9902ec09ef927545bd82f6146a6dd5a1fece`.
Its orderly stop, original restart, repeated strict CLI OS identity and owned
cleanup then all succeeded, ending with a terminal deleted receipt. Stop is
proved by its terminal stopped receipt; no separate pre-restart show-state or
physical checkpoint was recorded. The immutable private summary is
`qualification-summary-100056.json`, SHA-256
`4bd27971eee5547ccedff2ba77d50aa2972f00d000e7cb05bdc0cddaaecd3132`.
This establishes one ordinary 16 GiB exact-image live lifecycle at `b17d6beec`,
separately from the native growth/policy/recovery scenarios and physical
isolation or reset stress.
Its promoted-artifact proof passed the shared schema/admission validator and
fresh full 8 GiB disk/4 MiB firmware hashes against the reviewed manifest.
Artifact custody, creation/readiness, exact CLI identity and later lifecycle
stages retain separate evidence scopes.

Both actual-host toplevel builds for the combined repair checkpoint
`870eecef53c5627b517974e5367069a068cd4b8a` passed in 357 seconds, log
`/tmp/overalls-osmatrix-870-hosts-build.log`; both auto-updaters confirmed
healthy exact-release convergence with zero failures at 10:10 UTC.
The combined Arch/Alma actual ext4s and image wrappers also passed forced
independent Dungarees `--check` rebuilds with builders and substituters disabled.
Remote rootfs and manifest hashes matched local outputs; manifest-file hashes
are distinct from canonical protocol image IDs. The receipt is
`/tmp/overalls-combined-linux-images-20261018/cross-host-reproducibility-receipt.json`,
SHA-256 `1c0ee9ab412c06c33555e18a9ebf445f1cbf80a2efb4db0f1e7e55c2b10989f2`.
These build/custody results did not establish guest readiness.

The final `/tmp/porsche-20261018-101111` custody audit independently validated
the actual selected artifacts and canonical identities. Ubuntu retained its
previous exact `8d468c67` image despite a wrapper-path change, so its recorded
`075200` full lifecycle is retained with fresh custody evidence. The changed
NixOS `92114604` image's VM `40e03d8b-b369-43e7-9f1e-faf72dfabfc2` passed
create, strict initial CLI identity, terminal stopped plus a separate current
owner stopped-state checkpoint, restart, repeated strict CLI identity and
terminal deleted cleanup. Final Arch `e2f67fe5` VM
`05406661-2b26-4d91-97fc-29d1cf87cd48` and Alma `43b08259` VM
`abe3258e-86a0-4956-adeb-2629720d5c37` both returned terminal `execution_failed` creates; no foreign SSH or
privilege smoke passed. The private `qualification-snapshot-102335.json`
retains the actual receipts, unchanged-Ubuntu proof and failed creates.

The exact Arch same-boot diagnostic found root mode 0555 and a capability-free
root process receiving `mkstemp` EACCES, despite immutable root mode 0755.
The preserved vendor `/usr/lib/tmpfiles.d/root.conf` contains `z / 555 - - -`.
An Arch-only higher-priority `/etc/tmpfiles.d/root.conf` now applies
`z / 0755 root root -`; it leaves the vendor file, capabilities, recursive
ownership, readiness checks and host authority unchanged. Actual private
artifact/evaluation gates passed in 63 seconds; the original exact image fails
the new gate for its missing override. A guarded scratch execution using the
pinned systemd-tmpfiles and exact extracted policies reproduces old root 0555
with capability-free `mkstemp` errno 13, then proves root 0755 and successful
write/flush/fsync/unlink with the override. Receipt
`arch-root-policy-runtime.json` in the combined Linux ledger has SHA-256
`64bfc6cd57b03b6a968664c90fab89d54a80f4f72524ad94336e866197c733f8`.
The final exact-artifact audit confirms the combined evaluation selects
`sha256:8ab89c2d0e0f679ef2f43fdd849b1d750d1ca24948ca5413c05913e17493801c`;
it checks the actual filesystem, manifest hashes and copied native executable
custody. Receipt `arch-root-policy-artifact-audit.json` has SHA-256
`8a4ace58fc62d81cbbb5231015eb40696c96dc2c5c21aab9b43c1f5652cef5a7`.
This is actual artifact and isolated policy execution evidence; a fresh
repaired-image production boot and lifecycle remain pending.
The exact Alma fixture separately passed capability-free root write/fsync,
network and growth predicates, but `systemd-resolved.service` was absent.
Dependent private DNS/readiness/SSH units therefore remained inactive. The
closed `alma-final-{readiness,units}-diagnostic.json` receipts preserve that
cause without changing its original failed create or proving guest SSH.

The private Alma-only repair now installs the existing pinned resolver service,
both sockets, D-Bus policy/activation and exact sysusers configuration. A
dedicated `overalls-resolved-identity.service` invokes only that configuration
after remount/vendor sysusers and before sysinit, D-Bus and resolver startup;
the resolver requires and follows this bootstrap. Vendor sysusers conditions
and unrelated account configurations remain intact. Eight regular files and
five activation links are checked byte-for-byte with root ownership and modes
in the actual immutable ext4; the old image is rejected specifically for its
missing resolver runtime. Final private filesystem/evaluation gates passed in
44 seconds. The Arch derivation is unchanged, and there is no new host service,
domain/resource, wire contract, capability or authority grant.

The repaired Alma candidate is
`sha256:bed87c331fae5fbd3669646765f21af7c9631498e3c8cef5d19952f55714dc33`.
Its actual-artifact audit checks the manifest, copied native executables and
exact pinned resolver/sysusers/nologin ELF bytes, including root-owned 0555
executables inside the copied Nix store. Private receipt
`alma-resolver-artifact-audit.json` in the combined Linux ledger has SHA-256
`e22bab6bda53887a9650c4e9f4e67f40b0227f2a68f3c130c749589bc175f98e`.
Independent Dungarees forced root and wrapper rebuilds with empty builders and
substituters passed, and remote root/manifest hashes match local immutable
outputs. The combined source selects those exact Alma outputs and preserves
the Arch derivation. Receipt `alma-resolver-cross-host-receipt.json` has SHA-256
`48495dc6264e4d05f6ec0e95b9990fe6b8b898e26751b94c4222cb53cfcee488`.
Isolated pinned sysusers execution using copied Alma account databases creates
only a locked nonroot resolver UID/GID 992, preserves every unrelated account
row and reruns byte-idempotently. Receipt `alma-resolver-sysusers-proof.json`
has SHA-256
`16086d0b7f231a2b17c0b41ed4a9ab316ec32cdfd80bbe77aaeca414c6f4afe2`.

The native Alma systemd 257 parser also accepts the exact pinned systemd 261
resolver service/two sockets and the actual built identity unit/drop-in with
zero unknown/invalid settings, ordering cycles or shared-library failures.
The isolated extracted scratch still reports eight missing executables; this
is parser compatibility evidence without daemon execution. The v2 receipt
`/tmp/alma-systemd-parser-20261018-1053/native-parser-receipt-v2.json` has
SHA-256 `9bd222f8a940488a1a8121013716cf5d8ca4ef3fc38d94d0e7fa0f1aea276973`,
and retains the original narrower v1 receipt identity. Artifact/build, sysusers
policy execution and parser results do not establish a fresh production guest
boot, resolver/D-Bus activation, strict CLI SSH or the repaired-image lifecycle.

The same ledger's later strict idle-namespace recovery preserved the original
cleanup intents. Both the user Podman service and exact pause scope received
normal SIGTERM under temporary `SendSIGKILL=no` guards only after fresh zero
ordinary containers, runtimes, API clients and storage users/errors. Namespace holders
then reached zero without forced signals, unmounts, migration, storage removal
or database writes; the external storage record remained intact. All 15 known
historical fixtures subsequently reached terminal deleted receipts with no
visible historical fixtures or missing cleanup. The durable manual audit is
`/tmp/overalls-osmatrix-idle-namespace-cleanup-recovery-audit.json`, SHA-256
`df26f04459beaecbbe2c9fab54606b8ba695f97b483d0b4aabb4d7ff7cfe995c`.
The two current failed foreign fixtures remain separately authorized for
causal diagnosis. Original failed creates, SSH attempts and transport failures
remain failures; this manual recovery is not an automatic or independent
physical cleanup guarantee.

## Consumer verification prerequisites

Initial consumer repairs used Hegel frontend `9b13af8`; the repaired consumer
checkpoint selected ref `02cd8bd`, resolved as
`02cd8bd5bf07a7ca1bfaf7d599456fff5badbfa2`.
The source locks were normalized to that full resolved commit while retaining
the requested ref. Source/fixed-output lock snapshot comparison and hash refresh
retain separate verification records. All eight actual Mix dependency outputs
now match their current source lock snapshots and configured recursive NAR
hashes. Six rebuilt outputs passed; Brady and Galileo retained their matching
outputs, and the Cargo hash is unchanged. This corrects source/artifact custody
without selecting new dependency bytes. The
historical protocol pass at `2c9f7a4` verifies neither pin. The first Marshall full test attempt (seed
836760) was killed with exit 137 during compilation. The pinned context-pattern
`property/3` macro recursively rewrites identifiers without reaching a fixed
point. Twenty-nine affected declarations across twenty Marshall test files now
use ordinary ExUnit declarations tagged `:hegel`, retaining their one existing
generated check, all generators, fixtures and oracles. These consumer repairs
change no production behavior, transport or authorization interface.

Both actual-host NixOS toplevel source builds subsequently passed in 691
seconds with the canonical dependency locks and native-growth correction. This
establishes release/build closure for those source inputs, separate from later
handbook-only rebuilds, deployment, live readiness and guest runtime acceptance.
A later pair of actual-host source builds at `d388cf91a` passed in 264 seconds.
That result likewise establishes build closure, separately from later merged
source, deployment and guest acceptance.
The frozen registry/foreign-mode source on merged `21831915e` then passed both
actual-host toplevel builds in 247 seconds, recorded in
`/tmp/overalls-osmatrix-registry-hosts-build.log`. The merged presentation checks
also passed, including nine JavaScript tests. Later handbook compilation and
deployment retain separate records.
The merged first batch `c420650b2` subsequently passed both actual-host
toplevel builds in 233 seconds, log
`/tmp/overalls-osmatrix-merged-registry-hosts.log`, and both consumers converged
healthy to that exact release before catalog activation. That release still
selected six entries. The later OmniOS alias activation is a distinct source
change requiring its own build, deployment and live records; no guest outcome
is inferred from the consumer convergence.
Both actual-host builds for the selected seven-entry catalog at `008a02331`
then passed in 291 seconds. After merging the caption and crawler policy,
both actual-host builds at `b17d6beec` passed in 263 seconds, recorded in
`/tmp/overalls-osmatrix-omnios-merged-hosts.log`; both consumers converged
healthy to that exact release. This establishes the selected-release build
and deployment scope, separately from live OmniOS or other guest acceptance.

The handbook unknown-ID property separately corrects a discarded compatibility
filter: a bounded UTF-8 generator actually excludes listed chapter IDs, draws
silently through the native test-case boundary and checks direct/traversal
refusal in 100 cases at seed 20261018. Fixed observability tests remove unused
Hegel imports. A capped focused execution passed all eight handbook/observability
tests (ExUnit seed 465575). Compile-only discovery then exposed unsupported
tuple-destructuring and single-line `gen all` forms in the distributed capacity
generator; explicit tuple/map/bind composition preserves its operation variants,
weights, key ranges and four-to-seven batches of two-to-four operations. Full
current consumer outcomes remain separate records. These are BEAM verification
repairs and establish no native guest or deployment guarantee.

After merging frontend `02cd8bd`, the view-inventory suffix generator was made
explicitly uppercase, and enrollment GUIDs compose two 32-bit halves to retain
all nonzero unsigned 64-bit values. Unknown enrollment keys use a real filter.
The three-case TLS histories use the native `test_cases` option; each actual
fifteen-second silence history runs separately so expected runtime does not trip
the cumulative slow-input health check. No deadline or assertion was relaxed.
The three-file focused rerun passed all 17 tests in 97.7 seconds, ExUnit seed
43955, with warnings as errors on the full resolved frontend commit above.
This covers the maintained view inventory, enrollment parser and real loopback
TLS peer fixtures; it does not establish a full consumer gate or native guest.

The subsequent count audit replaced 158 ignored `max_runs` option names in 107
Marshall test files with native `test_cases`, retaining each literal value.
Ninety-seven plain outer properties also receive the identical count so their
existing per-case fixture and replay boundaries remain intact. Normalized AST
comparison preserved every other body, generator, assertion and option value.
Compiler, contract and logging checks passed; a temporary native counter probe
observed exactly three executions from an outer `test_cases: 3` property.
Full current-source execution remains separate. One pre-existing distributed
admission `max_shrinking_steps: 0` option remains unsupported by this engine;
the repair does not claim that shrinking is disabled there.

Lilly's analogous audit restores 55 intended counts in 37 files and moves 14
plain outer wrappers to tagged ordinary tests so their native checks own those
counts. Protocol restores three counts in two files; its two View histories
create a fresh View and retire real writer processes for every case and replay.
The focused protocol run passed eight tests in 3.6 seconds, seed 427219.
Lilly's full canonical-pin precommit previously passed 610 tests in 150.4
seconds, seed 947632, Covenant 15/15 and forced Dialyzer with zero errors.
That pass preceded these intended-count repairs; the final repaired-source
protocol, Lilly and Marshall full gates remain separate pending records.
Lilly's final repaired-count full precommit subsequently passed all 610 tests
in 66.8 seconds, seed 991989, Covenant 15/15, contract regression/format checks
and forced Dialyzer with zero errors or skips in 12.46 seconds. It exercises the
55 corrected counts on the frozen dual-family registry source, separately from
the earlier canonical-pin baseline or native host behavior.

The later protocol merge serializes the control-client fixture and selects the
CI profile directly on the standalone workspace-source native check. The
reviewed count stays 500: the incoming two-case outer wrapper and ignored inner
`max_runs: 50` would reduce exploration from the already passing native count.
The merged workspace-source profile passed all five focused tests in 0.1
seconds, seed 926594. Control-client serialization retains its separate focused
and full verification record;
the prior 299-test full repaired-count gate passed in 417.3 seconds, seed
953483, Covenant 14/14 and Dialyzer with zero errors or skips.

The first complete repaired-count Marshall scan ran 1,694 tests with seed
634032: 1,682 passed, 12 failed and four were excluded, in 1,342.4 seconds.
Covenant passed 24/24, presentation JavaScript passed 9/9 and the Monospace
check passed; forced Dialyzer passed with zero errors/skips in 61.36 seconds
after a 4-minute-50.9-second PLT refresh. Six failures were the
native TooSlow input-health heuristic including real database, distributed,
passkey and ten-second SMTP histories. Scoped `profile: :ci` selections retain
all intended case counts and the actual clocks/assertions. A strict typed C
diagnostic against the actual linked NIF and its exact setter sequence compared
the effective settings: only the TooSlow suppression bit differs; seed,
randomness, database, phases, backend and counts are equal. The remaining
repairs give each ingress/key history unique fixture ownership, use the intended
lowercase list alphabet instead of a Range that the generator treated as
printable ASCII, use `integer(0..2)` for peer selection and retain the existing
`image_name` projection in SSH's exact field list. These repairs change no
production behavior and require fresh focused and complete execution; the
failed full scan is preserved as a failure record.
The fresh ten-file focused scan passed 59/60 tests in 407.4 seconds, seed
393478, clearing all twelve original failures. A sibling four-case retry-window
history then hit the same TooSlow heuristic after three valid cases in 34.55
seconds; it receives the same scoped profile while retaining all four cases,
proof mixtures and assertions. Its fresh focused run then passed in 46.4
seconds, seed 525114 (one selected test, three excluded). Complete final
Marshall precommit then passed completely: 1,694 tests, four excluded,
1,540.6 seconds, seed 156566, Covenant 24/24, terminal JavaScript 36/36,
presentation JavaScript 9/9, Monospace and forced Dialyzer with zero errors,
skips or unnecessary skips in 59.03 seconds after its PLT refresh. The process
exited zero; log `/tmp/overalls-os-matrix-marshall-confirmation2.log`.
It began at 09:11:27 UTC from `21831915e` plus final repairs committed as
`b84ac6277` at 09:13:28. Later caption/handbook merges add no test fixture
change. This is the `02cd8bd` checkpoint, separate from the focused records
and the later frontend update.

The frozen dual-family registry's full protocol precommit then passed 302 tests
in 413.6 seconds, Covenant 14/14, compiler/format/contracts/ADR checks and
Dialyzer with zero errors or skips in 3.38 seconds. That exact-source protocol
gate does not establish the pending consumer or native fleet execution.

Upstream `0ed3c8151` subsequently selected frontend ref `f1ad336`, resolved as
`f1ad336e4be1f0b3e18e429f8bc826d538b40601`, and refreshed all eight Mix
dependency hashes. Its upstream delta changes only map-context/keyword-options
macro handling and a regression test; the native engine/settings sources are
unchanged. Both freshly resolved Marshall and protocol NIFs hash to
`6ed2a45ede213661e8231523bcdc8315e96bcd81b4e1b29085686a436665d38a`.
The new context/options branch still recursively wraps its inserted variable:
an actual macro-compilation probe in an isolated 512 MiB/10-second scope
exited 137, while the plain-property/options control exited zero. Probe files
and logs are `/tmp/overalls-hegel-f1ad-{context,plain}-probe.{exs,log}`.
Existing tagged ordinary ExUnit workarounds remain in place. Focused new-pin
execution passed two protocol capability tests (seed 21863), six native
admission tests (seed 395668), and fourteen Marshall handbook/observability
tests in 4.7 seconds (seed 365394). The complete `f1ad336` Marshall run then
exited 2: 1,693 of 1,694 tests passed, four were excluded, in 1,526.1 seconds,
seed 770435. Its only failure was the opposite-source relocation/clone
host-lock property's native TooSlow heuristic after two valid inputs in
34.511763231 seconds. Covenant passed 24/24, terminal JavaScript 36/36,
presentation JavaScript 9/9, Monospace and forced Dialyzer with zero errors,
skips or unnecessary skips in 54.36 seconds. Log
`/tmp/overalls-os-matrix-marshall-f1ad-full.log` has SHA-256
`191055fe6498cadf7e922480a1b99518fa18eafc2893bafb54108b61a0334e09`.
It ran `0ed3c8151` plus the frozen sources committed as `870eecef5`.
This remains a failed full gate, separate from the passing prior-pin record.

Incoming `fb956a2c4` selects frontend `08cd428`, actually resolved as
`08cd4289b8b268ae14176e3391c791647e8affae`. Its delta from `f1ad336` touches
only the Elixir macro and regression tests: postwalk replaces recursive
prewalk, inserted variable metadata is corrected and context/options expansion
uses the ExUnit context pattern directly. Native engine/settings source is
unchanged. An isolated 512 MiB/10-second actual compilation/runtime probe passed
three forms: map context with options, named ExUnit context with options and
map context without options, seed 454122. Its log is
`/tmp/overalls-hegel-08cd-context-confirmation.log`; the initial diagnostic's
overly strict equality against a named full ExUnit context was corrected to a
submap pattern, preserving the original diagnostic log. This does not establish
the upstream suite or every compatibility form.

The scoped host-lock property repair adds only its outer `profile: :ci`,
retaining two generated cases and all three rotations per case, the real
three-peer startup, lock barriers, clocks, allocation/SQL assertions and cleanup.
Its selected actual `08cd428` run passed one test with two exclusions in 26.9
seconds at seed 770435, log
`/tmp/overalls-os-matrix-marshall-08cd-lock-focused.log`.

The incoming release failed the existing source-lock snapshot comparison.
Actual Mix resolution normalizes all eleven locks to the full upstream commit;
ten source locks required correction because Ziggy was already normalized.
All eight configured dependency outputs retained stale snapshots: seven used
the short ref and Ziggy used a different full revision. The private audit
`/tmp/overalls-os-matrix-08cd-stale-dependency-snapshots.json` preserves those
identities. All eight hashes were then discovered from actual normalized-source
fetches and refreshed; normal fixed-output builds passed. Independently computed
recursive NAR hashes equal the configured values, and every actual
`.overalls-mix.lock` is byte-equal to its source lock. Receipt
`/tmp/overalls-os-matrix-08cd-dependency-custody.json` has SHA-256
`574fe280ab34fd1d3d01996402cf8d120edf92d61484df606a1b393f0f729136`.
The Cedar Cargo hash is unchanged. Upstream `cdbc76086` then supplied
byte-identical resolved locks and hashes. The post-fast-forward source
comparison is `/tmp/overalls-os-matrix-08cd-cdbc-custody-confirmation.json`;
it independently confirms the same eight proven identities at that revision.
Both hosts subsequently converged healthy to exact `cdbc76086` at 10:43 UTC,
with zero failures. Complete current-pin consumer gates and the later Arch
repair's host builds retain separate records. No prior-pin pass is transferred.

The subsequent incoming `f7f3c8c7e` bounds Porsche's invalid-boot property to
one generated CI history. Each history still visits every configured refusal
mutation and retains startup, fixture-custody and diagnostic-secrecy assertions;
randomized history exploration is reduced, and no new execution is inferred.
Its unrelated temporary fake Porsche dependency hash is replaced with the
previously proven `sha256-Hp2h0NYvDKZDiVJEztDpL8/YVGF1r9vD/lNC51MlI30=`.
Source locks and dependency contents are unchanged, so the existing independent
fixed-output and byte-equal lock custody proof still applies. This merge
changes no production authority, domain, protocol or deployment placement.

The scenario validator additionally recognizes exact qualified Elixir
`Hegel.check(...)`/`Hegel.run(...)` calls, alongside existing property markers.
Negative-prefix and tag-only fixtures retain refusal; path containment, inspected
assertions and recorded-execution requirements remain unchanged. This prevents
real explicit-runner properties from losing their existing evidence category;
lexical recognition alone remains no proof of execution or native behavior.

### Completed current-pin execution and final-source custody

The full pre-machine-pin Marshall `mix precommit` at frontend `08cd428`
exited zero: **1,694 passed, four excluded**, seed **325708**, in **1,382.3
seconds** (32.1 async, 1,350.2 sync). Covenant passed **24/24**, terminal
JavaScript **36/36**, presentation JavaScript **9/9**, Monospace and forced
Dialyzer with **zero errors, zero skipped and zero unnecessary skips** in
**49.65 seconds**. The pinned devenv execution used four schedulers and a
6 GiB memory cap with no swap. Its exact frozen runtime sources remained
unchanged through `439a71e96`. Log
`/tmp/overalls-os-matrix-marshall-08cd-full.log` has SHA-256
`dd8f73eda5811aff43da64738bd55bb0df0b5e43523355c2c270f735cc87ceb4`;
source ledger `/tmp/overalls-os-matrix-marshall-08cd-frozen-sources.sha256`
has SHA-256
`f4ebb2f8f7ceab830355ca5eeccfddcf801124ed1fe7be555762645e3234ede8`.
This completes that current-pin execution record while preserving the failed
`f1ad336` run. It excludes the machine-pin implementation and tests imported
at `132bc28b5`, whose complete consumer gates require new execution.

At `132bc28b5`, `devenv shell -- prek run --all-files` exited zero. Ruff,
Ruff format, ty, conflict markers, all eight application logging checks and
the remaining installed hooks passed. Log
`/tmp/overalls-os-matrix-132-prek-all-files.log` has SHA-256
`9d1885de225f7035055b88f65212189c605f5e2219a95a13bf29e9511513b446`.
Static Python verification establishes neither browser rendering nor guest
execution.

The final `132bc28b5` protocol `mix precommit` exited zero: **303 passed** in
**420.6 seconds**, seed **476754**, Covenant **14/14**, the shared contract
validator **19/19**, and Dialyzer with **zero errors, zero skipped and zero
unnecessary skips** in **2.77 seconds**. Log
`/tmp/overalls-os-matrix-protocol-132-final.log` has SHA-256
`1679f6d5b0cabeace7b81a542ff7cf78662e122ef8ab02429c71842f10cb8b15`.
The frozen four-consumer runtime source ledger
`/tmp/overalls-os-matrix-132-final-consumer-sources.sha256` has SHA-256
`ed5721b9b633c20f632c760b0ee8d269fd6f3cad1c059aef56e9391f9ee1f82c`
and checked unchanged after execution. This protocol result does not replace
the final consumer gates.

The final frozen `132bc28b5` Marshall `mix precommit` also exited zero:
**1,712 passed, four excluded**, seed **576982**, in **1,413.8 seconds**
(27.6 async, 1,386.2 sync), including the machine-pin integration. Covenant
passed **27/27**, terminal JavaScript **36/36**, presentation JavaScript
**9/9**, Monospace and forced Dialyzer with **zero errors, zero skipped and
zero unnecessary skips** in **51.78 seconds**. The same four-consumer
runtime ledger verified unchanged after completion. Log
`/tmp/overalls-os-matrix-marshall-132-final.log` has SHA-256
`d52868d3b51b25421a4d945096155655c3d767e29488119ad9d6ff303b546981`.
This BEAM/static gate excludes subsequent fixture-script and CSS corrections;
their browser execution has separate receipts. Lilly and Porsche's final
full consumer gates remain separate.

The final frozen Lilly `mix precommit` exited zero with **610 passed**, seed
**132572**, in **62.1 seconds** (18.2 async,43.8 sync), Covenant **15/15**,
and forced Dialyzer **0 errors,0 skipped,0 unnecessary skips** in
**11.43 seconds**. The runtime ledger remained unchanged. Log
`/tmp/overalls-os-matrix-lilly-132-final.log` has SHA-256
`b193a17760c14c179670d55125cb0a4efd0c9e719286e22e8d112e6b97f786fb`.
The final frozen Porsche `mix precommit` then exited zero with **100 passed**,
seed **486608**, in **76.5 seconds** (6.4 async,70.1 sync), Covenant **4/4**,
and forced Dialyzer **0 errors,0 skipped,0 unnecessary skips** in **4.26 seconds**.
Log `/tmp/overalls-os-matrix-porsche-132-final.log` has SHA-256
`45ab9b63cb56da8bdcc80d9fc2a8bbbdecb2fc8f3e15b2993d5b8e8e327ddbdc`.
The four-consumer ledger verified unchanged after all four full gates completed.

The same final source's two evaluated host catalogs select the seven exact
immutable image paths already bound by the artifact custody receipts. Actual
small manifests also passed `OverallsProtocol.validate` with canonical IDs
NixOS `92114604`, Ubuntu `8d468c67`, Arch `8ab89c2d`, AlmaLinux `bed87c33`,
FreeBSD `d141e426`, OmniOS `98b23b79` and Windows `8ca0a11f`. The audit reuses
prior full-artifact custody only where the immutable store path is unchanged;
it does not repeat large-disk hashing or any guest/runtime execution. The
standalone validator emitted one unused unloaded-module reference warning;
all manifest validations completed with exit zero. Receipts and SHA-256:

| Receipt | SHA-256 |
| --- | --- |
| `/tmp/overalls-final-seven-selected-paths.json` | `110d6eacb874d3f4dde9e82ef80868dd8030cc7dc4d1306dc26bdad59897805e` |
| `/tmp/overalls-final-seven-identity.json` | `82d42c95c930bc5632a0ea768a5ad2f7ed5135cb4fadb187ca83d48ca14983ef` |
| `/tmp/overalls-final-seven-identity-bindings.json` | `3af2025af850b8cba44a62d95878777904f41ba90f6f826827365db817d38f5a` |
| `/tmp/overalls-final-seven-lifecycle-applicability.json` | `85fef32a62d712a71b51a6fc2cb3187169e441ab7b01334fa776ea025a9f36c3` |

The four historical completed lifecycle records remain image-applicable for
their exact selected NixOS, Ubuntu, FreeBSD and OmniOS artifacts at their
recorded revisions. This identity proof does not establish the final control
plane's runtime acceptance. The later current-image Windows, Arch and AlmaLinux
lifecycles are recorded below; their results remain bound to their own execution
revisions.

### Strict SSH warning classification

The fresh repaired Windows image reached readiness and its same-VM diagnostic
returned exact Server 2025 edition/build 26100 with exit zero. The original
strict attempt remains failed because stderr contained the stock three-line
OpenSSH non-post-quantum key-exchange warning. Byte comparison identified that
exact warning with LF and CRLF endings; no arbitrary stderr is admitted.
The reviewed runner now recognizes that exact Windows-only warning, alongside
empty stderr and the existing native SSH login event. Immutable attempts record
one closed `stderr_classification`: `none`, `native-ssh-login-event`,
`windows-openssh-pq-warning` or `unexpected`, plus the existing digest and length.
No raw stderr is persisted. The client changes no SSH algorithms, warning flags,
trust settings or guest image. A warning is not post-quantum transport evidence.
Nonzero exits, timeout, wrong exact OS output, changed/truncated/repeated/extra
stderr and the same warning from every other OS family still fail.

27 runner tests passed, including both accepted line endings and the refusal
cases above; the pinned all-files Ruff, Ruff format and ty hooks passed again.
The final checks log `/tmp/windows-pq-warning-harness-final-checks.log` has
SHA-256 `30ee3f9c1ecce5a15612083fa3cf4e16e96da538c3e28bfaa339526a1e565d93`;
all-files static log `/tmp/windows-pq-warning-harness-full-static.log` has
SHA-256 `b5695d3f70cb508283675778bac5a7500dffdf3dc53f79c8dbd255d93873d6ff`.
These controlled tests establish the classifier boundary only. The original
Windows failed attempt is preserved.

The new explicit `windows-profile-qualified` stage then passed on the fresh
exact `8ca0a11f` image and original UUID: create/readiness, strict authenticated
CLI SSH with exact Win32NT/Server 2025 edition/build 26100, stop, an independent
current-owner stopped-state checkpoint, restart, repeated strict SSH at
`windows-profile-restarted`, and terminal deleted cleanup. Both hosts remained
healthy at `132bc28b5`. The immutable summary
`/tmp/porsche-20261018-103842/windows-qualification-summary.json` has SHA-256
`db17809c7cdf54d2027fa36a03b598e9ef0b41be31efb33ae52733aa94970020` and
binds the individual receipts, artifact custody and exact stock warning proof.
Warning custody `/tmp/porsche-20261018-103842/windows-stock-warning-custody.json`
has SHA-256 `7eb7cf0c30c19513efb6930bcb2eeeb290a3433704804d67f291db1f59792084`.
This is the fifth separately qualified OS family. It establishes the recorded
create, strict SSH and lifecycle outcomes only; terminal, executor, workspace,
storage growth, native isolation and physical recovery remain separate.

### Foreign Linux PAM helper repair

The exact preceding Arch/Alma images both reached create/readiness, but their
strict personal SSH closed during authentication. Arch's boot-bound diagnostics
found working NSS/startup, PAM account refusal and missing compiled
`unix_chkpwd`. Alma has the same SSH symptom and shared immutable helper
omission; no independent Alma PAM root probe is recorded. Both owned
fixtures were ordinary-deleted. The shared builder now installs only the
pinned PAM helper at `/run/wrappers/bin/unix_chkpwd` through a root-only,
argument-free oneshot, with regular root-owned04755 runtime bytes and immutable
root-owned0555 source. Exact root-owned0755 parents and destination custody
are checked before copying; SSH requires and follows helper success. Key-only
policy, account expiry, roster/private login receipts and nosuid mounts remain.
Pinned PAM1.7.2's root account caller sets real UID0 before helper execution;
this grants no direct unprivileged setuid elevation under nosuid.

The final eight-file implementation and actual unit/filesystem/isolated VM
checks passed. The maintained VM gate records missing-helper9 → repaired0,
expired13, password-change12, unknown10, exact bytes/ownership/mode,
idempotence and twelve unsafe/argument/nonroot refusals. vmTools projects the
source store UID/GID to65534, so the disposable chroot overlays a byte-identical
root-owned0555 source; the actual final-image check separately verifies source
root ownership. Its immutable receipt
`/nix/store/91ikl29mjkway8h0djrvdw96p01kmk3k-foreign-linux-pam-helper-runtime/receipt.json`
has SHA-256 `792400d714a963c0842c11fd91ef0d8aa22ab4f611c0ccaa7128e2b57cd81305`.
The pinned Python format/lint/type gates and contract structural checks passed.

Exact rebuilt Arch image
`sha256:99fa9876f927fe02dbc2151e01f35b73d6f381b646fe8b924ade5d467667fefb`
and Alma image
`sha256:473f958974b821d2b8e13b11c6fb28206aa64eddbe743325359433215578e559`
passed actual artifacts, native Protocol and independent canonical-ID checks,
plus forced Dungarees rootfs/package rebuilds with equal content hashes.
`/tmp/overalls-pam-helper-artifact-receipt.json` has SHA-256
`4331461635c779b3d670300489ecc3021632820bcbbeb126135361a24ef07ca2`
and binds exact sources, caller evidence, installer and all artifacts. These
results do not establish fresh guest SSH/sudo, distribution boot or lifecycle.
Architecture impact: repair of accepted owned PAM runtime under ADR-0190;
no new host service, protocol, capability or deployment placement.
The exact immutable root helper/SSH units also passed the pinned systemd261.1
image parser with no diagnostics or service starts for both images; receipt
`/tmp/overalls-pam-helper-unit-parser-proof.json` has SHA-256
`d10f9bc90d0a084f44e849c8158a7e805582c80c883f0e7a448b47139dd26301`.

### Fresh helper-fixed Arch lifecycle

Run `/tmp/porsche-20261018-114223` completed the exact Arch
`sha256:99fa9876f927fe02dbc2151e01f35b73d6f381b646fe8b924ade5d467667fefb`
lifecycle on the original fresh VM `bd53747c-ca57-423b-b4e5-d91a1e619d8c`:
create/readiness, strict personal-account CLI SSH, reviewed read-only sudo/helper
checks, stop, an independent current-owner stopped-state checkpoint, restart,
repeated strict SSH/checks and completed deletion. Host health required the
merged `e8f3e5457` source or its reviewed `8428a676` descendant with unchanged
catalog selection. The stopped checkpoint has SHA-256
`79e8416d09a6a4ee2dcb67184ed4e9371080653ee323d8e153b3c93d4b134009`;
`matrix-helper-fixed-cleanup-arch.json` has SHA-256
`48430f158097689a8a75b8d21716617352725017103fd8f1a9f3c90a942907e7`.
The initial and restarted read-only smoke checks observed the same managed
nonroot UID/GID, `sudo -n id -u` equal to 0, exact private sudo-policy custody,
active helper service, root-owned 0755 parents, a regular root-owned 04755 runtime
helper and byte identity with its immutable root-owned 0555 PAM 1.7.2 source.
The runtime mount was nosuid; no effective helper setuid elevation is claimed.
Initial/restarted smoke receipt hashes are
`0cef4f01160a06e918221e28acb1c7c1603d204642b51d1c199a9aa04c638ea2`
and `854c7c08a74147c5228ad018686e95ea99623acbd1019cebf048c54a61d4b09b`.
Two retained pre-stop holds did not create another VM or replace failed OS
evidence. This is the sixth separately completed family lifecycle. It does not
establish revocation, terminal/executor/workspace, growth, isolation or physical
recovery. The later Alma result follows; the fresh OmniOS checkpoint journey
remains separate at this checkpoint.

### Fresh helper-fixed AlmaLinux lifecycle

The same `114223` ledger completed the exact AlmaLinux
`sha256:473f958974b821d2b8e13b11c6fb28206aa64eddbe743325359433215578e559`
lifecycle on VM `ed47f904-9ba6-442e-a733-106317060ce7`: create/readiness,
initial strict personal-account CLI SSH and reviewed read-only sudo/helper
checks, stop with a separate current-owner stopped-state checkpoint, same-VM
restart, repeated strict SSH/checks and completed deletion. Healthy deployments
and the exact seven-image catalog were checked around the journey.
The stopped checkpoint has SHA-256
`2342ff60b13dd50fbddcf00e16d7bd72bfdf84a0b0710b60ef27c8ef3e4508a4`;
`matrix-helper-fixed-cleanup-almalinux.json` has SHA-256
`0a8a04170eafb7cd09d40564380ad266d80e3ff15d27bdf832c786655ff4012e`.
The initial/restarted smoke hashes are
`6fc6ace4c02fd126122973349c9f3675d3504eacbef66198bc9179a54b608919`
and `c2bc4799c08a72ed1d265372aa22c07d2e025cf1b2a1bf2ffa05b69857231fbe`.
They establish the same bounded observations as Arch: managed nonroot identity,
numeric sudo UID 0, reviewed policy custody, active helper service and exact
root-owned helper/source bytes and modes. Runtime mounts remained nosuid.
This is the seventh separately completed family lifecycle. The fresh OmniOS
journey below subsequently adds the independent stopped checkpoint missing
from its earlier lifecycle evidence. No terminal, executor, workspace, revocation,
growth, isolation or physical recovery result follows from these SSH/smoke
checks, and no independent historical Alma PAM root probe is inferred.

### Fresh OmniOS independent stopped checkpoint

Run `/tmp/porsche-20261018-122228` passed a fresh exact promoted OmniOS
`sha256:98b23b7931bc52d55b3c5b38cc20c97c1c967be96cf301940f88b01c715530d8`
16 GiB lifecycle on VM `26c53b61-f59a-4e2e-acad-5cfabb291126`:
create/readiness, strict initial personal-account CLI SSH, stop, an independent
current-owner stopped-state checkpoint, same-VM restart, repeated strict SSH
and completed deletion. Checkpoint
`matrix-checkpoint-omnios-checkpoint-stopped-omnios.json` has SHA-256
`9b7562fd05f0e970460a2fe361c3eadd2c78e2081c0c3b387ea5635457d4ef55`;
`matrix-omnios-checkpoint-cleanup-omnios.json` has SHA-256
`7e8f678db35206256d8e68b046986fa3fcfe353927d43f81bd5175329654d7ab`.
The source-health holds after creation retained the same VM and attempted no
SSH/stop before the accepted deployment gate recovered. They are separate
from OS failures; no cause is inferred for the earlier updater verify timeout.
Accepted host observations span reviewed `8428a676`, `e5234f67f` and
`d0eaddbc9` descendants of required `e8f3e5457`, with unchanged exact image
selection. At 12:43:41 UTC the post-deletion observation records both hosts
healthy at `d0eaddbc9f99416e785b82eb277cae55d2dfba9f`, zero updater failures,
passing live checks and the exact seven-image catalog. Its receipt
`deployment-omnios-after-delete-124341.json` has SHA-256
`b8350da70e228cb0866270afa093e9e12698ace8d5cadc5bb864ea033188b87d`.
This closes the independent owner-checkpoint gap through a new journey;
the historical `091638` record is unchanged and gains no missing observation.

### Seven-family lifecycle milestone

The typed closed aggregate
`/tmp/porsche-20261018-114223/seven-family-lifecycle-evidence.json` has SHA-256
`c77e33863fba694ea1bd6b5122f5d83d71194e377b838c9da112031c0199f6cf`.
It validates 49 identity-bound stage receipts across the seven selected families:
create/readiness, strict initial SSH, stop, independent stopped-owner checkpoint,
same-VM restart, strict repeated SSH and owned completed deletion for each.
It separately binds four read-only helper/sudo smoke receipts for Arch/Alma,
the exact final catalog and 17 historical failures/health holds. Each receipt
retains its path and hash; old failures and the original two historical cleanup
requests remain separate scopes.

This completes the scoped seven-family SSH/lifecycle milestone at distinct times
and recorded revision contexts. Ledger preparation times do not establish exact
execution timestamps, and historical revision context is distinct from activated
host revisions actually observed during newer journeys. Current exact catalog
equality binds those historical results only to unchanged immutable image IDs;
it does not rehash disks or replace independent artifact custody. No simultaneous
same-revision seven-OS run is claimed.

The broader custom-kernel plan remains partial: reproducible native full-image/
kernel assembly, including OmniOS native linker/ZFS assembly; wrong-CID injection;
reset/DMA stress; direct native peer/host isolation; interrupted growth;
physical power-loss/recovery; relocation; and broader fleet/capability/revocation
acceptance remain open. The immutable promotions and separately recorded native
scenarios retain their existing scope. ADR-0190 stays accepted/partial,
ADR-0191 stays accepted/partial, and ADR-0171 stays proposed/partial. Inception
is known broken and excluded.

### Separate historical cleanup recovery

The two earlier `101111` diagnostic fixtures retain their original cleanup
requests, separate from the seven successful lifecycle records: Arch
`05406661-2b26-4d91-97fc-29d1cf87cd48` and AlmaLinux
`abe3258e-86a0-4956-adeb-2629720d5c37`. Guarded manual retirement of their
original idle rootless namespace holders passed two fresh complete idle proofs
and used normal SIGTERM on the exact original Podman API service. The original
PIDs, namespaces and open-file holders were confirmed gone. No force, SIGKILL,
lazy unmount, Podman CLI, storage removal or database writes were used.
The journal `/tmp/overalls-retirement-86636242fb1140b88683283e56999906.jsonl`
has SHA-256 `4bbd78bce4c2e2dff9f9d50296c530b0a1136264e84659ec6bc3cc80183053b9`.
Guard/custody removal followed confirmed inactive/dead/success state, and the
original configuration was restored.

Alma's original cleanup request subsequently reached deleted. Before Arch's
retry completed, new external rootless Podman activity created a different
namespace that retained its dataset; these are new identities rather than
surviving retired PIDs. Arch's original request remains accepted at this
checkpoint, with no replacement intent. No active workload was stopped, and
the operator did not restart the API service to produce that activity. This
manual recovery does not establish automatic cleanup for arbitrary holders;
the current seven-family milestone does not imply these separate old requests
are complete.

### Final browser layout evidence

The first final-source browser attempt failed the existing grid assertion on
the machines list. Its log `/tmp/overalls-os-matrix-132-browser/probe.log` has
SHA-256 `281b9195aff7d94033426a0b9024901da06e5f88657b2b9f14ab8400ac23b048`.
Fresh diagnostic fixtures reproduced editor/pin offsets of 0.125/0.15625 px;
computed geometry showed that the inherited character-unit row gap accumulated
against the half-line grid. The narrow CSS repair retains a one-character
column gap and uses an exact half-line row gap, preserving grid tolerance and
all controls. The actual asset build, Monospace structural gate and
TypeScript/presentation checks passed; log
`/tmp/overalls-os-matrix-132-browser/css-gates.log` has SHA-256
`c767b0960d8668a4c6e7ebc704a646c40833626930b4120c925270a2d6478f35`.
An on-page comparison removed those offenders at 1,440 and 1,000 px. An extra
800 px exploration still found responsive border offsets; that width is outside
the full probe's 1,440/390 px geometry scope and is not claimed fixed.

A separate pre-repair diagnostic completed 61 main-route screenshots, then
timed out selecting the theme before thread checks. Its exact cause remains
unresolved; log `/tmp/overalls-os-matrix-132-browser/probe-diagnostic2.log`
has SHA-256 `3f92b83ed12f4b0bd5110332507d178d30afff646c2ce1722f928c6b51987334`.
The post-repair original probe also completed the 61 main-route screenshots
before a later grid assertion failed in the thread phase. These remain failed
full browser attempts; the machine-list correction does not establish a full
probe pass, packaged-browser acceptance or guest execution.

Later focused checks found three additional layout causes: whitespace-only
empty thread workspace boxes, a20ch minimum field conflicting with the narrower
activity grid, and a2px iframe border shifting its viewport off-grid. Narrow
CSS corrections hide only element-empty workspace boxes, let the existing
grid own field width, and preserve the visible2px terminal frame with an inset
outline. The actual lazy disclosure populated its owned machine terminal
iframe and rendered inner content; computed outline/offset and inspected
screenshot confirm its visible frame without claiming guest execution.

The fixture also bound a synthetic thread to a random machine key instead of
its VM's actual admission key. Production `valid_binding` correctly refused
that transcript. The fixture now uses the actual key and checks event kinds
through the public retained-transcript read before serving. Its source digest
is `0d19d584c400905d9248d08e8cd53afc7c037e7caaa47324c0c92c145c2a22f1`.
The next untouched probe reproduced an open palette whose composer ARIA state
reset false after validation. Focused DOM confirmed open=true/expanded=false;
the two-line JS correction restores state/query/focus even if the dialog
remains open and only calls showModal when closed. Assets, Monospace,
TypeScript, contracts and logging gates passed; log
`/tmp/overalls-os-matrix-132-browser/palette-fix-gates.log` has SHA-256
`eee9ee2d389f7a901cce337175dd18004f25350528d78d2add55b3abae6f1257`.
These preserve production permissions and the existing browser assertions.

The original, unmodified full browser probe then exited zero with153 screenshots:
both themes/mobile, grid/overflow/contrast, self-hosted font, no external
resources or browser errors, drafts/public docs,32 thread route/theme/viewport
combinations,36 collaborator role/state/theme/viewport combinations, sharing,
live revocation and unrelated-account refusals. Log
`/tmp/overalls-os-matrix-132-browser/probe-final8.log` has SHA-256
`458895226c5fdc47e82715b99a7cdeba71980b4799fd21da67498fbe1b5c2d18`.
This is local synthetic fixture browser evidence, separate from packaged
browser, actual guest execution, and the earlier frozen runtime test ledger.

## Verification boundary

After checkpoint `002391dd2`, integration of upstream `d18a6f11e` imports
three Enrico property files and its prior receipt update. Eleven property
declarations now explicitly select one CI case; assertions and fixed loops
remain, while inner compatibility `max_runs` values do not preserve former
random counts. This narrows exploration without adding a passing Enrico result.
The four-consumer runtime ledger still verifies unchanged and excludes Enrico.
The import preserves production behavior, deployment placement and accepted
architecture; ADR-0191 remains partial. Reviewed merged-source governance
receipts replace the conflicting historical receipt metadata.

The later upstream `e5234f67f` import changes only Brady cleanup and
Porsche/Ziggy Hegel test bindings plus receipt metadata. It changes no
production runtime, image, protocol or placement. The changed Porsche
`host_certificate_negotiation_property_test.exs` passed its separate pinned
one-property execution, retaining trusted, foreign-CA, foreign-name and absent
trust cases. Log `/tmp/overalls-os-matrix-e523-porsche-property.log` has SHA-256
`3b5955f13a539c6d49ca2ff5e2a85adae057201f7570e3b836b00fa1d2a41e4a`.
The frozen prior 100-test Porsche result does not verify this changed test
source; no new Brady or Ziggy execution is claimed.

The subsequent `d0eaddbc9` import changes only Lilly's transfer test and review
metadata. The test also admits the existing closed `stream_consumer_failed`
observation when refused SSH closes the pipeline, retaining zero initial
progress and actual transfer-lock reacquisition assertions. The runtime's
typed failure domain, helper-exit mapping and lease-release path are unchanged.
Its separate pinned transfer-file execution passed five tests in 1.1 seconds;
log `/tmp/overalls-os-matrix-d0-lilly-transfer.log` has SHA-256
`c36a07fe6684ef076b949449972a238fb136d5ddf56e5b61bee3b37b8e2cb363`.
This verifies the changed test file, separately from the earlier frozen
610-test Lilly gate. No native transfer, storage or recovery result follows.

The native and Windows evaluation assertions inspect generated artifact/service
configuration; they do not start a guest. The pinned Python 3.13 runner suite
passed all 24 tests with
`python3 -m unittest discover -s scripts/test -p test_porsche_acceptance.py` in
`devenv shell`. These tests exercise runner refusal, receipt recovery, timeout
cleanup, strict SSH configuration, output privacy and OS-oracle behavior with
controlled responses, including accepted UUID retention after failed or uncertain
creation. Ruff and ty passed separately for the runner and tests.
The handbook scenario ledger distinguishes these checks from live acceptance.
ADR, handbook, generated-reference, coverage and topology gates check
documentation consistency only. Remaining gate results are recorded at
completion; the open runtime requirements above remain open regardless of
those results.

## Forward callback and generated-fixture repairs

The `7c323f197` checkpoint was pushed with the startup-mail and Customer
private-service repairs. A read-only production observation at **22:32:58 UTC
on 2026-10-18** subsequently found Overalls healthy at `98bd5da6` and Dungarees
healthy at `ccad2528`, with no updater failure on either host. Both reports were
about one second old and carried all six inventory keys, at sequences 92 and
416 respectively. Unexpired route counts were zero on Overalls and six on
Dungarees. Marshall had started at 22:31:27 UTC. Separate local and remote
checks at 22:32:05 and 22:32:29 UTC found Lilly and Audi DNS/gateway readiness
true. These public-field observations are retained in the tool transcript;
no manual restart or production mutation was used.
The ordinary Windows CLI then passed through the normal Overalls proxy in
**0.636 seconds**, exit zero, checking the fixed marker with strict certificate
trust. This establishes that observed activation, inventory convergence and
ordinary Windows routing path; it does not qualify browser/editor access,
native isolation, recovery or the complete guest OS matrix.

The later Marshall Covenant run passed **35 of 36 tests**, seed **336541**, in
**3.9 seconds** (`/tmp/osmatrix-marshall-forward-contracts-types.log`). Its
callback replay failure exposed a deterministic nullable-attempt guard: a
successful connection clears its active attempt ID, then strict `and` received
`nil` and the exception became `unavailable`. The forward guard explicitly
requires a non-nil attempt before the unchanged state, login, generation, phase
and expiry checks. Existing Covenant, fixed callback and generated replay
assertions retain `invalid_callback` and passed in the focused timing run
below. This restores ADR-0202 and ADR-0186 without changing authority or protocol.

The earlier Pins property failure followed a SQL sandbox owner exceeding its
120-second ownership limit; Teams' HTTP history exceeded the default aggregate
60-second ExUnit timeout. The fixture repair creates a sandbox for each
generated case and replay before its gateway, host and account rows, then
releases that owner before the next case.
All three Pins runners and both generated Teams runners retain their full
100-case budgets and existing state/refusal oracles. Fixed Teams tests retain
their ordinary sandbox setup. The focused timing-only run passed **23 tests**,
seed **52647**, in **419.4 seconds**, including the callback Covenant and
history regressions, all three Pins properties, both Teams generated tests and
sandbox regressions (`/tmp/osmatrix-forward-followup-regressions.log`). It
measured Teams' full HTTP history at **30.5206 seconds** and Pins' full
ordered-set history at **276.0067 seconds**. The pinned Mix
runner implicitly enables `--trace` for `--slowest 8`
(`/tmp/osmatrix-test-help.log`), so this execution does not qualify finite
ExUnit deadlines. Only the Pins ordered-set history now has a finite
**600,000-millisecond** aggregate timeout, approximately twice its measured
duration; the other Pins tests retain the 300,000-millisecond module timeout,
each generated case retains its 120,000-millisecond SQL ownership deadline,
and Teams retains the 60,000-millisecond default. These are test-isolation and
bounded test-budget repairs under ADR-0191. The required complete Marshall
`mix precommit` gate, without `--trace` or `--slowest`, remains pending and
will verify these tests with their finite deadlines. No production failure or
native guarantee follows from the test-fixture repairs.

The Windows browser probe reached HTTP 200, the workbench and its native
command, then failed its existing workspace-equality assertion: the `folder`
query held a Windows filesystem path that Code OSS parsed as URI scheme `c`.
The probe now sends `/C:/workspace/overalls-editor-acceptance-<run-id>`, a path
under the configured remote authority. The exact workspace and native command
assertions remain unchanged. This corrects probe input syntax; it changes no
production authorization surface or editor admission contract. The rebuilt
harness is
`/nix/store/nm4yzal1g32fp4msplfha6xi42l148jr-overalls-windows-editor-acceptance-harness-0.1.0`
(`/tmp/windows-editor-harness-uri-build.log`). Whole-repository Python Ruff
formatting, Ruff and ty gates passed in the pinned environment
(`/tmp/windows-editor-python-gates.log`). The native retry ended at an SSH EOF
before readiness (`/tmp/windows-editor-native-browser-uri.log`); it is not a
browser pass. The stock-fixture probe also remains separate from qualification
of the exact immutable candidate image.

The stable forced Marshall Dialyzer run exited **2** with **50 total errors,
35 skipped and zero unnecessary skips**, leaving **15 findings**: one prompt
pattern match, one GitHub guard and 13 generated Gettext opaque-call findings
(`/tmp/osmatrix-marshall-stable-forward-types.log`). Its compiled scope is the
pre-pull checkpoint. An earlier attempt lost a compiled `Collectable` input
during overlapping compilation. No typing pass or complete Marshall gate is
recorded for this diff.

The merged Marshall catalog checker exited zero with **invalid=0** in every
reported catalog (`/tmp/osmatrix-incoming-marshall-catalogs.log`); empty and
source-equal documentation entries remain explicitly incomplete. Porsche's
catalog regression passed **3 tests**, seed **691955**, in **0.05 seconds**
(`/tmp/osmatrix-porsche-catalogs-retry.log`). These results establish bounded
catalog/template checks, not linguistic review, packaged browser or native
Porsche acceptance.

## Trunk integration through `c89335a2a`

The `a22c3ca7` callback, generated-fixture and browser-probe checkpoint was
committed before the requested normal pull. The pull adds substantive Android
source under accepted, partial ADR-0206, alongside catalog translations,
localized SSH-key and administrative flashes, canonical GitHub ADR links and a
suspension fixture that owns its VM and route. The GitHub non-nil attempt guard
survives; incoming `Ash.Error.Invalid` handling and broad callback exception
classification now return `invalid_callback`. This changes failure
classification, not authorization. It does not establish that infrastructure
failures are distinguishable from invalid callback state.

The Android additions comprise a software-emulator guest recipe and machine
fixture, a `linux_android_v1` capability row, relay-preface and bounded-stream
codecs, Lilly's display connector, signed Marshall display tickets, relay state
and workspace controls with a browser-hook source. The upstream
[Android review](2026-10-18-android-firecracker.md) retains partial status and
open native Firecracker and authenticated-display acceptance. These additions
do not qualify another production guest image or widen the recorded native
editor matrix. The constructed version-4 Linux artifact does not yet carry the
new Android capability identity through admission; the hook is not registered
in the main application and its `/android-display` endpoint is not connected.
Lilly's TCP target also does not establish a working path to the guest's
loopback RFB/vsock bridge.

Read-only review found concrete source defects pending forward repair: the
viewer branch of `DisplayRelay.handle_call/3` returns its updated state as the
reply while retaining the old state, contrary to its new `:ok` assertion and
multiple-viewer contract. The hook's full-canvas RGBA size exceeds its own
bounded-frame maximum, and its input header uses generation and kind zero,
which the protocol codec refuses. The stream module also has malformed
`@cc` label metadata. These are source findings, not observed runtime results.
The incoming handbook's generation-change revocation statement describes an
intended obligation; the relay has no rollover API or lifecycle integration.
Generation rollover, lease expiry/reacquisition, browser rendering, native
transport and persistent emulator acceptance remain unverified. The Hegel
lifecycle property uses a standalone model, and the emulator fixture uses its
own service rather than the production image/relay path.

The checkpoint's 23-test timing run, Python static/build results and public
rollout/ordinary-CLI observations retain their original scope. The forced
Marshall typing process started before the pull and covers its compiled
checkpoint only; it cannot verify the incoming Android or localization source.
No merged full Marshall, Lilly or protocol gate is recorded. Shared protocol
changes require the library and both consumer gates. Incoming Hegel and NixOS
machine tests are present; their presence is not a recorded passing execution.
The upstream Porsche 108-test/zero-Dialyzer result remains explicitly at
`1f79f63e6`, and translation additions establish neither linguistic review nor
all-locale browser acceptance.

## Additional trunk integration through `2d598e3e2`

The next normal pull adds an Android display WebSocket adapter and authenticated
upgrade route, hook registration, and bounded GitHub `Link` response headers
for the existing private-endpoint rewrite path. The preceding disconnected
hook/endpoint findings describe `c89335a2a`; the new source advances that
plumbing without establishing native integration or passing browser evidence.
Read-only inspection finds that the hook registration still lacks its module
import, so browser initialization requires a forward repair. The new socket
adapter also does not establish current machine generation, claim-mode binding
or a shared machine controller lease. Earlier viewer, framing, artifact and
transport gaps remain open. These are source findings, not executed results.

The GitHub allowlist regression assertion is present, with no new execution
record. No new Android test or native/browser acceptance result accompanies
this range. Earlier checkpoint test/type evidence retains its original scope;
merged consumer gates and the normal finite-deadline Marshall gate remain
pending. No deployment or native capability qualification is inferred from the
pull.

After merge `2ce5d0c4`, the application imports `AndroidDisplay` from its
existing module before referencing it in the hook registry. This closes the
missing-import source finding without changing authorization, display
contracts or accepted architecture; ADR-0161 and partial ADR-0206 remain
unchanged. Startup smoke and the broader feature qualification retain separate
evidence scopes.

## Additional trunk integration through `31002e49f`

The next pull adds signed-generation equality at the Android WebSocket upgrade,
generation propagation in the browser-hook interface, and a bounded host-stream
bridge with two regression tests present. It also sends the terminal empty
chunk for Galileo's existing GitHub streaming response. The `910e1622` browser
hook import repair survives. These are source changes; the earlier missing
claim-generation binding is historical, while current machine authority,
shared controller lease, native transport and browser acceptance remain open.
No new merged gate or native execution result is recorded.

## Forward verification repairs after trunk integration

The next forward patch addresses the recorded typing and relay findings while
preserving accepted decisions. Prompt audit selection now matches the returned
`WakeRequest` shape, and GitHub admission removes a redundant nullable-user
check after `Security.lock_user!/1`; deleted-user and current-login refusals
remain. Explicit `>=` and `<=` comparisons in the Android socket's bounded
integer guard preserve the same accepted interval. These restore existing typed
contracts rather than changing authority under ADR-0002, ADR-0199 or ADR-0202.

`MarshallWeb.GettextPlural` uses the official Gettext plural callbacks. Generated
backend code retains the plain locale/header context, while runtime callbacks
reconstruct the Expo opaque value through `Gettext.Plural.init/1`. Explicit
catalog rules, Arabic's six categories, missing-header territory fallback and
full generated headers are retained. Three semantic regressions are present,
including an explicit English header whose zero case differs from the built-in
rule. Every plural selection reparses its header; there is no runtime cache,
new dependency, catalog change or added Dialyzer exclusion. Runtime and typing
results for this adapter remain pending; ADR-0201 is unchanged.

The Android viewer attachment now replies `:ok` while retaining the monitored
viewer in relay state. Its regression processes are supervised for cleanup.
The stream contract's label metadata and adjacent Nix contract block separation
are repaired without changing frame limits or emulator flags. These close the
specific source defects identified above; shared controller custody, current
machine generation, artifact admission, native transport and browser rendering
still require separate implementation and acceptance under partial ADR-0206.

The native-admission regression now asserts the exact 13-key capability map:
seven previously qualified native capabilities remain true, while editor,
Inception and all four Android flags remain false. This replaces the old
assumption that every non-editor/non-Inception capability must be true; the
raw and wrong-image refusal assertions remain. No capability is widened.
Lilly's two incoming Android network modules and their target test receive
formatting changes only.
The initial protocol run has reported two failures against the older loaded
capability assertion, and Lilly's first gate stopped on formatting; final-source
reruns remain pending.

The Windows browser fixture now accepts a broker receipt whose SYSTEM-only
allow entries are inherited from its protected SYSTEM-only parent. It still
checks SYSTEM ownership, effective foreign allows, reparse points and unsafe
ancestors, and includes disposable inherited-receipt admission and foreign
Administrators-read refusal oracles. This changes fixture validation only;
the product custody script, Rust broker and original installed broker remain
unchanged. The rebuilt harness is
`/nix/store/16rgky75dbqrifks2nj9qlc0jkns785q-overalls-windows-editor-acceptance-harness-0.1.0`
(`/tmp/windows-editor-harness-receipt-build.log`). The native receipt check
passed the disposable inheritance/foreign-read refusal oracles and the real
inherited receipt, with `broker_unchanged=true`
(`/tmp/windows-editor-receipt-native-cases2.log` and
`/tmp/windows-editor-receipt-native-cases-result.json`). The foreign-read case
requires the exact `fixture_receipt_foreign_access` refusal. These receipt
checks establish neither PTY nor browser/recovery acceptance.

The Lilly Windows machine fixture adds explicit `editorCandidate` mode, which
requires agents and provisions four GiB guest RAM within a 6,144-MiB host
budget. That mode requires the exact version-7 `windows-editor-v1` manifest and
version-4 bundle editor descriptor at first start and restart. Ordinary
version-5/bundle-2 Windows expectations remain separate. The exact candidate
run is pending; its intended scope is trust, bounded readiness, root ConPTY,
workspace transfer, a new boot UUID and cleanup. It does not establish ordinary
CLI, browser-editor acceptance, image promotion or physical isolation.

The earlier asset build exited zero
(`/tmp/osmatrix-merged-browser-assets.log`), but its mixed compile/source scope
predates this forward patch and includes the earlier range-step warning.
It establishes asset construction for that scope only. Protocol, Lilly and
Galileo gates and focused Marshall checks are in progress; no new full gate,
forced typing, native candidate or complete browser pass is recorded here.

### Stock Windows browser stage and broker restart failure

The latest stock-fixture `native_browser` stage passed: the workbench and native
extension command ran, the saved-file oracle passed, a real PowerShell PTY
appeared in xterm, and the exact worker snapshot matched. The subsequent
automatic broker-restart stage failed after 100 seconds
(`/tmp/windows-editor-native-browser-network.log`). The task remained enabled
with its original restart settings, but no broker/listener returned and its
last result was `0xFFFFFFFF`; scheduler history was disabled. The worker-loss
stage was not run. Restoring the unchanged original task was cleanup, recorded
with `definition_unchanged=true` and `automatic_recovery=false`
(`/tmp/windows-editor-broker-cleanup-restore-result.json`). It is not recovery
acceptance.

The forward `start-editor.ps1` repair preserves native success as zero and maps
every nonzero native result, including `-1`, to task failure one; exception
failure remains one. Custody checks and scheduler settings are unchanged. The
pinned PowerShell parser passed (`/tmp/windows-editor-launcher-parse.log`).
Whether this normalization repairs the observed automatic restart remains a
hypothesis pending native execution. The exact immutable candidate currently
under Lilly qualification still contains the old launcher; stock-fixture
browser results and this source change do not qualify that image or establish
browser recovery, worker-loss recovery or production promotion.

## Additional trunk integration through `351b160de`

The reviewed incoming range is `589530ab..351b160de`. The resolved merge keeps
the forward callback, property-fixture, browser-path, typed plural adapter and
verification repairs recorded above. It takes the incoming explicit `>=` and
`<=` comparisons for the Android socket integer bounds and the shared terminal
string byte-length bounds. Both preserve their existing inclusive intervals
and malformed-input refusals; no wire schema, capability or authorization
contract changes. ADR-0002, ADR-0012 and partial ADR-0206 remain unchanged.

The Android software-emulator machine fixture explicitly supplies the pinned
JDK through `JAVA_HOME` and checks the actual emulator command line through
`pgrep`, retaining its no-acceleration and software-rendering assertions. The
suspension composition now takes only Audi enrollment/bootstrap before the
first guest HTTP scenario, then runs its own VM and route journey. This removes
the unrelated Audi guest/SSH journey from that fixture. Its native continuation,
paused-cgroup absence and interrupted-capture cleanup assertions remain present;
this merge does not record a passing Android or suspension machine execution.

At forward checkpoint `6b6f04c8`, the focused Marshall run passed **28 tests**
with normal finite deadlines, seed **327352**, in **12.9 seconds**
(`/tmp/osmatrix-type-repair-focused.log`). It covers Gettext plural and
interpolation semantics, Prompt and wake-property behavior, GitHub authorization
and Android relay state. Formatting also passed
(`/tmp/osmatrix-type-repair-format.log`). These are checkpoint-scoped results;
they do not establish merged-source full-suite, forced typing, native Android,
browser recovery or exact Windows candidate acceptance. The corrected protocol
assertion has received formatting only; its final-source gate and both consumer
gates remain pending.

No domain ownership, deployment placement or accepted architectural decision
changes. The frozen handbook already describes the relevant partial Android,
native editor, controller-custody and recovery boundaries; the checkpoint result
does not close those gaps. No handbook chapter or scenario-status change is
needed for these contract-preserving repairs and bounded evidence updates.

## Localization integration through `ee597fc1e`

The merge adds the `1e36beb3e` localization patch while retaining this branch's
typed plural adapter, callback and generated-fixture repairs, Windows fixtures
and handbook reference history. Human HTTP refusals now use the existing
Gettext integration; their status, newline, generic redaction and privacy
branches remain. Successful scripts, downloads, manifests, checksums, trust
JSON, CSV and raw Git bytes keep their machine format. Porsche translates
reviewed outer labels, statuses and refusal guidance while its JSON branch,
identifiers, unknown keys and nested values retain their existing representation
and escaping. The pin guidance retains literal `unpin MACHINE` in all catalogs.
No authority, protocol schema, domain ownership or placement decision changes;
ADR-0201 and ADR-0161 remain partial.

Successful account-language persistence now pushes `locale-updated`, and the
typed application listener reloads the document. The new JavaScript regression
uses a simulated event target; it does not establish real browser root language,
direction or repeated-save acceptance. The incoming
[localization review](2026-10-18-localization.md) explicitly retains the earlier
all-English browser trace as no language-transition evidence. Its Porsche
110-test/zero-Dialyzer result predates five wording corrections; those have
source/catalog review only. The new controller evidence remains `present` in
the scenario ledger. No linguistic, packaged-browser or native SSH acceptance
is inferred from these source changes or historical results.

The incoming 3,800-identity documentation extraction excludes this branch's
retained newer handbook reference text. Reconciliation of generated messages,
POT and all locale catalogs against the final handbook remains pending;
untranslated prose retains English fallback. It is deferred while the existing
Marshall gate runs its compiled `572a0ebc6` checkpoint. That gate cannot establish
acceptance of these newly merged source/catalog changes. The known duplicate
original and rewritten GitHub `Link` projection remains a separately recorded
source discrepancy, not a passing hostname-redaction claim.

Galileo's pending-version refusal property receives a finite 300,000-ms aggregate
timeout after the old full gate exceeded 60 seconds. Its CI profile still runs
100 cases, each covering six verified TLS combinations and a 50-ms no-replay
window, for 600 connections and 30 seconds of quiet windows. Version refusal,
transient draining classification, peer-observed pending requests and no-replay
assertions are unchanged. The rerun is pending; no fresh full-gate pass is
recorded. The three Android/terminal source edits accompanying this merge are
formatting only and preserve their template identifiers and authority checks.

The stock Windows fixture remains blocked after launcher exit normalization:
new browser connections were refused before navigation with broker reason
`custody`. A SYSTEM read-only discriminator could not open the exact named job
(`job_open=false`, error 2), while the previously inspected receipt root remained
live (`/tmp/windows-editor-job-custody-result.json`). This is a custody observation,
not proof of why the job disappeared or of a recovery repair. The earlier first
browser/PTY/save stage retains its scope; automatic restart, worker-loss recovery
and immutable-candidate promotion remain unaccepted. Handbook 17 stays unchanged;
its explicit native/editor/recovery gaps remain accurate.

The Windows Lilly fixture raises only observation, stop and delete command
budgets to a finite 1,800 seconds, matching its existing refusal probe. Every
invocation still verifies the full 64-GiB image; no digest check is skipped.
The exact candidate's first image/manifest/refusal phase took 1,071.11 seconds,
which motivates this verification budget without establishing lifecycle success.
The already-running immutable derivation retains its older driver and remains
in placement/start qualification; exact native lifecycle acceptance is pending.

### FreeBSD native wrong-CID injection

The FreeBSD wrong-CID gap now has native machine evidence. Firecracker stamps
host CID 2 on every frame it delivers, so a host cannot send a guest a
wrong-CID frame. A separately identified, test-only `GENERIC-OVERALLS-FAULT`
kernel appends `ovfb_fault.h` to the unchanged driver source. It exposes a
root-only `debug.overalls_vsock_inject` OID that passes one raw frame through
the same `ovfb_receive` path, under the same domain lock as the receive task.
The fault kernel has its own configuration hash and build identity, and the
production recipe asserts that `ovfb_fault_inject` is absent from its symbols.

Before the fault probe exposes its build token, it injects REQUEST frames to a
live listener with these CIDs:

- sources 4, 3, 0, 1, `u32::MAX` and `u64::MAX`
- source 2 with an upper 32-bit bit set
- destinations 2, 4, 0 and `u32::MAX`
- destination 3 with an upper bit set

It also injects one length-mismatched frame. Each of these must return
`EBADMSG` and leave the listener unreadable. A correctly addressed CID 2 to 3
REQUEST must then succeed and make the listener readable, which shows the
refusals happen at the decoder and not on an unreachable path.

`native-freebsd-wrong-cid` (derivation
`/nix/store/cvgbh3kpajp9rf4qcxlxyxfc0rh3rlxy-vm-test-run-overalls-freebsd-native-wrong-cid.drv`)
passed under nested KVM and the patched Firecracker 1.16.1. The test script took
192.4 seconds; the runner took 170.8 seconds. The run used fault token
`ade4982ba9bb4dbf28cc2ed9a7d61934cf15974b01d06d4a6886183a318f1421`, image
`f9cc0149627f650381dd39aca5cbf2742674ae32845955acc92c49958f363976`, firmware
`261c6d43…` and VMM `9815649a…`. The receipt has SHA-256
`a854e30edb03e68de75b7ec6525535053148237f83580f4c21392b297b891eaf`. The same run
also passed the ordinary token, CID 2/3, ABI refusal and nine-size exchanges.

This covers kernel-level CID validation for FreeBSD only. It is not evidence for
OmniOS wrong-CID refusal, malformed DMA descriptors, reset races, peer-VM or
physical-host isolation, or production admission. The production FreeBSD kernel
does not contain the injection OID.


### FreeBSD native reset race

The fault kernel now also exposes a root-only `debug.overalls_vsock_inject_reset`
OID. A write of 1 calls the driver's own `ovfb_config_change`, so the real
receive task sees an unexpected configuration change, treats it as an invalid
reset, fences every socket and stops the device. The OID never touches socket
state itself. Both test OIDs exist only in the `GENERIC-OVERALLS-FAULT` build;
the production recipe now fails if either `ovfb_fault_inject` or
`ovfb_fault_reset` appears in its symbols, and the fault recipe fails if either
is missing.

After the wrong-CID checks, the fault probe accepts one connection on port 1101
while the host streams 64 KiB writes into it from a reader thread. The probe
then injects 64 resets: the first must succeed, and later ones may only succeed
or return `ENXIO` once the device has stopped. The blocked reader must wake
within 5 seconds, and a new `socket()` must then fail with `ENXIO`. The guest
prints its verdict on the console. The host requires `OVFB-RESET-RACE pass`, and
then requires the ordinary probe port to refuse a new connection.

`native-freebsd-wrong-cid` (derivation
`/nix/store/f4zcmpsa85xay1lf2bipcj92sdpd8ngm-vm-test-run-overalls-freebsd-native-wrong-cid.drv`)
passed under nested KVM and the patched Firecracker 1.16.1. The test script took
220.5 seconds; the runner took 204.9 seconds. The run used fault token
`6a8a404e9963e355580076bc3549d8afc4e67002556659b0037f1eb0e2315e99`, image
`66e9d500dbee3bc01117c6ac0384607687ac7be6a541093b52fae0aa26b754d7`, firmware
`261c6d43…` and VMM `9815649a…`. The receipt has SHA-256
`ceaf0283dd47f599fd473f085e3123b1ea4f088e93649b932b3f0f8ae3a2fbf8` and records
`fault_injection`, `wrong_cid_injection_refused` and `reset_race_fenced` as true.
This run also re-passed the wrong-CID refusals and ordinary exchanges with the
new token, so it supersedes the `ade4982b` run as current wrong-CID evidence.

This covers FreeBSD's fencing when invalid resets race each other and live
receive traffic. It does not cover a valid transport-reset event racing traffic,
malformed DMA descriptors, OmniOS, peer-VM or physical-host isolation, or
production admission.

## Nix KVM OmniOS assembly and formal transport/reset gates (2026-10-20)

The manual OmniOS link/install procedure now has a Nix derivation,
[`omnios/assembly.nix`](../../../nix/domains/artifacts/guest/omnios/assembly.nix),
exported as `omnios-image-candidate`. It requires the `kvm` system feature,
boots the pinned stock r151050 image offline in QEMU twice over the serial
console, reguids the administration pool, has the guest's Solaris `ld` link the
nine kit modules and runs `native_image.py assemble` against a separate scratch
copy. [`check_assembly.py`](../../../nix/domains/artifacts/guest/omnios/check_assembly.py)
binds the extracted receipts to the kit build ID, pinned pool GUID, stock `unix`
digest and final raw disk. It also requires each module whose input objects equal
the promoted kit's objects to reproduce the promoted digest recorded in
[`promoted-assembly-reference.json`](../../../nix/domains/artifacts/guest/omnios/promoted-assembly-reference.json).
The output carries a test-only manifest with `transport_build_id`; it keeps
`native_admission=false`, is not a v6 production manifest and does not replace
the `45983bb7` promotion selected by `omniosGuest`/`illumosGuest`.

Assembly found one defect in the automated procedure: both disk copies share
ZFS vdev GUIDs, so the loader and an unqualified `zpool import` could select the
scratch pool. The derivation now exposes only the administration disk to the
loader (`-boot strict=on`) and selects the scratch slice by reading its ZFS label.

Two independent executions of the same input-addressed derivation
(`/nix/store/sfsn6xkinwsryy7c0i90p5a25mbvh4fw-overalls-omnios-native-image-candidate`)
produced the identical assembly receipt SHA-256
`b3acafb48c028d8afd668789c8487a8c357030ab03eddb8b0929c747ec14daca`
for build ID
`117de5bbcdb4da055359d97f2eb66e97c9390ec2de262e6faf3ce6ad1422cd88`,
with stock kernel `c56dc5c1` unchanged. The virtio, vioblk, vioif, vioscsi,
vio9p, viorand and sockfs modules are byte-identical to the promoted `45983bb7`
receipt. viosock `689f984e` and sockvsock `275d8223` differ because their source
changed after promotion (listener continuation across a validated reset event).
The raw disks differ (`b435f4d6` first, then
`1db6ac1328299414937359b298491016774c73c1f3471ef917058fcff4d0563e`): ZFS
snapshot/clone GUIDs, transaction groups, timestamps, the SMF repository and the
rebuilt boot archive are not reproducible. Deterministic guest linkage for
identical inputs is therefore recorded; a bit-reproducible full disk is not.

The formal catalog gates now consume this candidate instead of remaining
fail-closed. The persisted `native-omnios-reset` nested-KVM gate passed on disk
`1db6ac13` in 721.76 seconds (an earlier run on disk `b435f4d6` passed in 541
seconds; its receipt was not retained). The OmniOS reset receipt SHA-256 is
`fe8c25708fa2821e88205be8a738053deb228eb105e0ee2766ff0ba350bf62b6`: three API
statuses 204, idle error 131, pending read error 131 and write error 32 after
262,144 bytes, original listener reuse and current-CID revalidation, with probe
`485b984f`, firmware `261c6d43` and VMM `9815649a`.

The `native-omnios-transport` gate failed twice before passing. Its first run
checked loaded modules while the fixture had stopped production SSH; the check
now runs after production services are restored. Its second run passed exchanges
and loaded-module identity on boot 0, then failed at `shutdown-send` with a
subprocess timeout: `/usr/sbin/poweroff` emitted no console output and its SSH
command did not return. The unchanged third run passed both clean boots in
761.59 seconds. The OmniOS transport service receipt SHA-256 is
`9fa4a5b9fc50d7412b36341ea325efb67486b504bb30963c9402f50761311bd4`, naming all
25 service checks; the per-boot transport receipts are `5ed72b43` and `8bcfafd9`.
Each records CIDs 3/2, malformed-length refusal, disconnected-history recovery,
same-boot production restoration, the nine exchange sizes through 1 MiB and the
loaded viosock/sockvsock file digests equal to the assembly receipt, with no
shadowing module on the other native module paths. This binds loaded module names
and their files, not in-memory kernel text. After a ruff-format quote-style
edit to the driver (identical jq expression), the final source passed both clean
boots again in 681.84 seconds on the same disk; that service receipt SHA-256 is
`48e3dd2bcc59e13356b828e53709525ac280f14f103809623f75af057150157f`, with
identical loaded viosock/sockvsock digests. The intermittent poweroff hang
matches the earlier `679f5f8b` isolation `shutdown-send` failure recorded in
ADR-0190; it has no diagnosis and remains open.

The `native-os-guest-unit` evaluation asserts that the candidate keeps
`nativeAdmission`, `runtimeValidated`, `imageAssemblyReady` and
`reproducibleRawDisk` false and differs from the promoted image. Wrong-CID
injection, reset/DMA stress, bit-reproducible native disks, physical recovery
and fleet admission remain open. ADR-0190 stays accepted/partial; no admission
flag, capability row, Ash domain, deployment host or wire protocol changes.

After these runs, merge review added one blank line before the `@cc` block in
`guest-assemble.sh` so the contract checker sees the directive at the start of
its comment block. That comment-only change alters the script bytes and so the
`omnios-image-candidate` derivation; the hashes above describe the earlier
input, and a fresh candidate build is needed before reusing them as current.

## Native durability: interrupted growth, power loss and relocation

[ADR-0243](../decisions/0243-native-guest-durability-verification.md) adds three
native machine scenarios for each of FreeBSD and OmniOS. They go beyond the
same-host process SIGKILL already recorded. Each scenario boots the real native
image under nested KVM with the patched Firecracker 1.16.1 and fresh MMDS V2
placement, epoch and boot challenge. Each drive is a regular file inside a host
ZFS dataset, with Lilly's production `cache_type: Writeback` and `Sync` engine.
The OmniOS checks use the promoted `packages.omniosGuest`. The FreeBSD checks use
the source candidate, because the defect below required an image change. Every
receipt keeps `native_admission: false`.

Architecture impact: ADR-0243 is new. It defines a flush receipt as durable
across host power loss under Writeback drives and records the verification
method. ADR-0190 gains evidence. No Ash domain or resource, deployment host or
service, wire protocol, persistence shape or authorization grant changes. The
domain and deployment views are unchanged.

### Why the method models power loss

A VMM SIGKILL leaves every completed write in the host page cache, so it cannot
show that anything survives. For the power-loss scenario, the host ZFS pool sits
on a `dm-log-writes` target (`/dev/vdc` data, `/dev/vdd` journal). That target
appends each completed write to the journal in completion order, together with
every FLUSH and FUA request. Replaying a prefix of the journal reproduces exactly
the media state that existed at that point, including writes that were never
flushed. Because the journal records device flushes, any write the host never
flushed is exposed as volatile: a cut before that write's flush discards it.

The scenario proceeds as follows:

1. Boot the guest and write a marker.
2. Request a native flush, bracketed by `guest-flush-requested` and
   `guest-flush-acknowledged` journal marks.
3. Write further unsynchronized guest data and a host canary in a separate
   `tank/canary` dataset. Host ZFS commits are deferred by
   `zfs_txg_timeout=3600` and `zfs_dirty_data_sync_percent=100`.
4. SIGKILL Firecracker, then write the `power-cut` journal mark.
5. Replay only the entries before the cut onto a zeroed `/dev/vde` and import
   the pool from that device.

The host canary MUST then be absent, which proves the cut discarded unflushed
host state. The acknowledged marker MUST be present with exact bytes. The replay
receipt counts the device flushes between the two guest marks.

Interrupted growth traces Firecracker's `pwrite`/`write` calls to the disk
descriptor with `strace --seccomp-bpf`. Firecracker gets SIGKILL after K writes
at or beyond the old disk end: K=1 in the first stage and K=8 in the second. Each
recovery boot MUST pass the native integrity check, report the old or the grown
root size, and then complete growth.

Relocation flushes a 32,768-line workspace file on the source, stops cleanly and
runs `zfs send -c | socat` to a second NixOS node into `zfs receive -u`. It checks
that snapshot GUIDs match, destroys the source dataset, then boots on the
destination under placement `eeeeeeee-…-000000000202`, epoch 1. The destination
MUST refuse flush, workspace and terminal requests that carry the source
placement `dddddddd-…-000000000201` and epoch 7.

### FreeBSD flush defect and fix

The first FreeBSD power-loss run used a candidate built from source before this
change (derivation `97ppr4mc…-vm-test-run-overalls-freebsd-native-power-loss.drv`).
It failed after replay:

```
native crash ufs-fsck-exit=0
native crash command refused: status=1 stdout_bytes=0 stderr_bytes=84 login_event_exact=True
native_services.ProtocolError: native crash recovery guest command refused
```

UFS was consistent, but the marker acknowledged before the cut was missing.
Pinned FreeBSD 14.3 UFS sends no BIO_FLUSH, because `softdep_flushcache` defaults
to 0. UFSSUSPEND waits only for completed writes, which remained in the virtio
volatile cache. The [agent](../../../lyra/src/native_guest.rs) now issues
`DIOCGFLUSH` through the fixed `gpt/swapfs` provider after UFSRESUME and refuses
the receipt on failure. GEOM refuses BIO_FLUSH without write access, and the
mounted root holds its own provider exclusively. The
[ABI gate](../../../nix/domains/artifacts/guest/native-growth.nix) pins the
ioctl number. The rebuilt candidate
`/nix/store/2dggg4mlhfdmvqmgvlc9ji2qj9i5rb8s-overalls-freebsd-native-image-candidate`
recorded 36 device flushes inside the guest-flush segment and kept the marker.
The promoted FreeBSD selection predates this fix and is not
durability-qualified; promoting a fixed image is a separate step.

### Results

All six checks passed on the final source (`nix build .#checks.x86_64-linux.<name>`).
Both power-loss output paths were re-confirmed against the final source with
`nix build --dry-run`. Growth and relocation were rerun on the final driver;
the two relocation reruns followed a format-only driver change. Earlier passes
(FreeBSD 203.28 s, receipt `877a4e53…`; OmniOS 316.12 s, receipt `c175647c…`)
had the same outcome.

| Check | Result | Test script | Receipt SHA-256 |
| --- | --- | --- | --- |
| `native-freebsd-interrupted-growth` | pass | 307.38 s | `8ec0202c14a8796e9317030b7d6836c8697b9d5816736b7d5cc5b1484fefa2fc` |
| `native-omnios-interrupted-growth` | pass | 430.14 s | `8020cbf0eb4cc9a919ced5e95948298ec927536ae3cb86f288ffbb91b1e25441` |
| `native-freebsd-power-loss` | pass (after fix) | 192.05 s | `6df64247d3c4939962761bae0f2eda5f5fc77b06618acfa8100ca175f9c0b4e8` |
| `native-omnios-power-loss` | pass | 267.22 s | `e1354caa587a2e0d913d8c78a006ec8817eabc43d20bc018c673f3da9fd31083` |
| `native-freebsd-relocation` | pass | 206.07 s | `ecc553c0e00711d1f6d153efa325c13f1fdcd75287a99a0b62f91826b41281f5` |
| `native-omnios-relocation` | pass | 300.46 s | `a270d5645539e761fc38e562d2fe703ddf5997ac02df8db2f4e4387854809830` |

Interrupted growth (FreeBSD output `casmi4ji…`, runner phase 233 s; OmniOS
output `a6i6hfli…`, runner phase 335 s):

- **FreeBSD** root capacity went 5,183,107,072 → 7,268,753,408 →
  9,354,403,840 bytes, with clean UFS snapshot fsck after each kill. Stage 1
  killed at the first write past the old end. The interim boot saw the old
  root size and completed growth (receipt outcome `grown`). Stage 2 killed
  after eight such writes. By then the root already had the new size, and
  recovery found nothing to do (`unchanged`).
- **OmniOS** pool size went 8,053,063,680 → 10,200,547,328 → 12,348,030,976
  bytes, with a zero-error scrub after each kill. In both stages the
  expansion transaction had already committed before the kill, so the interim
  boot saw the grown pool. No OmniOS kill point observed a pre-commit state.
- So only FreeBSD stage 1 interrupted growth before the size change became
  visible. The other three kills show that a kill during late growth writes
  leaves a consistent, grown root.

Power loss:

- **FreeBSD** replayed 16,302 writes and 149 flushes before the cut and
  discarded 224 entries after it. Unsynchronized guest churn was absent after
  replay. Integrity was checked with a UFS snapshot background fsck.
- **OmniOS** replayed 4,571 writes and 765 flushes and discarded 326 entries.
  The flush segments held 4 device flushes (requested) and 10 (acknowledged).
  The churn file survived only as 0 bytes. The ZFS scrub completed with zero
  errors.
- **Both** lost the host canary, kept the exact marker bytes, booted with the
  same placement under a new epoch, challenge and boot identity, refused pre-cut
  flush, workspace and terminal authority, and shut down cleanly.

Relocation:

- **FreeBSD** sent about 2.1 GB in 13.79 s. Its source phase took 46 s and its
  destination phase 60 s.
- **OmniOS** sent in 11.77 s. Its source phase took 96 s and its destination
  phase 79 s.
- **Both** produced workspace SHA-256
  `8a149c996b193c8e220ade535fec8e2879a6394073b9aa30d21d0bd762ee4b11` on the
  destination, with two distinct boot IDs and refusal of the source placement's
  authority.

Observed failures before the passing runs (harness defects fixed forward):

- Relocation: the driver's `wait_for_open_port` consumed socat's single
  connection, and a received dataset was already auto-mounted.
- OmniOS power loss: the first canary sat in the guest dataset and was carried
  by the guest's ZIL commits. It now has its own dataset.
- OmniOS growth (product, open): two of four early OmniOS runs on ZFS-hosted
  disks failed at first boot because `svc:/site/overalls-native-growth` entered
  SMF maintenance ("failing too often"). This happened under both Writeback and
  Unsafe caching. Later ext4-hosted, diagnostic and final ZFS-hosted runs passed.
  The cause is unestablished. A failure-only diagnostic now prints the stopped
  guest's SMF log.

Host checks: nine unittest cases (4 `native_write_log_test.py`, 5 `native_durability_test.py`)
pass. The tool derivation gates them with pinned ruff and ty. Lyra
`cargo clippy --all-targets -D warnings` and `cargo test` passed.

### Remaining gaps

- Only one kill point per growth stage. Only FreeBSD stage 1 hit a pre-resize state;
  OmniOS kills landed after its expansion commit.
- No physical disk or firmware write cache.
- No Lilly dataset transfer or Marshall relocation orchestration.
- No split brain against a live source.
- The relocated workspace is a flushed file, not a Git checkout.
- The FreeBSD fix is not yet in a promoted image.
- The OmniOS growth maintenance failure remains intermittent and unexplained.

## 2026-10-22: FreeBSD native regression repair

Every FreeBSD native check was run on trunk after the native-kernel candidate
and ADR-0243 work. Three failed, and each was a fixture fault, not a guest fault:

- `native-freebsd-services` stopped at the flush stage. The guest's
  `flush_disk_cache` sent `DIOCGFLUSH`, and the service runner's drive used
  Firecracker's default `Unsafe` cache. That cache does not advertise virtio
  flush, so the guest got `EOPNOTSUPP` and correctly withheld the receipt.
  FreeBSD guests in the service, transport and reset runners now use Lilly's
  production `Writeback`/`Sync` drives (`guest-flushes-reach-backing-storage`).
  Applying the same policy to OmniOS made `native-omnios-services` fail twice:
  each ZFS flush became a host fsync, and the run missed its deadlines. It had
  passed on 1539706d3. OmniOS keeps the default there and passes again; the
  durability checks cover OmniOS on Writeback.
- `native-freebsd-relocation` (which also failed on e799ff9b9) ran the
  destination's `fsck_ufs -B -f` inside one SSH probe capped at 20 seconds. The
  check now runs detached and polls only its closed exit status under a
  300-second deadline.
- `github-tools-freebsd-retained` failed at the push phase. git-lfs sends the
  managed gitconfig's `Connection: close` beside Go's own copy, and the
  synthetic fixture refused every repeated header. It now joins a repeated
  `Connection` list header and still refuses other duplicates. A parser unit
  test covers both cases.

All twelve then passed under nested KVM with Firecracker 1.16.1 on 2026-10-22:

- `native-freebsd-{services,isolation,growth,recovery,crash-recovery,reset}`
- `native-freebsd-{transport,wrong-cid,interrupted-growth,relocation,power-loss}`
- `github-tools-freebsd-retained`

`native-omnios-services` also passed with the final drive policy. Fix commits:
d731eb6bd, c70940b99 and the OmniOS drive correction.

The OmniOS executor-withdrawal stage also failed intermittently with a
subprocess timeout. `native-omnios-reset` failed this way on 1539706d3 and on
the current tree, and `native-omnios-transport` failed once. Each group
observation is an SSH probe capped at five seconds inside the fifteen-second
fence, and an illumos SSHD/PAM login can outlast that cap. A timed-out probe
now counts as no observation and is retried under the same deadline; a late
probe still fails. After 5aadeae9a, `native-omnios-reset` and
`native-omnios-transport` each passed twice, and `native-freebsd-services`
passed again.

## 2026-10-22: OmniOS native sweep

Every OmniOS native check was then run on trunk under nested KVM with
Firecracker 1.16.1. These passed:

- `native-omnios-{services,crash-recovery,growth,interrupted-growth}`
- `native-omnios-{isolation,recovery,relocation,reset,transport}`

Two did not pass reliably.

### Intermittent first boot (`native-omnios-power-loss`)

`native-omnios-power-loss` failed twice on trunk because the first
`power-loss-before` boot exceeded the 240-second kernel-boot deadline. A third
run on the same tree passed, and so did a run of e799ff9b9, where the
`power-loss-before` phase took 78 seconds including boot. The guest image is
identical at both revisions. The built durability tools differ only in code
that runs after boot (the fixture capability list and `Connection` header, the
FreeBSD fsck poll, the FreeBSD-only drive policy and the executor-observation
retry), so this is an intermittent illumos boot stall, not a regression.
Illumos guests stalled at boot in three of seven OmniOS runs that day; no run
captured the guest console, so the stall is not yet diagnosed.

A later capture of the guest console diagnosed it. The service manager placed
`svc:/site/overalls-native-growth:default` in maintenance ("a method is failing
in a retryable manner but too often"), so bootstrap never started and the boot
deadline expired. The promoted image's ZFS label records the assembly path
`/mnt/overalls-native-assembly/devices/scratch`. At boot the kernel opens the
root through an alternate `/devices` path and keeps that vdev path, so the
growth helper's cache-free `zdb -e -p /dev/dsk` discovery can only resolve the
canonical `c…t…d…s1` vdev through `/dev/dsk` links. On a first boot at a new
device path, devfsadm may not have created those links yet; the helper then
refuses, as its contract requires. The slower Writeback drives over
dm-log-writes in `native-omnios-power-loss` lose this race most often.

The [growth helper](../../../lyra/src/native_growth.rs) now runs
`devfsadm -c disk` synchronously before label discovery. Every existing gate is
unchanged: assembly pool GUID, one canonical whole-disk vdev, raw-device custody
and no persisted pool cache. `power-loss` passed three of three runs against the
rebuilt Nix candidate image through a temporary check, with first-boot phases of
77–79 seconds, and `native-omnios-transport` passed on the same candidate. The
promoted `45983bb7` image that the other OmniOS checks use is unchanged, so its
first boots keep the race until a new promotion.

### Retained GitHub tools on illumos (`github-tools-illumos-retained`)

This check fails on trunk and on e799ff9b9, before the day's changes. The
guest stops receiving any network traffic while one of its sockets stops
reading:

- The retained bootstrap downloads the 41 MB `gh` artifact and pauses reading
  the stream about every two seconds to renew its lease over a new TLS
  connection. Every download was cut off after 18–22 MiB, 3–4 seconds in;
  the bootstrap then exited 92 (renewal `Send`/`TimedOut`) and was re-run more
  than 40 times.
- Host socket sampling during a stream showed the renewal connection stuck in
  `SYN-RECV`: the guest never acknowledged the host's SYN-ACK. The stalled
  stream's unacknowledged segments froze while the host retransmitted with
  backoff, and the guest sent no further acknowledgements although its
  advertised window never shrank. Reception resumed only when the stream
  closed.
- Firecracker's network counters set the illumos run against a passing
  `github-tools-freebsd-retained` run:

  | Counter | FreeBSD | illumos |
  |---|---|---|
  | Bytes received | 58.7 MB | 809 MB |
  | Packets received | 3,906 | 533,988 |
  | `no_rx_avail_buffer` | 28 | 589,547 |
  | `no_tx_avail_buffer` | 0 | 84,718 |

  FreeBSD receives large coalesced segments. Illumos `vioif` receives
  MTU-sized packets and repeatedly leaves the device without a posted receive
  buffer.

The fault is in the illumos guest's virtio-net receive path (`vioif` from the
pinned illumos source with the `0002-modern-virtio.patch` changes, under
Firecracker), not in Lyra or the fixtures. Its effect reaches past this test:
an illumos workload that stops reading one socket can stall all inbound
traffic for the VM. A temporary change that let the executor's renewal use its
whole request deadline to connect only moved the failure to the pinned
image's `agentd`, whose own renewal then timed out, so it was not kept.

A fix belongs in the guest kernel and needs a new OmniOS candidate,
qualification and promotion under ADR-0190. The pinned driver lends at most
half its receive buffers upstream and refills the ring after each receive
interrupt, so simple loan exhaustion does not explain the stall; the remaining
suspects are refill notification under the modern virtio transport and the
absence of receive offload. Until then this check is a known failure, and
retained GitHub tools on illumos are not qualified.

### Follow-up: `vioif` receive descriptor budget

The illumos stall above has a precise cause in the pinned `vioif` driver
under Firecracker:

- Firecracker offers no `VIRTIO_F_RING_INDIRECT_DESC`, so each receive buffer
  uses direct ring descriptors: one for the virtio header plus one per data
  cookie.
- Receive buffers were `VIOIF_RX_DATA_SIZE` (65,550 bytes) even though the
  driver never negotiates guest receive offload. Each spanned about 17 page
  cookies, so the 256-entry ring held only about 14 posted buffers. That matches
  Firecracker's very high `no_rx_avail_buffer` count.
- Buffers lent upstream keep their descriptors until the stack frees them, and
  the driver allowed up to half its 256 buffers on loan. Around 14 loans to a
  socket that stops reading exhaust the ring. No receive interrupt then fires to
  refill it, and inbound traffic stops until the socket closes.

`0005-vioif-receive-budget.patch` follows the 0004 block-descriptor budget:

- Without guest receive offload, receive buffers are sized to the MTU plus a
  VLAN Ethernet header and the virtio header, and page-aligned when they fit in
  a page. Each buffer is then one cookie and two descriptors.
- `vioif_rx_loan_limit` caps loans at half the buffers the ring can hold: one
  ring slot each with indirect descriptors, otherwise the header plus the largest
  cookie count.

`net_receive_budget_test.c` executes the helper extracted from the patched
source under ASan/UBSan. Its vectors include the production 256-descriptor ring
with 17-cookie buffers (former limit 128 loans against 14 buffers that fit).
The kernel candidate build ran it, and the Nix KVM candidate
`/nix/store/4marcra2m10kalj3m82zrf82iyvkpqm9-overalls-omnios-native-image-candidate`
records `vioif` as `inputs-changed` against the promoted reference. On that
candidate `native-omnios-transport` passed in 672 seconds and
`native-omnios-reset` in 390 seconds on 2026-10-22.

Retained GitHub tools are not used for native runs, so the change was not
re-qualified against `github-tools-illumos-retained` and the candidate was not
promoted. The promoted `45983bb7` image and its admission are unchanged and
still carry the stall until a separate promotion under ADR-0190.

## 2026-10-23: OmniOS `a96f291b` promotion

The Nix KVM candidate
`/nix/store/yl2zb69m8l18cl5ynl1lwaaqpx6xz6m7-overalls-omnios-native-image-candidate`
carries the `vioif` receive budget and the growth helper's disk-link creation.
Its 8,589,934,592-byte disk SHA-256 is
`a96f291b7874c005e295ed1d1958471e0d84095aa8ddd143786fcc1199357240`, with stock
kernel `c56dc5c1` and firmware `261c6d43`. Its assembly receipt SHA-256 is
`3bb1dada687994082250cb82dfb47a4e4bdad9e511ed9a48200c6a9aa441d1e8`.

All five scenarios ran as Nix machine checks against those exact bytes with
VMM `9815649a9bed84194ca45c5aef4c9307a596c7ffbe1f9f0e881c1ae536226d02`, using
temporary catalog entries that pointed the maintained runners at the candidate.

| Scenario | Output | Service receipt SHA-256 |
| --- | --- | --- |
| Services | `/nix/store/mbl6i0nhxhq307z0v6lc1ia9dbjrxg9l-vm-test-run-overalls-illumos-native-services` | `0710bf88266bbce4135889dcf644a5f5fdeec128cc67b75825e7c50614bb50bf` |
| Growth | `/nix/store/bw4n8dc0m9i011al13sly83avkw8bx38-vm-test-run-overalls-illumos-native-growth` | `9d330d31094ff2bb747265e04e31d31163e020765e9a07d75cb0c96970173a48` |
| Isolation | `/nix/store/jgn0l5h6nhd48qr86lnf8f774wf3n1hv-vm-test-run-overalls-illumos-native-isolation` | `c8c6bff93be2caf9bac3171377e4975cac55f744783bef3ddced5e6c44f98f41` |
| Daemon recovery | `/nix/store/7j0923ha2y23zznnxrx66l1q44ikh876-vm-test-run-overalls-illumos-native-recovery` | `4faef82a37dcc4972bae67b2b9afdad683e4573d32dc4c16ba6d03c2507f707b` |
| Crash recovery | `/nix/store/lp2wrsdv830gxcb3zd2cs7a4vs44fcmm-vm-test-run-overalls-illumos-native-crash-recovery` | `7463109b25bad312e655247bc57b87820ae9e47796a72e88708cda18c8789a9f` |

Every service receipt binds the disk, kernel, firmware and VMM above, records
distinct boot IDs and the exact 25-check OmniOS oracle, and ends `clean`
(`sigkill,clean` for crash recovery). The images do not claim Git identity
support; no receipt carries the attribution oracle. Supporting receipts cover
their boots: one growth receipt for three boots, one isolation and one recovery
receipt per boot, and one crash receipt.

One earlier isolation attempt on the same bytes failed at `stage boot
category=runtime`; its guest console was not retained, so the cause is not
established. Two other attempts at isolation, recovery and crash recovery were
stopped by an external interrupt, not by a check. The recorded passes are the
next serial attempts with unchanged inputs and oracles.

The sealed directory holds `disk.raw`, a dereferenced `firmware` and the public
receipts under `evidence/`: check names, digests, boot IDs, sizes and pool/vdev
GUIDs, with no credentials, logs or probes. It was added as
`/nix/store/n07g05k2160s3zfbd8i4m9abxz84vxgn-overalls-native-omnios-r151050-a96f291b`,
recursive NAR hash `sha256-JtShi7noaG35U4pUfUKVKQtNwOLna9acXFSi1lOOxTo=`, with
no references. The host watch-store agent published it to the signed Overalls
cache within two minutes. A fresh empty store substituted it from that cache
with `require-sigs=true` and the reviewed public key, reproducing the NAR hash
and disk digest.

The reviewed version-6 manifest
[`omnios-r151050-a96f291b.json`](../../../protocol/priv/native/omnios-r151050-a96f291b.json)
differs from `omnios-r151050.json` only in the root digest. Its image ID is
`sha256:6dc1a0840e50e508c964c2890e805c919b78c2cddb3e1e8e9d379e001c28617d`.
The [admission registry](../../../protocol/lib/overalls_protocol/native_admission.ex)
selects it and keeps `98b23b79` in illumos history. The
[promotion constructor](../../../nix/domains/artifacts/guest/native-promotion/omnios-r151050-a96f291b.nix)
ran `verify_approved!` and produced
`/nix/store/8zl5axlb9phfi075az710wjpx8ga87f0-lilly-omnios-r151050-x86_64-a96f291b-promoted`
(NAR hash `sha256-kqdXCIXf3HpOFG7bgY6mukA4GTjA3mmiwQQO86xdidY=`, no references),
containing only `disk.raw`, `firmware` and the reviewed `manifest.json`.
`omniosGuest` and `illumosGuest` select it; `legacyOmniosGuest` keeps the
`45983bb7` promotion staged for retained machines. `native-image-promotion`
passed 23 checks, `native-os-guest-unit` passed with the new identity, and the
protocol admission tests passed 12 of 12.

With the promotion selected, the regular `native-omnios-power-loss` check passed
(first boot 78 seconds, script 310 seconds) and `native-omnios-interrupted-growth`
passed (script 469 seconds), both against the promoted package.

The earlier sealed candidates
`/nix/store/9r92hvbj5zch8r0xdv4wsw7rhhwg6as7-overalls-native-omnios-r151050-45983bb7`
and FreeBSD `4ccphabcl7f0dcjyvy7s3hx4a1dnnj36` now return 404 from the signed
cache, so a host without the built promoted output cannot rebuild
`legacyOmniosGuest` or `guest-freebsd`. Their cache retention is a separate
publication gap.

Not established: live Marshall-driven OmniOS lifecycle on `a96f291b` (the
recorded CLI journeys ran on `45983bb7`), deployment, physical isolation,
reproducible raw-disk assembly and Git identity support.
