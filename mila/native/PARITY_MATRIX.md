# Mila native parity matrix

This matrix is the migration gate for ADR-0249. It compares the behavior in
the retained Flutter client with the native shells. A row is **implemented**
only when the native UI, its Rust adapter, and a platform test or build
receipt cover the behavior. A controller, command classifier, or localized
label by itself is **partial** evidence; it does not prove an end-to-end
workflow.

## Status legend

- **partial**: native code or a focused test exists, but an end-to-end user
  workflow, persistence, OS integration, or release evidence is missing.
- **open**: no native implementation has been found for the Flutter behavior.
- **implemented**: native workflow and platform verification cover the listed
  behavior. No row currently meets this bar for every platform.

## Feature matrix

| Flutter behavior (source of truth) | Rust/core evidence | Apple (SwiftUI) | Android (Compose) | Linux (GTK4/libadwaita) | Windows (WinUI/.NET 10) |
| --- | --- | --- | --- | --- | --- |
| Deployment list, add, forget, select (`features/deployments_screen.dart`, `forget_deployment.dart`) | Route and host validation; device-key policy | partial: durable `MilaDeploymentSessionCoordinator` with SwiftUI picker, selection, forget, reconnect and generation fencing; live approval journey remains open | partial: `MilaDeployments.kt` persists deployments, exposes Compose selection/Forget controls and authenticated reconnect; complete trust/device journey remains open | partial: validated host entry and selection, durable XDG restore, GTK Reload/Forget controls with idempotent clearing; deployment list and complete sign-in journey remain open | partial: host entry, connect state, and durable LocalApplicationData store; approval lifecycle remains open |
| Sign-in, approval, reconnect (`sign_in_screen.dart`, `session.dart`) | `mila-session` SSH listing, certificate checks and bounded `whoami --json` approval envelope | partial: FFI/session scaffolding and live HTTPS trust enrollment; approval and lifecycle not wired | partial: persisted deployment, one live certificate-authenticated session, validated HTTPS approval browser action, same-session `whoami` polling and Android instrumentation covering approval completion plus a fresh packaged reconnect; real deployment/device journey remains open | partial: validated deployment is required before GTK sign-in enters the generation-scoped reducer; `SignInCoordinator` reconciles trust, `CurlTrustFetcher` performs redirect-free HTTPS trust retrieval, `XdgTrustStore` persists owner-only canonical trust bytes, and `FileDeviceSigner` enforces owner-only P-256 key files with signature tests; live browser approval/device journey remains open | partial: generation-scoped approval/expiry/reconnect reducer and typed approval-page launcher; live browser approval outcome and backend reconnect transport remain open |
| Machine list/detail/snapshot (`machines_screen.dart`, `machine_screen.dart`) | bounded machine snapshot/list projection | partial: shell only; no complete list/detail | partial: authenticated Rust session listing, Compose machine selection/detail and typed mutation state; packaged device journey remains open | partial: authenticated session listing projection, bounded GTK machine rows/detail, and permission-aware display; live deployment journey remains open | partial: authenticated Rust listing FFI, bounded typed rows, selection/detail projection and mutation gating; live Windows backend journey remains open |
| Machine create/resize/start/stop/pause/resume/delete (`machine_form.dart`, `machine_actions.dart`) | command parsing/classification and policy | partial: authenticated SwiftUI create/resize forms dispatch through `MilaLiveSession` Rust FFI; remaining lifecycle actions and live deployment journey remain open | partial: Compose create/resize forms and authenticated Rust mutation seam with bounded inputs; complete UI session binding remains open | partial: GTK create/resize/start/stop/pause/resume controls dispatch through authenticated `LiveSession` with canonical request IDs; live deployment journey remains open | partial: authenticated Rust start/stop/pause/resume/delete/create/resize dispatch with bounded WinUI inputs; live Windows backend journey remains open |
| Machine sharing (`sharing_controller.dart`) | authorization policy primitives | partial: typed SwiftUI controller and FFI request boundary; authenticated share transport remains open | partial: typed principal validation, authenticated mutation seam, and Compose sharing controls bound to live listings; packaged device journey remains open | partial: authenticated `LiveSession::share_mutation` validates role/email/request IDs and GTK add/remove controls require sign-in; live deployment journey remains open | partial: authenticated Rust share mutation FFI with typed role/email/request validation and WinUI add/remove controls; live Windows backend journey remains open |
| Threads, turns, prompts, answers, plan approval (`threads/*`) | route and command validation; bounded thread response decoding | partial: route/shell and typed machine workflow; authenticated session lifecycle remains open | partial: authenticated Rust/JNI thread listing and closed-command actions with bounded Compose state/input; packaged device journey remains open | partial: authenticated `LiveSession::thread_action` for bounded list/show/turns responses plus GTK Prompt/Answer/Plan controls gated on sign-in; mutations require bounded stdin where used and canonical request IDs, while the live deployment journey remains open | partial: bounded typed thread listing and Show/Turns/Read/Prompt/Answer/Plan controls dispatched through authenticated Rust FFI; live backend remains open |
| Terminal attach/stream/input/resize/reconnect/kill (`terminal/*`) | bounded terminal reducer, permission/dimension validation and text bounds | partial: `MilaTerminal.swift` and live-session adapter; native PTY stream remains open | partial: bounded renderer with authenticated-session-gated attach/input/resize and sanitized receive projection, reconnect tests; live PTY transport/device journey remains open | partial: `TerminalStream` generation-scoped attach/output/reconnect/kill, bounded text renderer, authenticated-session-gated GTK lifecycle controls and input/resize validation; `HostPtyTransport` now binds the authenticated session generation to the Porsche SSH/PTY client with lifecycle tests; GTK stream wiring and live deployment journey remain open | partial: generation-fenced bounded renderer with authenticated Rust-session gating for attach/input/resize; live PTY transport/reconnect/device journey remains open |
| Web controls/webview (`web/*`) | bounded web endpoint projection and web command classification | partial: typed HTTPS endpoint, authenticated `MilaLiveSession` web transport and native WKWebView wrapper; WebView lifecycle and live deployment journey remain open | partial: authenticated Rust web show/set, machine-bound endpoint validation, optimistic revision requirement, and Compose WebView; packaged device journey remains open | partial: authenticated `LiveSession` web show/set with optimistic revision and bounded HTTPS endpoint projection; GTK browser launch and host transport journey remain open | partial: authenticated Rust web-show binding, session-gated WinUI controls, WebView2 embedding, and exact HTTPS origin fencing; live backend lifecycle remains open |
| SSH keys (`ssh_keys/*`) | key policy and device signer boundaries | partial: device signer plus typed authenticated key list/revoke FFI and Settings UI; CI Swift verification remains open | partial: `MilaSshKeys.kt` authenticated-session store, bounded JSON decoder, opaque-id revoke with at-most-once request IDs, and controller tests; packaged device approval/reconnect journey remains open | partial: revoke command validation only | partial: authenticated Rust FFI list/revoke wrappers, generation-fenced controller and WinUI projection; live Windows CI journey remains open |
| Push notifications/devices (`notifications/*`) | push registration/poke validation | partial: UserNotifications authorization and device metadata store; APNs delivery integration remains open | partial: `MilaNotifications.kt` OS-permission-gated registration, Rust-validated metadata bound to an authenticated session, durable identifier/toggle/remove CRUD, and tests; FCM delivery and server-side device CRUD remain open | partial: local desktop notification capability with explicit enablement and fail-closed registration state, plus authenticated Rust device list/remove/preferences projections, bounded command formatting and refusal tests; Susan has no Linux push provider | partial: authenticated typed WNS channel metadata validation/controller and runner provider hooks; live channel exchange, Susan delivery and Porsche device CRUD remain open |
| App lock (`lock/*`) | lock/device-key persistence boundaries | partial: durable Swift lock lifecycle and foreground re-authentication are implemented; platform authenticator integration remains unverified | partial: lifecycle, persisted lock state, Android BiometricPrompt integration, and unavailable-authenticator refusal coverage; broader device coverage remains open | partial: explicit unavailable capability state | implemented: typed Windows Hello broker and lock/unlock verification controller; CI smoke coverage |
| Settings, appearance, locale (`settings_screen.dart`, `preferences.dart`) | locale policy and generated catalogs | partial: design tokens, catalog loader, and persisted preferences | partial: design tokens, catalog loader, persisted SharedPreferences deployment/settings, and canonical BCP-47 locale validation | partial: catalog loader, GTK controls, and XDG settings persistence | partial: catalog loader, GTK controls, and XDG settings persistence |
| Deep links and share/open actions (`routes.dart`, web/share providers) | canonical route parser in Rust/Linux adapter | partial: route tests, app integration open | partial: `MilaDeepLinkController` accepts only canonical typed targets and rejects stale lifecycle generations, malformed IDs, and command-like query links; `MilaNativeRoot(initialRoute:)` projects validated targets into Compose navigation; Android VIEW and SEND intent routing now accepts only canonical navigation targets; authenticated share-provider completion remains open | partial: bounded typed multi-URI activation now classifies unknown, signed-out and authenticated deployment targets; target widgets and share-provider integration remain open | partial: canonical activation parser and WinUI external activation/share routing with smoke coverage; authenticated share-provider completion remains open |

The matrix deliberately records gaps even where a native button calls a Rust
classifier. ADR-0249 requires the Rust core to authorize real mutations and
the native layer to verify lifecycle, secure storage, and release behavior.

## Verification commands

Run from the repository root inside `devenv shell` where the platform toolchain
is available:

```sh
cargo test --manifest-path mila/rust/Cargo.toml --workspace
cargo test --manifest-path mila/native/linux/Cargo.toml --locked
./gradlew -p mila/native/android test
swift test --package-path mila/native/apple
dotnet test mila/windows-dotnet/Mila.Windows.csproj
```

The first two commands provide current Rust/core and Linux evidence. Android,
Apple, and Windows commands require their respective SDKs and are expected to
be run by native CI; a successful compile alone does not change a row to
implemented. Before Flutter removal, each row must have a native end-to-end
receipt on all applicable platforms and the Flutter source/build references
must be absent.

## Review record

This is a migration review artifact for ADR-0249, not a claim of completion.
It has no server schema or protocol impact. The current repository lacks the
Elixir runtime needed to run `scripts/check_hldd.exs`; the parent change must
run the mandatory HLDD status/record/check commands and attach receipts for
this path before merging.
