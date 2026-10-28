# Mila guidance

Mila consists of native platform shells over the shared Rust workspace. Read
[ADR-0220](../docs/architecture/decisions/0220-mila-client-over-porsche-ssh.md),
[ADR-0235](../docs/architecture/decisions/0235-mila-desktop-clients.md),
[CONTRACTS](CONTRACTS) before changing it.

## Layout

| Path | Responsibility |
| --- | --- |
| `rust/` | Typed protocol, transport, session, policy and FFI libraries. |
| `native/apple` | SwiftUI iOS/macOS client and Rust FFI adapter. |
| `native/android` | Kotlin/Compose Android client and JNI adapter. |
| `native/linux` | GTK4/libadwaita Linux client and Rust session adapter. |
| `windows-dotnet` | WinUI/.NET 10 Windows client and Rust interop. |
| `localization` | Shared typed locale policy and deterministic catalogs. |

## Working rules

- Use the pinned `devenv shell` and run the relevant Rust, native and platform
  checks before committing.
- Keep external data behind typed validation and preserve generation/session
  authority fencing at every FFI boundary.
- User-facing strings come from the shared localization catalogs; use the
  localization skill when adding or changing them.
- Property-based tests use Hegel for stateful and boundary behavior. Prefer
  native integration evidence over unit tests for platform claims.
- Wire formats shared with Elixir use fixtures under `protocol/test/fixtures`;
  change both sides and the fixture together.
- Native builds that require a platform SDK run in the corresponding CI job.
