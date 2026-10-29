# Guest trust evidence verification

## Scope and pre-implementation assessment

Campaign improvement 043 closes the evidence bookkeeping of
[ADR-0113](../decisions/0113-guest-trust-at-boot.md)'s boot-bound guest platform
trust on current source. ADR-0113, ADR-0115/ADR-0117's roster requirements and
ADR-0050/ADR-0051/ADR-0053's physical admission policy remain unchanged.
No production protocol, authority, image, deployment topology or storage
contract changes; the delta is the native probe, its directory contract and
evidence records.

The `guest-trust` scenario row
held two property entries at `present` (test exists, assertion inspected,
no execution record on current source) and asked in its `preferred_gap` to
record the lifecycle/digest property execution and add native terminal
trust-failure exhaustion.

Recorded before implementation on current source `40c1e73b`:

1. The lifecycle property
   [a boot must pass pending and delivering before installed](../../../lilly/test/lifecycle/guest_trust_test.exs)
   writes a real `Lilly.Lifecycle.GuestTrust` Ash journal in a locked temporary
   directory: a direct `pending → installed` transition is rejected, generated
   `delivering → failed` retries (1–3 attempts, `max_runs: 12`) succeed, the
   final `delivering → installed` write persists, and a reload returns
   `installed` with exactly `2 * attempts + 3` monotonically sequenced events.
   This matches the row's claim of generated retry transitions against the real
   Ash journal; no gap required a test addition.
2. The digest property
   [digest is invariant under CA ordering and changes when a CA changes](../../../lilly/test/lifecycle/guest_trust_test.exs)
   checks `Lilly.VM.GuestTrust.digest/1` on generated independent root byte
   sets (`max_runs: 30`): ordering invariance for two distinct binaries and
   digest difference for two different single-root sets. This matches the
   row's digest-only claim; no gap required a test addition.

Improvement 011's [fleet guest trust review](2026-09-25-fleet-guest-trust-verification.md)
recorded natively, per distribution, exactly one completed wrong-boot refusal
(wrong challenge with a different valid root subset, receiver EOF without
response bytes) between positive same-boot deliveries. No refusal repetition
or failure-variant sweep was recorded. This improvement reuses that fixture
topology as a bounded stage of the same probe; it does not rerun the seven
legacy feature matrices listed there.

The failure-side addition exercises only the receiver (`overalls-trustd`)
terminal boundary: each mutated request violates exactly one validation
(checks in `lyra/src/bin/overalls-trustd.rs` `validate/2`) and must reach a
completed terminal refusal — peer EOF with no response bytes — before the
probe verifies the unchanged durable journal receipt, the installed guest
bundle, guest services, and a still-accepted final positive delivery.
"Expired" means stale boot-bound authority (a previous execution epoch);
receiver-side X.509 expiry is not inspected because the host is the root-set
authority under ADR-0113. The ADR's sender-side trust-retry exhaustion
(`failed → delivering` for at most three attempts on one boot, then fencing
and stopping the VM) is canonical improvement 053 and remains outside this
scope. Independent physical hosts remain excluded.

## Property execution records

`lilly/test/lifecycle/guest_trust_test.exs` executed to completion twice on
current source, partitioned isolation (`MIX_TEST_PARTITION=verify043`)
against the local PostgreSQL socket:

- seed 0: **2 passed**, finished in 0.5 seconds (0.5s async, 0.00s sync);
  `property a boot must pass pending and delivering before installed (448.0ms)`;
  `property digest is invariant under CA ordering and changes when a CA changes (2.5ms)`.
- seed 43043: **2 passed**, finished in 0.6 seconds (0.6s async, 0.00s sync).

No exclusion or failure occurred in either run. These are host-local property
records against the real Ash journal and the digest function; they carry no
kernel, vsock or guest-native claim.

## Native execution record

