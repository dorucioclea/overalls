#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || ! "$1" =~ ^(ios|macos)$ || ! "$2" =~ ^(dev|release)$ ]]; then
  echo "usage: mila/native/apple/build.sh <ios|macos> <dev|release>" >&2
  exit 2
fi
platform=$1
mode=$2
configuration=debug
[[ "$mode" == release ]] && configuration=release
: "${MILA_FFI_LIB_DIR:?MILA_FFI_LIB_DIR must point to the built mila-ffi library}"
swift build --configuration "$configuration"
out="mila/build/${platform}-${mode}"
rm -rf "$out"
mkdir -p "$out"
# Package the typed Swift package and its build manifest as the native release
# handoff. Platform signing/export remains the host application's responsibility.
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
  -czf "$out/mila-native-${platform}-${mode}.tar.gz" \
  -C .build .
(cd "$out" && shasum -a 256 "mila-native-${platform}-${mode}.tar.gz" > SHA256SUMS)
