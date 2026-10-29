# ADR-0122: Separate handbook sections and bounded browser content

- ID: ADR-0122
- Date: 2026-09-25
- Status: superseded
- Implementation: implemented
- Components: Marshall Web, documentation, repository governance
- Supersedes: ADR-0121
- Superseded by: ADR-0250

## Context

After the initial handbook deployment, the user reported slow loading and browser
out-of-memory crashes and explicitly requested separate pages per section. The
single page sent twenty chapters, including the full option reference, and rendered
all diagrams together. Native presentation tests passed but did not measure heap
use on the user's browser.

## Decision

Make `/hldd` a contents page containing only section identifiers and titles. Serve
one compiled chapter at `/hldd/SECTION`. Select only known catalog identifiers;
unknown identifiers return to contents without selecting a filesystem path.
Section navigation replaces the previous chapter and its diagram hook. Direct
links, previous/next controls and browser history use the same current-login
boundary. Source inter-section links compile to their authenticated section URLs.

Carry forward ADR-0121's signed-in navigation, reviewed static content, local
strict Mermaid renderer, generated references, mandatory skill, blocking review
receipts and explicit layered security evidence. No domain, persistence, guest
isolation or operational authorization changes are introduced. The user's explicit
design correction establishes acceptance.

The user's subsequent documentation requirement adds separate Ash domain and
deployment topology views. Each combines source-derived ownership/placement
diagrams with maintained interaction diagrams and concise responsibility,
authority and verification-gap explanations. Discover literal Ash domains and
resources from application source; project only allowlisted public placement
fields from evaluated fleet configurations. Domains do not imply separate services,
and declared placement does not establish live health. Both views are mandatory
in the maintenance skill and blocking checks, independent of refreshed receipts.

## Alternatives

Collapsing sections visually would retain their bodies and diagrams in the
browser. Lazy rendering on a single document would still grow with reading and
would not satisfy the requested separate pages. Public static pages would change
the authentication boundary. None is selected.

## Consequences

Initial reading and each navigation send one bounded section or the small contents
list. Browser search and printing apply to the current section. Old `/hldd#SECTION`
bookmarks reach contents; section links now use `/hldd/SECTION`. Large reference
sections remain larger than prose chapters. No numeric heap guarantee is claimed.

## Invariants and verification

The index includes no chapter bodies or diagrams. Every known section URL contains
exactly one chapter. Switching sections and returning to contents remove previous
bodies and diagrams. Unknown IDs cannot become paths; expired/revoked logins cannot
navigate to another section. Previous/next controls preserve catalog order.

Use unit/property tests for catalog identity, metadata-only contents and invalid
IDs; LiveView tests for direct access, payload scope, navigation and revocation;
and NixOS browser tests for actual release navigation, browser back, all diagrams,
themes, mobile containment and public-route isolation. These tests do not establish
resource limits for every browser or physical authenticator acceptance.

Property/unit checks reject changed domains/resources/hosts, evaluated placement
drift and removed diagrams or explanations. Native browser checks visit both new
sections directly as well as through navigation. Human source review remains
necessary for interaction semantics and security claims; the source extractor
covers literal declarations, not extension-generated resource versions.

## Implementation evidence

- Catalog (`marshall/lib/marshall/handbook.ex`, removed by ADR-0263) exposes summaries and one
  compiled chapter lookup; it rewrites inter-section links.
- LiveView (`marshall/lib/marshall_web/live/hldd_live.ex`, removed by ADR-0263) and
  diagram hook (`marshall/assets/js/handbook.js`, removed by ADR-0263) bound rendered content
  and stop disposed hooks before further diagram work.
- Catalog tests (`marshall/test/marshall/handbook_test.exs`, removed by ADR-0263),
  web tests (`marshall/test/marshall_web/hldd_live_test.exs`, removed by ADR-0263) and
  native browser (`nix/verification/tests/machines/hldd/browser.py`, removed by ADR-0263) test these boundaries.
- Maintenance skill (`.agents/skills/hldd-maintenance/SKILL.md`, removed by ADR-0263) preserves
  section delivery and preferred machine/property verification. Passing application,
  native browser, release and deployment results are scoped in the
  [review](../reviews/2026-09-25-hldd-sections.md).
- Visual view checker (`scripts/hldd/views.ex`, removed by ADR-0263),
  public Nix projection (`scripts/hldd/topology.nix`, removed by ADR-0263) and
  regression properties (`marshall/test/architecture/hldd_views_test.exs`, removed by ADR-0263)
  enforce required domain and topology views. The
  [visual-view review](../reviews/2026-09-25-hldd-views.md) records scope and validation.
- [Reader authority review](../reviews/2026-09-25-handbook-reader-verification.md)
  corrects the historical native ordinary-user claim: the old fixture promoted its
  first reader through installation bootstrap. The repaired fixture completes
  bootstrap separately and checks the persisted reader role after login and at
  completion. Native stale-cookie and mounted-navigation refusals complement
  generated chapter histories covering revoked, expired and deleted logins. Its
  integrated native run also checks the shared Source code link's position and
  destination without contacting GitHub, and fixed fixture sign-in diagnostics.

Retired by [ADR-0263](0263-retire-hldd.md); the removal is visible in the
[Marshall router](../../../marshall/lib/marshall_web/router.ex), which no longer
serves `/hldd`.

## Open questions

None. The reported browser heap was not captured; acceptance is scoped to removing
all-section delivery and off-page diagrams, with explicit native browser evidence.

ADR-0250 replaces only aggregate review invalidation with independent source and
chapter receipts. All section delivery and other maintenance requirements remain
in force; see [independent review records](0250-independent-hldd-review-records.md).

## Related decisions

Supersedes [ADR-0121](0121-authenticated-hldd.md).

[ADR-0001](0001-architecture-governance.md),
[ADR-0028](0028-colocated-code-contracts.md),
[ADR-0119](0119-authenticated-control-room-reads.md).