The composed native candidate
`/nix/store/f62qs50m55h68z2lhjrn06qnz2sc1hah-vm-test-run-overalls-fleet-guest-trust.drv`
on worktree base `40c1e73b` (branch delta: probe stage and directory contract
prose only) ran under the serialized native lock from **17:41:58 UTC on
2026-09-26**, returned exit 0 at **18:41:14 UTC** (wall 59m16s, including first
realization of this worktree's guest images) with output
`/nix/store/lh92cxb1jffz1y2sxmjcy4hkxdnnspln-vm-test-run-overalls-fleet-guest-trust`.
Fleet bootstrap passed in 56.88 seconds and authenticated storage/service setup
in 144.87 seconds; the test script finished in 976.44 seconds and cleanup
drained all nine machines in 3.99 seconds, with no fleet-guest-trust driver or
QEMU processes belonging to this run remaining afterwards.

The executed probe `/nix/store/11jmizjs3r32wcm7bbf59swj22k1rsga-fleet-guest-trust`
evaluates `/nix/store/j2w77pyi7myhrcv69mb2vivgl00bfmwh-guest.exs`
(`sha256-VgFpYtTR6kr9ob3GQKXwk/FsxGnqzzgCfdslc5yYNsw=`), byte-identical to the
committed fixture source including the `trust_failure_exhaustion` stage.

The trust and restart subtest passed in 451.78 seconds on both distributions.
Six probe executions occurred (Ubuntu and NixOS each in seed and check modes,
plus two further NixOS seed probes against the capacity guests). Each probe
execution exhausted eight refusal variants to completed peer-EOF refusals
without changing the durable receipt, installed bundle or services: the
wrong-boot exchange recorded by 011 plus seven mutations, each violating
exactly one receiver check — legacy protocol version 0, a foreign placement, a
stale execution epoch, a malformed nonce, a forged digest claim, a duplicated
root, and private-key-bearing certificate material. The durable receipt check
reloads the real Ash journal after each sweep, exact installed bundle, system
trust store and service ordering checks follow it, and the final positive
same-boot delivery after each sweep returned the current boot receipt.

Native failure-side summary: Each probe execution exhausted eight refusal variants to completed peer-EOF refusals without changing the durable receipt, installed bundle or services.

One observation independent of trust: the l1 Ubuntu guest's stop escalated
through systemd's final-sigterm timeout to SIGKILL before stopping (the unit
had run 2m39s); the stop then completed, the restart produced a new boot UUID
with retained data, and every refusal/renewal assertion above passed. This is
the pre-existing stop path under fixture load, recorded for completeness; it is
not a trust verdict.

The capacity control passed again in 322.52 seconds: three usable NixOS guests,
exactly `3|16106127360` held disk bytes, and the 17 GiB-root request refused
with `insufficient_capacity` against the actual 16 GiB quota without an added
VM. The seven legacy feature matrices were evaluated, not rerun.

## Mutation record

One mutant cycle targeted the new stage: `overalls-trustd` `validate/2` was
relaxed to additionally accept an expired execution epoch
(`request.execution_epoch == boot.execution_epoch - 1`), i.e. accept expired
trust once. Rebuilt under the same native lock, the mutated candidate ran
40m37s wall and failed as designed: the first Ubuntu seed probe terminated at
the closed stage `trust_failure_exhaustion` because the mutated receiver
accepted the stale epoch and answered a receipt where the oracle requires peer
EOF with no response bytes. Cleanup drained in 3.76 seconds. The mutation was
then restored with `git checkout` (byte-identical to HEAD), and the restored
tree evaluates back to the identical passing derivation
`f62qs50m…fleet-guest-trust.drv`, whose passing store output `lh92cxb1…`
already exists in the native store; no rerun was needed.

## Final architecture and contract assessment

The final diff changes the native probe, its directory contract prose and
evidence records only. ADR-0113's boot authority and ADR-0050/0051/0053's
admission policy are preserved; no new production API, domain, resource,
dependency or deployment placement is introduced. ADR-0113 remains accepted
with partial implementation: sender-side terminal trust-retry exhaustion
(bounding a boot to at most three attempts, then fencing and stopping the VM)
remains unverified as canonical improvement 053, and independent physical hosts
and the seven legacy feature matrices remain separate acceptance.

Review covered the refusal vector against every `validate/2` gate, the closed
stage vocabulary, the unchanged-journal and unchanged-bundle assertions around
the sweep and final positive delivery, and the directory contract strengthening
(`fleet-native-trust-evidence`). Repository, Nix-test and handbook contracts
are consistent within this scope; the 011 recorded journeys retain their scope.

Verification performed: the two focused property executions above; the Lilly
full `mix precommit` passed (toolchain pins, 124 ADRs, contracts, logging,
warnings-as-errors compile/format, `test --warnings-as-errors`, and forced
Dialyzer with zero errors, zero skips and zero unnecessary skips) and the full
suite independently passed 413 checks (50 properties, 363 tests) in 15.3
seconds under seed 226043 with zero exclusions; the composed native candidate
and mutant cycle above; all-file `prek run --all-files`;
`scripts/check_adrs.exs`; HLDD receipts plus generated options/coverage/views
checks; and the Nix `checks.x86_64-linux.hldd` build. Remaining gaps: 053's
sender-side terminal retry exhaustion, independent physical hosts, the seven
legacy matrices, and native coverage beyond this two-node colocated topology.
