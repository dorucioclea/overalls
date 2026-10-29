---
name: covenant
description: Add, maintain, and verify Covenant contracts for this repository's Elixir Mix applications.
---

# Covenant contracts

Use this skill when changing Covenant configuration, contract obligations, contract tests, or the contract verification gates for an Elixir application in this repository.

## Repository workflow

- Read the root `AGENTS.md`, the application's local guidance, existing `CONTRACTS` files, and relevant ADR evidence before editing.
- Keep Covenant in `only: [:dev, :test]` with `runtime: false`; never add it to production runtime dependencies.
- Use the pinned Hex release already adopted by the repository (`~> 0.2.0`). Preserve existing test-helper callbacks and append `Covenant.Formatter` rather than replacing formatters.
- Put obligations under the application's `contracts/` tree and executable tests under `test/contract/`. Use stable IDs of the form `<mix_app>.<component>.I<n>` and tag every contract test with its obligation ID.
- Preserve the existing `@cc` code-contract system. Run the `code-contracts` workflow for code changes; Covenant does not replace `CONTRACTS` or architectural evidence.

## Evidence discipline

Write obligations that are specific and evidence-backed. A BEAM contract test may establish behavior observable in the test VM, such as a codec invariant, privacy rule, accounting transition, or module loadability. It must not claim native Rust/KVM behavior, physical isolation, multi-host recovery, browser behavior, or production deployment evidence unless the test actually exercises that boundary. Link those claims to the existing ADR, machine, native, or integration evidence instead.

Generated module-loadability obligations are a valid bootstrap baseline, but label them as such and expand them with meaningful subsystem behavior when practical. Do not describe 100% Covenant coverage as complete system verification.

## Verification

From an application directory, run the relevant checks with the pinned runtime:

```sh
mix covenant.check --static --contracts contracts --test-path test/contract --root .
mix test test/contract --warnings-as-errors
mix covenant.check --no-run
```

Run `mix covenant.conditions --verbose` when changing contract conditions. Commit deterministic `contracts/coverage.json` and `contracts/coverage.static.json` when produced and valid; do not commit `_build/covenant/results` or temporary mutation matrices. Run the application's normal `mix precommit`; shared protocol changes also require Marshall and Lilly consumer checks.

For architecture, behavior, configuration, or verification changes, update the relevant ADR and run the repository's ADR checks. Review mutation survivors where mutation testing is available, recording surviving obligations honestly rather than weakening them silently.
