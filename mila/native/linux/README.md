# Mila native Linux scaffold

This directory is a standalone GTK4/libadwaita presentation seam for Mila. It is intentionally
outside `mila/rust`'s workspace so a host can integrate generated Rust bindings after the native
surface has a stable shape. The GTK shell uses the shared Rust session adapter.

`dev.overalls.Mila.Linux` is a stable `GApplication` id and the application opts into
`HANDLES_OPEN`. GTK/GIO therefore forwards a second launch to the existing process. The desktop
entry registers `overalls://` as a URI scheme; incoming URIs arrive through `connect_open`, pass
through the bounded typed route parser, and select navigation text in the existing window.

`src/adapter.rs` defines the typed `RuntimeAdapter` seam. `InProcessRuntimeAdapter` routes
bootstrap and snapshot refresh through the shared Rust FFI validation contracts. Requests and
responses contain owned byte buffers behind typed operation values; no raw pointers or credentials
cross this seam. Unsupported input fails closed.

## Build and test

From a machine with Rust, GTK4 development files, and libadwaita development files:

```sh
cargo test --manifest-path mila/native/linux/Cargo.toml
cargo check --manifest-path mila/native/linux/Cargo.toml
```

Install `data/dev.overalls.Mila.desktop` with the executable on the desktop search path to enable
system URI activation. The scaffold's UI is deliberately small while network/session transport is
integrated behind the runtime adapter.
