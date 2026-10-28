# Mila Android native UI scaffold

This is an isolated Jetpack Compose application for the native Mila presentation seam. It is the production Android client. The adapter exposes a narrow, typed JNI seam for the
Rust `mila-ffi` library; host packaging supplies the ABI-compatible native library and may inject a
test binding implementing `MilaRustBindings`.

The project metadata targets Android API 36, uses Java 17, Android Gradle Plugin 9.1.0, and Kotlin
2.4.0 with the Kotlin Compose compiler plugin. The Compose dependency BOM is pinned in
`app/build.gradle.kts`; update it together with the rest of the native dependency lock when the
host build adopts this scaffold.

`MilaFfiPayload` owns a defensive copy of every byte array. The default linked adapter loads `mila_ffi` lazily and reports unavailable when the host has not
packaged it. Use `LinkedMilaFfiAdapter` in production packaging; keep the unavailable adapter only for tests. Keep
credentials, key material, authentication tokens, and terminal bytes out of this adapter's logs and
UI state.

The `preBuild` task also runs the shared catalog generator against
`mila/localization/catalogs` and packages the deterministic 30-locale JSON bundles as
APK assets. Native message identities use English only as a safe fallback when
a translated resource is unavailable.

## Static validation

On a machine with Android SDK API 36, JDK 17, and Gradle 9:

```sh
gradle --project-dir mila/native/android :app:assembleDebug
```

The repository's Linux checks do not install a native Android SDK for this standalone scaffold. If
Gradle or the SDK is unavailable, inspect the Kotlin and Gradle metadata and run the contract syntax
check from the repository root.

## Release evidence

The `android` job in `.github/workflows/mila-release.yml` assembles this project
with pinned JDK 17, Gradle 9.3.1, Android API 36/NDK 28.2.13676358, and locked
Rust dependencies (`cargo-ndk ... build --locked`). It publishes
`app-release-unsigned.apk` and a SHA-256 manifest as the native release
candidate. Signing remains a distribution concern while the native parity
matrix is open; the artifact is installable for QA and provides repeatable
build evidence.
