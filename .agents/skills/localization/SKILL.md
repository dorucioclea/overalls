---
name: localization
description: Implement or review localization of Elixir, Phoenix, browser, documentation, and terminal user-facing text using the repository's approved Elixir Localize integration, including locale negotiation, catalogs, formatting, and bidirectional UI behavior.
metadata:
  short-description: Localize user-facing strings safely
---

# Localization

Use this skill whenever changing a user-facing string, adding a locale, changing locale selection, or reviewing localization in Marshall, Porsche, or shared protocol presentation code. Read the repository's architecture and component guidance first, then inspect the pinned Localize dependency and its documentation before choosing APIs. Do not invent a translation-key or formatting abstraction when Localize/Gettext already provides one.

## Discovery and boundaries

- Inventory human-facing text across HEEx, LiveView modules, mailers, browser JavaScript, CLI/SSH presentation, and public documentation before editing. Keep logs, telemetry, protocol field names, command names, JSON keys, and other machine contracts language-neutral unless the task explicitly changes them.
- Include plain-text HTTP refusal and sign-in guidance in the human-string audit. Preserve successful installer scripts, downloads, checksums, raw files, CSV fields, JSON and redirect/session keys as machine contracts; keep status codes, privacy and session-free public routes unchanged.
- Inspect accessible names, screen-reader state text, third-party component overrides, command descriptions, missing-data fallbacks and prose interpolated into translated messages. Extraction cannot discover raw strings that never call a native translation API. Configure vendor accessibility copy through its public API; never translate terminal bytes or patch vendored assets.
- Find existing Gettext domains, locale configuration, catalog generation, interpolation conventions, and tests. Preserve established domains and identifiers; use stable source identifiers supplied by Localize/Gettext rather than ad-hoc atoms or translated strings.
- Localize public `/docs/*` prose only.
- Treat translations as typed interfaces: every placeholder, plural/select variable, markup boundary, and format option must remain valid in every locale. Validate external locale tags before using them.
- Validate translated input examples against the receiving field grammar. HTTP header names, integration identifiers, email examples and literal repository identities must remain valid machine syntax; record exact technical-literal reviews when preserving them. Never translate a sample merely to remove a source-equality count.

## Locale policy

- Read `Marshall.Localization.supported_locales/0` in `marshall/lib/marshall/localization.ex` for the authoritative supported tags; keep Porsche catalogs and the versioned envelope aligned with that policy.
- Define one central, typed policy for supported BCP 47 tags, canonicalization, `Accept-Language` negotiation, fallback, and text direction. Use the product's documented precedence (explicit user override, then browser preference, then default) and ensure an override is authorized and isolated to that user/session.
- Keep locale data bundled and deterministic in production. Unsupported, malformed, oversized, or ambiguous input must fall back safely without raising from request rendering.
- Derive `lang` and `dir` from the validated locale. Use logical CSS properties and semantic direction-aware layout; test both LTR and RTL with long strings and interpolated user data. Isolate interpolated values where the formatter supports bidi isolation.
- Use `Marshall.Localization.direction/1` for repeated direction lookup. Its bounded CLDR-derived table avoids full locale matching for every interpolated message; keep caches limited to the validated supported locale set.
- Check glyph coverage when adding a locale or translated text. Follow ADR-0207:
  JetBrains Mono remains the primary/grid font and bundled Noto faces supply
  missing scripts. Read `marshall/priv/static/fonts/README.md` for the pinned
  assets and check commands. Preserve native shaping and validated HTML language;
  do not force complex-script graphemes into Latin character cells or rely on a
  developer's installed fonts to establish coverage.

## Catalog and implementation workflow

Catalogs use Gettext's native `priv/gettext/<locale>/LC_MESSAGES/<domain>.po` layout, with matching root `<domain>.pot` templates. Use explicit `dgettext`, `dngettext` and context/noop variants; runtime lookups must name the same domain. Domains are catalog organization, not an opaque message-key registry. Preserve source strings and interpolation syntax when moving messages.

Marshall domains are `shared` (shell, navigation and reusable core/time components), `auth`, `account`, `teams`, `machines` (including launch, clone and resize), `terminal`, `agents`, `artifacts` (artifact browser, sharing, storage and administrator moderation), `integrations`, `git`, `inference`, `editor`, `ssh`, `downloads`, `browser` (client-side notices), `documentation` (public guides) and `errors`. Administration is partitioned into `admin_access`, `admin_audit`, `admin_git`, `admin_jobs`, `admin_nodes`, `admin_operations`, `admin_users` and `admin_workloads`. Porsche domains are `onboarding`, `help`, `management` and `sessions`.

