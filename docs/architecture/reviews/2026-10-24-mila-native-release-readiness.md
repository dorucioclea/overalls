# Mila native release readiness (2026-10-24)

## Scope and decision

This review examines release wiring and retirement readiness at `10b60d801`.
[ADR-0249](../decisions/0249-mila-rust-core-native-clients.md) remains accepted
and partially implemented. Its Rust core and native client direction authorizes
replacement of the release implementations; implementation complexity does not
require a new product decision. [ADR-0235](../decisions/0235-mila-desktop-clients.md)
retains per-platform development and release obligations. No decision is superseded
by this evidence update.

## Findings

| Severity | Observed implementation | Consequence and next action |
| --- | --- | --- |
| High | [Linux release](../../../nix/domains/artifacts/mila/default.nix) archives the Flutter `app` output. | A native Cargo test cannot establish what the published tarball contains. Build a Rust/GTK derivation with the shared catalogs, GTK/libadwaita runtime closure and desktop entry; exercise the installed artifact before switching the release output. |
| High | [Android packaging](../../../nix/domains/artifacts/mila/android.nix) invokes the Flutter build. | Native Gradle/JNI sources do not replace the shipped APK. Supply pinned SDK/NDK and Gradle dependencies, assemble the native APK, and verify installation and authenticated device behavior before replacing this output. |
| High | [Source bundle](../../../nix/domains/artifacts/mila/source-bundle.nix) supplies Dart locks, pub cache and patched dartssh2 to existing consumers. | Removing these inputs while consumers still build Flutter breaks the bundle contract. Define native source/dependency contents and update consumers together, preserving checksums and reproducibility. |
| High | [Parity matrix](../../../mila/native/PARITY_MATRIX.md) retains 13 rows with partial platform evidence. | Input validation and controller tests do not prove live transport, platform custody, push delivery or packaged user journeys. Close the explicit per-platform gaps using actual build and integration receipts before deletion. |

These are accepted requirements still unimplemented or unverified, not reasons
to retain Flutter permanently. The [workflow](../../../.github/workflows/mila-builds.yml)
contains native jobs alongside Flutter consumers. Job definitions establish intended
checks, not successful execution for the current revision.

## Localization prerequisite

Commit `8d1041710` moved catalog sources to
[`mila/localization/catalogs`](../../../mila/localization/catalogs).
The [Linux build script](../../../mila/native/linux/build.rs) and
[Android build](../../../mila/native/android/app/build.gradle.kts) now select that
shared location. This removes their catalog-source dependency on the Flutter app
tree. The sources remain ARB; relocation alone does not establish gettext migration,
translation completeness, or platform rendering acceptance.

## Implementation and acceptance sequence

1. Build native release artifacts alongside existing outputs, preserving the full
   repository-relative Rust path dependencies and shared catalog inputs.
2. Verify each installed artifact, its runtime dependencies, and authenticated
   platform journeys. Record revision, command, result and tested scope.
3. Replace source-bundle consumers and publication workflows with the verified
   native artifacts. Preserve platform signing and integrity requirements.
4. Remove Flutter sources, tooling and dependencies only after all applicable
   matrix cells have sufficient evidence; run native-only builds and integration
   checks on the resulting tree.

The [deletion checker](../../../mila/native/check_flutter_deletion.exs) is a
structural aid. Text matching for release wiring and source absence cannot prove
artifact contents, signing, transport behavior or parity. It is not a replacement
for the acceptance evidence above.

## Verification scope

This review inspected source paths and build definitions. No native release build,
installed-artifact journey, platform signing or physical-device test was executed
for this review. Documentation validation results are recorded separately from
those outstanding execution obligations. Architecture impact is an implementation
evidence correction under ADR-0249 and ADR-0235; accepted rationale is unchanged.
