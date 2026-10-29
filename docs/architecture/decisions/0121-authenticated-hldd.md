# ADR-0121: Authenticated handbook and mandatory maintenance

- ID: ADR-0121
- Date: 2026-09-25
- Status: superseded
- Implementation: implemented
- Components: Marshall Web, documentation, Nix, repository governance
- Supersedes: none
- Superseded by: ADR-0122

## Context

The user requested a concise but complete high-level design and operations manual
at `/hldd`, one page with diagrams and navigation for all signed-in users. They
required a maintenance skill and a blocking review gate, preferred NixOS machine
integration and property-based tests, and requested explicit user-scenario and
layered security-boundary coverage with untested gaps.

## Decision

Ship reviewed Markdown chapters in Marshall's release and render them through the
existing current-login LiveView boundary. Add shared navigation independent of
administrator membership. Do not expose the chapters through public documentation
or static routes. Use the existing Markdown compiler and locally bundled, pinned
Mermaid in strict mode. No live fleet query supplies documentation content.

Maintain source-to-chapter review receipts binding relative file identities and
bytes. New or changed sources, removed files and changed chapters invalidate their
receipt. Each update requires an explicit reviewed update or concrete no-impact
rationale. The checker never refreshes receipts. A catch-all covers new source
areas; generated artifacts, dependencies, ciphertext and build caches are excluded.

Require the repository HLDD maintenance skill for relevant changes. Generate the
NixOS option reference from evaluated declarations and the scenario chapter from a
validated evidence ledger. Each sensitive scenario identifies the boundary,
expected refusal, evidence scope and gaps. Require entries across identity,
authorization, transport, execution, isolation, storage and recovery layers.
Prefer native NixOS integration and property tests. Distinguish present test code,
recorded execution and deployment acceptance. Missing preferred tests require an
explicit next-test explanation; structural validation cannot establish correctness.

## Alternatives

Public documentation was rejected in favor of signed-in access. Multiple pages
were rejected in favor of a single searchable document. Manual optional upkeep
would not satisfy mandatory maintenance. A digest checker alone cannot establish
semantic accuracy, so reviewed evidence and skill obligations remain necessary.
Runtime CDN rendering would violate the asset boundary and release reproducibility.

## Consequences

The release gains documentation and a pinned diagram renderer; no database or
protocol migration is needed. Source review receipts introduce deliberate review
work for behavior and test changes. The large option reference increases page
size. Evidence records must not promote a historical test into current acceptance.

## Invariants and verification

Anonymous or revoked logins cannot read the handbook. All current users can find
it in either navigation context. Repository-authored content alone enters trusted
HTML. Diagram policy remains strict with readable failure fallback. Source edits,
additions, renames and deletions invalidate reviewed digests. Every security layer
and every documented scenario must retain explicit test scope and gaps.

Use unit/property tests for receipt identity, fail-closed validation and evidence
classification; LiveView tests for access and navigation; browser checks for
rendering; and the exported Nix check for packaged source and option drift.

## Implementation evidence

- Handbook LiveView (`marshall/lib/marshall_web/live/hldd_live.ex`, removed by ADR-0263) and
  compiled catalog (`marshall/lib/marshall/handbook.ex`, removed by ADR-0263) implement access
  and release-local content.
- Review gate (`scripts/hldd/gate.ex`, removed by ADR-0263) and
  coverage validation (`scripts/hldd/coverage.ex`, removed by ADR-0263) enforce recorded review
  currency and structural evidence requirements.
- Gate properties (`marshall/test/architecture/hldd_test.exs`, removed by ADR-0263) and
  web tests (`marshall/test/marshall_web/hldd_live_test.exs`, removed by ADR-0263) exercise the
  new boundaries. The [completion review](../reviews/2026-09-25-hldd.md) records
  passing application, property, native browser, release and packaged-source
  checks, together with their limits and separate deployment acceptance.
  The [reader authority correction](../reviews/2026-09-25-handbook-reader-verification.md)
  withdraws its original native ordinary-user inference while preserving the
  executed rendering evidence; ADR-0122 carries the corrected fixture and scope.
- Maintenance skill (`.agents/skills/hldd-maintenance/SKILL.md`, removed by ADR-0263) makes the
  review procedure discoverable; root guidance makes its use mandatory.

Retired by [ADR-0263](0263-retire-hldd.md); the removal is visible in the
[Marshall router](../../../marshall/lib/marshall_web/router.ex), which no longer
serves `/hldd`.

## Open questions

None. Validation and deployment results are recorded in the associated review.

## Related decisions

Superseded by [ADR-0122](0122-hldd-section-pages.md).

[ADR-0001](0001-architecture-governance.md),
[ADR-0028](0028-colocated-code-contracts.md),
[ADR-0074](0074-durable-lifecycle-state-machines.md),
[ADR-0119](0119-authenticated-control-room-reads.md).