Put a message in the domain owning its rendering call. Equal English wording in separate features remains separate domain identities; only reusable component messages belong in `shared`. Never introduce new application messages into `default`. For mass moves, use the repository catalog migration script with a scratch baseline and inspect its dry-run report before writing. Preserve exact translations and per-form reviews; fuzzy matching is not a substitute for migration.

1. Extract or identify source messages and assign them to the existing catalog/domain. Preserve source context and placeholders. For Marshall documentation, regenerate `mix run --no-start scripts/extract_documentation.exs` before native `mix gettext.extract`. Marshall precommit also runs `mix localization.documentation`, which compares the generated source against the current documentation and shared command summaries; native extraction alone cannot detect an outdated generated source file. Reconcile exact domain/context/source/plural identities without fuzzy reuse. Both Marshall and Porsche precommit gates run `mix gettext.extract --check-up-to-date`; this checks native source freshness, including reference locations, and force-compiles the application. Catalog-to-template equality alone does not prove extraction freshness.
2. Use the approved Localize API for new messages and structured formatting; retain legacy Gettext calls when compatibility requires them. Prefer CLDR-backed number, date, time, list, plural, and relative-time formatting over hand-built strings.
3. Add all supported locale catalogs (including English source/fallback) and translations or explicit reviewed fallbacks. Check PO syntax, duplicate/context collisions, placeholder parity, plural rules, and catalog completeness in CI. Track empty, fuzzy and source-equal entries separately. English prose copied into a target catalog is untranslated. Identical brands, units, commands and genuine cognates require an exact per-message review; do not blanket-exempt a locale or classify every nonempty entry as complete. Never apply approximate/fuzzy catalog merges without reviewing the source/translation pair.
   For intentionally unchanged text, record an exact review in `marshall/priv/gettext/reviewed_source_equal.json`: application, locale, domain, nullable context, source and plural source, plural-form index, reason and review note. Inspect each message in its locale. The checker rejects stale, duplicate, fuzzy or structurally invalid reviews and reports reviewed invariant forms separately from translations. Never use wildcards or locale-wide exemptions. A copied form in an otherwise translated plural remains a gap unless that exact form has an eligible review.
4. Use the application’s Gettext interpolation adapter for legacy `%{name}` messages; it delegates RTL value isolation to Localize’s MF2 formatter. Keep external data in bindings, never in formatter source. For newly authored MF2 messages use the pinned library’s native API and explicit bidi options. Preserve missing-binding behavior and test mixed-script names/IDs, plural counts and LTR byte compatibility.
5. Extract documentation prose, headings, table cells and generated reference summaries. Preserve fenced examples/diagrams and inline command/link tokens. Validate source identity after regeneration; new source units must not silently inherit an unrelated translation.
6. For JavaScript, expose only validated locale data and generated catalogs from the server's build pipeline. Never embed secrets, arbitrary user input as code, or an unvalidated locale in a script.
7. For Porsche or protocol-facing human output, carry a validated locale only in a versioned, backward-compatible envelope. Keep machine/JSON output stable and default old clients/versions to the documented fallback locale.

## Verification

- Add focused tests for canonicalization, quality-weighted browser negotiation, fallback, persistence/reset, authorization and cross-session isolation, direction, and malformed input.
- Test every catalog for syntax, coverage, nonempty messages where required, placeholder/plural parity, and compilability. Test representative long and mixed-script strings.
- Run `mix localization.catalogs` as an enforcing gate: default execution and `--strict` reject untranslated non-English forms, whitespace-only forms, fuzzy entries and unreviewed source copies. `--report-only` is a diagnostic command, not passing completeness evidence; it still rejects malformed catalogs and invalid exact reviews. Retain negative entrypoint tests so CI cannot silently become report-only.
- The reusable Bombadil probe is `marshall/scripts/localization_browser/run.py PRIVATE_CONTEXT NEW_OUTPUT_DIRECTORY`. Use an isolated loopback fixture with owner-private context and output; never publish login URLs, tokens or raw traces. The packaged `localization-account-porsche` NixOS check exercises ordinary account settings and trusted Porsche SSH. Record executed language, route, theme, viewport and machine-control coverage separately from test presence.
- Verify bundled font integrity and coverage of catalog text and locale autonyms.
  Use Bombadil for new browser checks of representative native script shaping,
  missing glyphs, long strings, both themes, LTR/RTL and mobile/desktop layout.
  Character coverage alone does not establish browser legibility or shaping;
  keep visual evidence scoped to the languages and routes actually inspected.
- Run the relevant Elixir formatter/compiler/test/type and contract checks, plus Marshall's Monospace Web and browser probes for presentation changes. Run architecture maintenance checks when behavior, configuration, protocols, operations, or verification evidence changes. Report missing native-language review honestly.

For detailed repository-specific locale lists or Localize API usage, consult the current localization ADR and any focused references added beside this skill; do not copy stale API examples into application code.
