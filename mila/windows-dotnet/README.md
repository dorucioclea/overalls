# Mila Windows native scaffold

This directory is the native Windows host for the desktop Mila client. It is a
small unpackaged WinUI 3 application targeting .NET 10 and Windows 10
19041. The native client owns presentation while the shared Rust core owns transport, validation, and policy.

## Build on Windows

Install the .NET 10 SDK, the Windows 10/11 SDK, and the Visual Studio workload
**Desktop development with C++**. From PowerShell:

```powershell
dotnet restore .\Mila.Windows.csproj
dotnet build .\Mila.Windows.csproj -c Debug -p:Platform=x64
dotnet run --project .\Mila.Windows.csproj -c Debug -p:Platform=x64
```

The project uses `Microsoft.WindowsAppSDK` with `UseWinUI=true` and runs
unpackaged (`WindowsPackageType=None`). Release packaging and signing belong to
the Windows build workflow once that workflow stages the Rust library.

## Rust ABI seam

`Interop/RustNative.cs` declares the typed ABI boundary with source-generated
`LibraryImport`. `TryGetVersion` returns `Unavailable` while `mila_native.dll`
is absent, so the scaffold can start before the native library is staged.
`native/mila_native.h` is the C ABI that a Rust `#[repr(C)]` implementation
must satisfy. The native library must be copied beside the executable as
`mila_native.dll` by the Windows source-bundle build.

The boundary currently exposes only a status and version. Device keys,
signatures, tokens, command arguments and terminal bytes must remain in the
existing typed Mila transport and must not be added as untyped FFI payloads.

## Verification in this repository

The development host is Linux, so the Windows SDK and .NET SDK are not
available here. The project files are checked for contract and XML syntax;
`dotnet restore` and a Windows build must run in the Windows CI job described by
ADR-0235.

## Windows Hello app lock

`Interop/MilaWindowsHelloBroker` is the only adapter that calls
`UserConsentVerifier`. `MilaAppLockController` exposes typed availability,
locked/unlocked state, and verification outcomes to the UI; biometric data,
passcodes, and Windows API objects never cross that boundary. The app disables
navigation while locked and requires a successful Windows Hello verification to
unlock.

## Release boundary

The .NET release is the production native client. Publish it with
`dotnet publish Mila.Windows.csproj -c Release -r win-x64 --self-contained true`
and stage the production `mila_native.dll`; do not invoke a different platform build.
Before signing or archiving, run `powershell -File .\verify-release.ps1
-PublishDirectory .\bin\Release\net10.0-windows10.0.19041.0\win-x64\publish`.
The verifier requires both release binaries and rejects foreign runtime engines, snapshots, and generated-runner files.
