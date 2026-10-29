#!/usr/bin/env bash
# Build the dev Mila app and launch it on this Mac or in an iOS simulator.
# MILA_SIMULATOR selects a simulator by name or UDID; the default is the first
# available iPhone.
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^(ios|macos)$ ]]; then
  echo "usage: mila/native/apple/run.sh <ios|macos>" >&2
  exit 2
fi
platform=$1
package_dir=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$package_dir/../../.." && pwd)

"$package_dir/build.sh" "$platform" dev
app="$repo/mila/build/$platform-dev/Mila.app"

if [[ "$platform" == macos ]]; then
  open -n "$app"
  exit 0
fi

if [[ -z "${DEVELOPER_DIR:-}" || "$DEVELOPER_DIR" == /nix/store/* ]]; then
  DEVELOPER_DIR=$(env -u DEVELOPER_DIR xcode-select -p)
  [[ "$DEVELOPER_DIR" == *.app/Contents/Developer ]] || DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export DEVELOPER_DIR

device=${MILA_SIMULATOR:-}
if [[ -z "$device" ]]; then
  device=$(xcrun simctl list devices available iPhone | grep -m1 -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' || true)
  [[ -n "$device" ]] || { echo "mila-run: no available iPhone simulator; install one in Xcode" >&2; exit 1; }
fi
xcrun simctl boot "$device" 2> /dev/null || true
open -a Simulator
xcrun simctl bootstatus "$device" -b > /dev/null
xcrun simctl install "$device" "$app"
xcrun simctl launch "$device" dev.overalls.mila
