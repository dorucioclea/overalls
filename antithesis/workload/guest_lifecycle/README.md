# Guest lifecycle workload scope

`serial_driver_physical_boot_cycle.py` is the one command of the launchable
`guest-lifecycle` selection
([selection](../../verification/selections/guest-lifecycle.json)). It remains a
draft for the separate `integrated-zfs-guest` template. It uses the private
fixture operator for real Marshall Compute provision/stop/start operations, keeps every request in an
attempt/acknowledgment ledger, and joins committed `compute.operation` outcomes
with a separate read-only guest witness. The witness reads actual QEMU/backend
PID and process start ticks, port-1024 boot ID and challenge digest, and a stopped
qcow2 hash. A lost operator reply or missing witness is unexercised. A completed
outcome that contradicts the current VM state or execution tuple fires a failing
assertion.

## Guest-lifecycle profile and its STUB storage

The `guest-lifecycle` profile renders the base graph plus
`config/compose.guest-vmm.yaml` and `config/compose.guest-lifecycle.yaml`. Its
images are the base `pg`, `marshall` and `workload` stages plus `lilly-guest`
and `guest-vmm`. Hosted Antithesis has no KVM, so the guest boots under QEMU
TCG. The container `lilly-guest` release has no ZFS: its
`OverallsAntithesis.Lilly.StubStorageCollector` reports each configured pool as
a **fixed synthetic 1 TiB STUB** with zero usage and no allocation credit, and
limits compute headroom to one free guest-vmm slot (1 vCPU, 2 GiB guest plus the 64 MiB VMM overhead admission reserves) capped by
the container's measured cgroup limits. `StubStorageHealth` sets
`execution_ready` only with that stub report, the verified advertised image and
a passing guest-vmm health check. The enrollment operator registers the
guest-vmm image manifest through `Marshall.Compute.Images.register`. None of
this is native ZFS, KVM, Firecracker or capacity evidence.

The bootstrap emits `setup_complete` only after the base checks and
`guest_lifecycle.readiness.substrate_gap` observe the guest-vmm image identity
through the read-only witness bridge and a Marshall catalog that offers that
image with known capacity for its shape. Each unmet condition is logged once
per process with a fixed reason token. The command ends with an unsampled stop
attempt so a later cycle can find the slot free; that stop proves nothing.

Marshall withholds capacity whose last accepted Lilly report is older than its
5 s freshness window, and injected faults on the Lilly Control exchange exceed
that window routinely. The command therefore polls the catalog for up to 90 s
before provisioning instead of judging one instant, and retries a provision
refused with `insufficient_capacity` once after a fresh wait, because admission
re-checks the same window transactionally. Refusals are logged with their
closed reason token only. A stop retains the boot it ended, so the stopped
witness is requested with the provision's execution tuple rather than the
stop operation's newer generation, which the guest server fences exactly.
The outcome/VM consistency assertion is evaluated for every completed outcome
sampled, so a healthy run records it as held. A stop or start whose reply is
lost is resubmitted with its original request key, which Marshall
deduplicates, up to three times before the cycle is left unexercised.

Which catalog properties the profile can exercise:

| Property | Profile exercise |
| --- | --- |
| `guest-readiness-binds-current-physical-boot` | Support only: guest-ready outcomes joined to the current tuple, live QEMU/backend identity and port-1024 readiness; fresh start needs a new boot UUID. |
| `stop-retains-disk-until-restart` | Support only: accepted stop has no QEMU/backend and a retained qcow2 hash. No ZFS dataset, content, address or detach evidence. |
| `guest-ready-does-not-claim-workspace-checkout` | Not exercised. |
| `continuing-boot-advances-generation-without-second-boot` | Not exercised. |
| `runtime-restart-requires-fresh-readiness` | Not exercised. |

The draft currently emits narrower physical boot and stop assertions. The five
catalog properties remain **unexercised as full properties** until these joins
exist:

| Property | Additional independent evidence required |
| --- | --- |
| `guest-readiness-binds-current-physical-boot` | Lilly's current boot journal challenge digest and boot ID, joined to the accepted outcome and guest witness across a delayed/replaced boot. The current Marshall outcome records `guest_ready` but no boot ID. |
| `guest-ready-does-not-claim-workspace-checkout` | A source-v2 image and actual guest done marker, Git HEAD and source digest. `workspace_source_version: null` means capability absent and is distinct from a checkout refusal or success. |
| `continuing-boot-advances-generation-without-second-boot` | A supported newer-running-intent adoption action plus old delivery barrier and exact journal settlement. Stop/start is a fresh boot, not an adoption. |
| `stop-retains-disk-until-restart` | Per-placement measured ZFS dataset GUID, retained guest content marker/hash, address and network detach. The stopped qcow2 hash alone does not prove these. |
| `runtime-restart-requires-fresh-readiness` | Closed Lilly restart and database fault controls, a current authenticated delivered report/actor witness, and unchanged QEMU process identity. |

The pure oracle functions in `oracle.py` return `UNEXERCISED` when those proofs
are missing. Tests cover stale generation/PID reuse, absent source capability,
and unknown disk content. This harness code changes no product protocol, domain
boundary or accepted architecture decision. It is not a native Firecracker or
ZFS acceptance result. This README records the selected profile and its stub
boundary; no hosted run is recorded yet.
