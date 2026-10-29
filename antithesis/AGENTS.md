# Antithesis harness guidance

The harness is a source-built, isolated verification environment. Read
`scratchbook/sut-analysis.md` and `scratchbook/deployment-topology.md` before
changing its service graph. Follow the repository's root `AGENTS.md` and
`CONTRACTS` requirements, especially architecture impact, typed code,
secret custody and truthful verification claims.

Use `antithesis-setup` for image and Compose scaffolding,
`antithesis-workload` for test commands/assertions, and `antithesis-launch` for
remote submissions. Only the workload bootstrap may emit `setup_complete` after
the selected graph and independent oracle are ready. A health marker for the
one-shot migration or enrollment process proves only that exact action finished.

Keep startup credentials in named runtime volumes. Never put them in Compose
environment values, image layers, build contexts, logs, assertion details or
scratchbook manifests. Production credential files are not mounted here.
Do not turn a missing physical prerequisite into a passing result. The hosted
Lilly controlled pool has a configured identity and unavailable capacity;
native ZFS, KVM and Firecracker claims require separate native evidence. The
only exception is the explicitly labelled `admission-stub` profile, whose
harness stub storage substrate reports configured (not measured) pool totals
so real Marshall admission can run; never present its results as ZFS,
physical-capacity or isolation evidence.

Run Docker Compose with the pinned CLI and Podman socket recorded in
`.devenv/antithesis-environment.json`. Validate the rendered Compose graph and
locally start/build images before claiming harness readiness. Record the
executed scope and failures. Never send a run with `snouty launch` directly;
use the launch skill when submission is requested.
