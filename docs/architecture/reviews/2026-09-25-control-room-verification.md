# Control room authority verification

## Scope and architecture impact

This improvement preserves ADR-0119's signed-in reads and the inherited
ADR-0065 requirement for current administrator membership plus a fixed five-minute
passkey elevation. It changes verification and documentation, with no production
API, persistence, domain ownership or deployment change.

The prior coverage contained fixed domain and LiveView cases, but no generated
combination of persisted roles, stale actor structs, mounted browser event guards
and stored login lifetime. There was no focused native Control room journey.

## Evidence and reviewed boundaries

[Generated histories](../../../marshall/test/marshall_web/control_room_history_test.exs)
exercise actual Ash actions and mounted LiveViews after promotion, demotion, signed
passkey verification, explicit locking, elevation expiry, session revocation and
stored login expiry. The independent model predicts read and write eligibility.
Fixed histories through the same oracle guarantee promotion, demotion, lock and
re-verification positive paths independently of generator sampling. Every denied
write preserves target role and administrative audit count; an allowed
write changes the target and adds one audit event. Forged or stale role fields do
not determine current authority. The property also checks the HTTP usage export.

[Native browser scenario](../../../nix/verification/tests/machines/control-room/browser.py)
uses source-built Marshall, HAProxy, PostgreSQL and Chromium in one NixOS VM.
The browser trusts the fixture CA and uses the configured HTTPS origin; HAProxy
also verifies its Marshall TLS backend. An ordinary user visits all ten Control
room landing pages, exports usage, and sends a forged role-change event. A virtual
WebAuthn authenticator registers and verifies through the real browser UI before
an administrator grants and removes a role and revokes the reader's session.
The test checks persisted role and audit state. Database fault injection then
simulates demotion and login expiry while the administrator's browser is mounted.
Read access survives demotion; mutation access does not. Revoked and expired
logins lose mounted views, fresh navigation and exports.

The native check uses one serving Marshall replica. Cross-replica propagation,
physical authenticator behavior, production rollout, populated drill-down pages,
and all other administrative mutation families remain separate coverage. It makes
no guest, storage isolation or independent physical-host claim. Seed tokens stay
in private fixture files; the test does not seed elevation receipts.

## Fixture findings

Initial machine runs were not acceptance. The shared service fixture's two
PostgreSQL connections lost readiness during rapid page loads; the focused fixture
now matches the deployed Overalls pool of ten and budget of 64. The unchanged hard
navigation sweep and exact export-200 assertion passed with that configuration.
This is bounded browser verification, not a capacity benchmark.

The first seed also left the one-time administrator bootstrap latch unconsumed.
The real first magic-link sign-in therefore promoted the supposed ordinary reader.
The fixture now represents an installed system with a completed bootstrap latch,
and asserts the reader's persisted non-administrator role immediately after sign-in.
Review identified the same unconsumed-latch pattern in the separate
HLDD fixture (`nix/verification/tests/machines/hldd/seed.exs`, removed by ADR-0263). Its correction and scoped
ordinary-reader acceptance are tracked separately by the verification campaign.

The browser waits for an actual connected LiveView after full-page transitions
before submitting mutations. A changed URL alone did not prove event handlers were
ready after the Security page's Continue link.

## Validation

- `MIX_TEST_PARTITION=verify003 mix test test/marshall_web/control_room_history_test.exs test/marshall_web/control_room_access_test.exs test/marshall/accounts/control_room_authority_test.exs`
  passed: **12 passed (1 property, 11 tests)**, seed 383359. The property generates
  25 role/elevation/session histories. The final generator caps histories at eight
  transitions so enrollment and verification remain within the separate ten-challenge
  resource bound.
- Pinned `ruff format`, `ruff check`, and explicit `ty check` on the browser script
  passed; ty resolves Playwright against the development shell's pinned interpreter.
- `MIX_TEST_PARTITION=verify003 mix precommit` passed; the suite reported
  **1014 checks (85 properties, 929 tests), zero failures, two exclusions**, seed 236232; terminal/dashboard/workspace
  browser checks and forced Dialyzer passed with zero errors or skipped findings.
  After bounding histories and adding fixed positive sequences, the final focused
  file passed **2 passed (1 property, 1 test)**, seed 746862.
- The final integrated `MIX_TEST_PARTITION=verify003 mix precommit` passed on
  `e9a262b0b478296aedad1abf29ca777e8d70dd38` with this change applied, including the
  earlier team and installer improvements. The suite reported **1020 checks
  (89 properties, 931 tests), zero failures, two exclusions**, seed 573829, in
  282.2 seconds. Terminal/dashboard/workspace browser checks and forced Dialyzer
  passed; Dialyzer reported zero errors, skipped findings or unnecessary skips.
- `prek run --all-files`, ADR and contract checks, HLDD source/coverage/options/views
  checks and `nix build .#checks.x86_64-linux.hldd --no-link` passed. Evidence-only
  documentation updates receive refreshed reviewed receipts and final gate checks.
- `nix build .#checks.x86_64-linux.control-room-browser --no-link` passed:
  **control-room-browser passed**, exit zero; VM script 59.57 seconds and browser
  journey 30.05 seconds. The passing derivation was
  `/nix/store/8s0vywc7aiq195s0vzkjrnjpqc2sbdv7-vm-test-run-overalls-control-room-browser.drv`.
  `nix log` on that derivation records the assertions and completed QEMU cleanup.
  Later evidence and integration documentation do not change its runtime assertions.

Initial application evidence was produced in an isolated worktree based on
`253cdcaa1e7b3c8e7a2039583cbc30d8f6ba1e14`, with this change applied; the final
integrated application gate uses the later base recorded above. The campaign
ledger records the final merged revision. The native derivation captures the exact
packaged test inputs and predates the unrelated team-owner protection integration.

## Contract review

Reviewed repository test-claim and secret boundaries, Marshall's database-backed
runtime authority, SQL sandbox ownership, the LiveAdminAuth current-authority
contract and Accounts stored-login/elevation contracts. The new property observes
both domain and browser results rather than substituting a policy implementation.
Native setup is disposable and authority assertions inspect resulting data.
No changed production caller or new public interface requires migration.
