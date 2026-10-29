# Antithesis harness reset

## Scope and architecture impact

The user authorized a new worktree at baseline
`9fe1e493b2090d44bacd16089049cd12b316d58a`, removal and a commit of the old
`antithesis/` tree before a fresh whole-repository rebuild. The removal phase
does not create a replacement harness or submit a hosted run. The pre-existing
staged deletions in the original worktree remain outside this change.

Reviewed root, documentation, Marshall handbook and Lilly fixture contracts;
ADR-0017's accepted host ownership, durable actor, journal, execution fencing and
independent guest lifetime requirements; the current generated property files;
and the lifecycle scenario ledger. This changes test organization and the
description of current verification capability. Production domain boundaries,
protocols, persistence, authorization, isolation, capacity and recovery authority
remain unchanged. ADR-0017 remains accepted and partial; no replacement decision
is introduced.

## Historical evidence and retained tests

Historical architecture records contain 18 local Markdown link occurrences
covering 15 distinct files in the removed tree. Each target was checked in the
captured baseline with `git cat-file`; links now use that full revision in GitHub
URLs. Existing reports preserve their recorded results, source scopes and
limitations, including local mutation evidence that never established hosted
Antithesis coverage. These archived artifacts are evidence, not the replacement
property catalog or current launch instructions.

The [ordinary durable fake executor](../../../lilly/test/support/durable_fake_executor.ex)
retains the controlled effects needed by the existing
[actor properties](../../../lilly/test/vm/antithesis_actor_property_test.exs) and
[fake-command properties](../../../lilly/test/vm/fake_executor_property_test.exs).
Both files keep their original paths and assertion names while depending on
Lilly test support rather than `antithesis/`. The fixture no longer emits the
old harness's Antithesis assertions. Its durable fake launch markers still
support generated replay, generation advance, interruption, actor death,
completed-effect recovery and stop/delete observation causality. These are
ordinary property fixtures, not native launch or storage evidence.

The scenario ledger (`marshall/priv/hldd/scenarios`, removed by ADR-0263) retains the
existing lifecycle and completed-launch test references, recorded assertion
names and gaps. The lifecycle handbook (`marshall/priv/hldd/04-lifecycle.md`, removed by ADR-0263)
distinguishes those retained tests from the retired Compose workload. The
verification reference (`marshall/priv/hldd/17-reference.md`, removed by ADR-0263) identifies
fresh hosted and mutation evidence as pending.

## Validation and remaining work

Baseline-target inspection passed for all 15 archived paths. The four actor
property names and one fake-command property name match the baseline exactly;
all three scenario evidence references resolve to their exact assertion and
historical record text. The scenario ledger is byte-identical to the baseline.
`git diff --check` passed, and no local architecture or handbook link targets
the removed tree. These are source/link checks, not executed property evidence.
Current validation uses the pinned Elixir 1.20.4 / OTP 29.0.6 shell. Targeted
format checks and both retained Lilly property files passed all five properties.
Lilly's full `mix precommit` passed 559 cases (110 properties, 449 tests), compiler,
formatting, reviewed logging and forced Dialyzer with zero errors and zero skips.
Root ADR, handbook receipt/reference, generated option/scenario/view, conflict
marker and code-contract checks passed; the contract tooling's 19 regression
tests also passed. `nix build .#checks.x86_64-linux.hldd --no-link` passed with
output `/nix/store/zkxmw9dh7wb9vyd1rs8h932kafh04z4i-overalls-hldd-check`.
Marshall's full `mix precommit` passed 1,459 cases (238 properties, 1,221 tests;
four excluded by the normal configuration) in 1,441.0 seconds, followed by forced
Dialyzer with zero errors, zero skips and zero unnecessary skips. The saved full
gate log and exit status are `.devenv/antithesis-reset-marshall-precommit.log` and
`.devenv/antithesis-reset-marshall-precommit.exit` (exit zero). A fresh independent
source review found no blocking architecture, contract or handbook issue; it
checked fixture semantics, both consumers, archived targets, retained property
names and exact scenario evidence references.
These are current removal-phase results; historical gate results are not reused
as a pass for this change. Receipt recording follows review of the final source
and chapter diffs, not merely the removal of stale paths.

The fresh whole-repository research, harness, workloads and hosted baseline
remain pending. Each later mutation verdict needs its matching source/config
fingerprint, image identity and counterexample-specific evidence within the
authorized run ceiling. Emulated guest journeys cannot establish Firecracker,
native ZFS or independent physical failure domains; their evidence remains
separate from hosted user-space services and native checks. No deployment or
production acceptance is inferred from this reset. This is a scoped self-review
of the removal phase, not the fresh harness's completion review.
