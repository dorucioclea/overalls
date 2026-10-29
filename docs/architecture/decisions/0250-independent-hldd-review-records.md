# ADR-0250: Independent HLDD review records

- ID: ADR-0250
- Date: 2026-10-20
- Status: superseded
- Implementation: implemented
- Components: repository governance, HLDD
- Supersedes: ADR-0122
- Superseded by: ADR-0263

## Context

Concurrent Codex sessions repeatedly conflict in the minified receipt manifest
and topology snapshot. A host-retirement session reported conflicts in both files
and stale receipts across all groups after rebasing. Broad source hashes and
overlapping chapter hashes require reviewing unrelated work repeatedly even after
textual conflicts are resolved. Merely formatting or splitting the aggregate
manifest cannot remove that coupling.

The user authorized a complete redesign, suggested YAML files with frontmatter,
and approved implementation with trunk delivery. Mandatory explicit source and
documentation review remains required.

## Decision

Replace aggregate group receipts with independent Markdown receipts containing
YAML frontmatter and a prose rationale. Mirror each source's repository path under
`docs/hldd/reviews/sources/`, appending `.md`; keep a separate receipt per chapter
under `docs/hldd/reviews/chapters/`. Stable YAML group definitions retain source
prefixes, chapter associations and exactly one catch-all.

Source currency binds the path, bytes and applicable group definitions. Source
receipts retain the hashes of chapters inspected during review as historical
context. A subsequent chapter edit invalidates its own receipt, not every source
that references that chapter. This replaces only the aggregate invalidation
semantics inherited by ADR-0122 from ADR-0121. All other handbook presentation,
access, evidence, scenario and structural requirements remain in force.

Deletions require explicit tombstones; additions, renames and restoration require
review. Recording is explicit and may select individual paths. Current receipts
are never rewritten. An `updated` source review requires a changed chapter in the
selected review; otherwise require a concrete `no-impact` rationale. Checks remain
read-only and fail closed.

Split scenario data by scenario ID and generated allowlisted topology by host into
YAML files. Retain deterministic generated chapters and evaluated topology checks.
Use pinned PyYAML through a batched adapter so the standalone Elixir gate does not
depend on loading a product application. Refuse duplicate keys, aliases, custom
tags and values outside the supported JSON data model.

Migration validates every legacy group against an unchanged baseline before
writing, transfers its exact evidence and rationale, and never approves changed
destination bytes. Remove the old format rather than maintaining two authorities.

## Alternatives

Pretty-printing the existing JSON reduces textual conflicts but retains broad
invalidation. Per-group files still conflict between agents in the same component.
Automatically refreshing hashes or using an accepting merge driver loses explicit
review of merged content. Git-commit-only receipts would not validate packaged
source trees lacking Git history.

## Consequences

Independent edits merge without rewriting unrelated reviews. The repository gains
many small files and a pinned development/check-time YAML dependency. Same-path
source or chapter edits still require deliberate merge reconciliation. Legacy
branches must adopt the new format. A current receipt still cannot prove that its
rationale or the handbook is factually correct.

## Invariants and verification

Test actual Git merges of independently reviewed branches in the same group;
source/chapter independence; selection isolation; changed merged bytes; additions,
deletions, renames, restoration, mapping drift; malformed YAML and misplaced
receipts; stale migration refusal; and Git/packaged inventory parity. Existing
scenario and view checks must retain their refusal behavior. Native/browser tests
remain separate evidence for unchanged delivery boundaries.

## Implementation evidence

- Gate (`scripts/hldd/gate.ex`, removed by ADR-0263) implements independent currency and scoped recording.
- Migration (`scripts/hldd/migration.ex`, removed by ADR-0263) preserves validated legacy evidence.
- YAML adapter (`scripts/hldd/yaml_io.py`, removed by ADR-0263) parses closed data and writes atomically.
- Regression tests (`marshall/test/architecture/hldd_test.exs`, removed by ADR-0263) exercise merge and refusal cases.
- Workflow (`docs/hldd/README.md`, removed by ADR-0263) explains review, migration and concurrent changes.

The merge/refusal regressions and packaged-source Nix gate passed; see the [review](../reviews/2026-10-20-hldd-independent-reviews.md)
for executed checks and remaining gaps.

Retired by [ADR-0263](0263-retire-hldd.md); the removal is visible in the
[Marshall router](../../../marshall/lib/marshall_web/router.ex), which no longer
serves `/hldd`.

## Open questions

None.

## Related decisions

[ADR-0122](0122-hldd-section-pages.md) retains section delivery and inherited
maintenance requirements except for the invalidation semantics replaced here.
[ADR-0028](0028-colocated-code-contracts.md) governs code contracts.

Superseded by [ADR-0263](0263-retire-hldd.md), which retires the HLDD handbook
and its review gates.
