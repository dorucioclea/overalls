# Mila Apple native UI scaffold

This Swift Package is an isolated SwiftUI presentation seam for iOS and macOS. It is independent of the retired Flutter runner and exposes a typed boundary for a host app to
link the Rust library. A host app can depend on the package and inject a generated binding by conforming to `MilaFFIAdapter`.

The package uses Swift tools 6.2, iOS 18, and macOS 15 as its deployment floor. The host Xcode
project remains responsible for signing, entitlements, and embedding the package. `MilaNativeApp`
is an `App` value without `@main`, so it can be used by a host that already owns the process entry
point.

The adapter intentionally has a typed request/response boundary. Replace
`UnavailableMilaFFIAdapter` with generated UniFFI bindings in the host integration; do not expose
raw pointers, key material, authentication tokens, or terminal bytes through this module.

## Static validation

On a machine with Xcode 26 or Swift 6.2 installed:

```sh
swift build --package-path mila/native/apple
```

The repository's Linux checks cannot build Apple SDKs. When Xcode is unavailable, inspect
`Package.swift` and run the contract syntax check from the repository root.
