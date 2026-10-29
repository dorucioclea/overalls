# Mila Apple host app and build targets (2026-10-29)

## Scope and decision

This review covers the change on top of `e99221968` that makes the native Apple
client buildable and runnable as an app on iOS and macOS. It stays within
[ADR-0235](../decisions/0235-mila-desktop-clients.md) decision 4 (one
`mila-build <platform> <dev|release>` command with refusing, self-verifying
release targets) and
[ADR-0249](../decisions/0249-mila-rust-core-native-clients.md) (SwiftUI over the
Rust core). No decision is superseded. ADR-0235's implementation evidence is
corrected and its remaining gaps extended.

## Findings at `e99221968`

| Severity | Observed implementation | Consequence and action |
| --- | --- | --- |
| High | `MilaWebControls.swift` declared `webView(_:decidePolicyFor:decisionHandler:)` without the `@MainActor @Sendable` handler that `WKNavigationDelegate` requires. Swift reported only a "nearly matches" warning. | WebKit never called the delegate, so the HTTPS same-origin navigation guard did not run in the embedded web view. Fixed with one shared `MilaWebNavigationGuard`, a `web-navigation-same-origin` contract and an XCTest that calls the guard through the optional protocol requirement. Reverting the signature makes that test fail. |
| High | `mila/native/apple/build.sh` ran `swift build` in the caller's directory, ignored the platform and used GNU-only `tar --sort`. | `mila-build` failed from the repository root, `ios` built nothing for iOS and the release produced a `.build` tarball rather than an app. Rewritten as below. |
| High | No host app existed; `MilaNativeApp` has no `@main`. | Nothing could be launched. Added the `App` host package, whose only code is `MilaNativeApp.main()`. |
| Medium | `List(selection:)` with a non-optional `MilaRoute` is unavailable on iOS. | The package declared iOS 18 but did not compile for iOS; `swift test` builds only macOS. Fixed with an optional binding; CI now builds `ios dev`. |
| Medium | `MilaStrings` read catalogs through `Bundle.module`, which checks only the app root and the build directory. | A signed macOS app cannot carry a bundle at its root, so a shipped app would have hit `Bundle.module`'s fatal error. It now checks `Bundle.main.resourceURL` first. |
| Low | `MilaWebControlsTests.testSessionInvalidationClearsPublishedWebState` was outside its class. | XCTest never ran it. Moved into the class; it passes. |
| Low | nixpkgs' `rustc` has no iOS standard library. | iOS builds needed rustup. On Darwin, devenv now takes the same 1.97.1 release from rust-overlay with `aarch64-apple-ios` and `aarch64-apple-ios-sim`. Linux shells keep the nixpkgs toolchain. |

## Build targets

`build.sh` uses the system Xcode and clears the Nix compiler variables. It
builds `mila-ffi` for the Rust target, builds `App` for the matching Swift
triple, assembles `Mila.app`, writes localized `NSFaceIDUsageDescription`
from the catalogs' existing `lockExplain` message and signs the app. A release
requires the team, identity, profile name, version and (macOS) notary profile.
It refuses a profile for another team or application identifier, never falls
back to ad-hoc signing, and verifies the signature, signing team and, on macOS,
an `Accepted` notarization, the stapled ticket and `spctl`.

## Checks run

On aarch64-darwin with Xcode 26.2, inside `devenv shell` with the rust-overlay toolchain:

- `mila-build macos dev` and `mila-build ios dev` built and signed Mila.app.
- The macOS dev app launched with `App/.build` moved aside, so catalog loading did not use the build-directory fallback.
- `mila-run ios` installed and launched the app on an iPhone 17 Pro simulator, showing the Machines screen.
- `swift test` in `mila/native/apple` executed 82 tests with 4 skipped and 0 failures.
- `python3 -m unittest mila/localization/test_apple_infoplist_strings.py` passed 5 tests.
- `mila-build macos release` and `mila-build ios release` with no inputs exited 1 naming `MILA_APPLE_TEAM`; a non-semantic `MILA_VERSION` and a missing `MILA_NOTARY_PROFILE` were refused.

No release target has run with real signing material.

## Remaining gaps

- Ad-hoc dev builds have no keychain entitlements, so `MilaDeviceSigner`
  cannot create a Secure Enclave key and sign-in is unavailable. ADR-0235's
  `MILA_SOFTWARE_KEYS` dev custody is not implemented in Swift.
- No notification service extension, app icon or iOS device dev target exists.
- Builds are arm64 only; there is no Intel or universal macOS binary.
- The Windows release job still invokes the removed Dart planner
  (`mila/tool`); it is outside this Apple change.
