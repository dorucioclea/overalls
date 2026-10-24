# The Mila source bundle (ADR-0235): everything a host without Nix (the
# Windows build) needs to build and test Mila from the same inputs Nix pins.
#
# Layout of mila-source-bundle-VERSION/:
#   mila/                                 tracked Mila sources (mila-source-closed)
#   mila/packages/mila_transport/.nix/dartssh2
#                                         the patched dartssh2, copied, never
#                                         resolved from pub.dev (ADR-0227)
#   mila/app/assets/fonts/noto/           the pinned Noto fallbacks (ADR-0207)
#   protocol/test/fixtures/, lyra/tests/fixtures/
#                                         the shared vectors the tests read
#   third_party/monocypher/               Monocypher 4 (src/ and licence) for
#                                         the Windows poke opener
#   pub-cache/                            a hosted pub cache of every locked
#                                         package, fetched by the lock's SHA-256
#   flake.nix                             an empty flake marking the root, where
#                                         mila-build looks for the repository
#   SHA256SUMS                            every file above
#
# The bundle includes tracked native sources and lockfiles so Linux release hosts
# can build the GTK4/libadwaita client and Windows hosts can build the WinUI
# client plus its Rust FFI library without Nix. Flutter remains available to
# existing consumers until native parity is accepted.
#
# Use it with PUB_CACHE=<bundle>/pub-cache and
# `flutter pub get --offline --enforce-lockfile`; Flutter's own engine
# artifacts and SDK packages come from the pinned Flutter install.
{ pkgs, source, dartssh2, notoFonts, version, root }:
let
  inherit (pkgs) lib;
  locks = map (d: lib.importJSON (root + "/${d}/pubspec.lock.json"))
    [ "app" "packages/mila_core" "packages/mila_transport" "tool" ];
  hosted = lib.unique (lib.concatMap
    (lock: lib.mapAttrsToList (_: p: {
      inherit (p.description) name sha256 url;
      inherit (p) version;
    }) (lib.filterAttrs (_: p: p.source == "hosted") lock.packages))
    locks);
  # @cc [owner:ghuntley,label:build] mila-source-bundle-pinned
  # Every hosted package MUST be fetched from pub.dev by the SHA-256 its
  # committed lock records, and dartssh2 MUST NOT be among them: the
  # bundle carries only the patched copy at `.nix/dartssh2`.
  archives = map (p:
    assert p.url == "https://pub.dev";
    assert p.name != "dartssh2";
    {
      inherit (p) name version sha256;
      archive = pkgs.fetchurl {
        name = "pub-${p.name}-${p.version}.tar.gz";
        url = "https://pub.dev/api/archives/${p.name}-${p.version}.tar.gz";
        sha256 = p.sha256;
      };
    }) hosted;
  unpack = lib.concatMapStrings (a: ''
    mkdir -p "$b/pub-cache/hosted/pub.dev/${a.name}-${a.version}"
    tar -xzf ${a.archive} -C "$b/pub-cache/hosted/pub.dev/${a.name}-${a.version}"
    printf '%s' ${a.sha256} > "$b/pub-cache/hosted-hashes/pub.dev/${a.name}-${a.version}.sha256"
  '') archives;
  fixtures = ../../../../protocol/test/fixtures;
in
pkgs.runCommand "mila-source-bundle-${version}" {
  passthru = { inherit archives; };
} ''
  name=mila-source-bundle-${version}
  b="$PWD/$name"
  mkdir -p "$b" "$b/pub-cache/hosted/pub.dev" "$b/pub-cache/hosted-hashes/pub.dev"

  cp -r ${source} "$b/mila"
  chmod -R u+w "$b/mila"
  mkdir -p "$b/mila/packages/mila_transport/.nix"
  cp -rL ${dartssh2} "$b/mila/packages/mila_transport/.nix/dartssh2"
  rm -rf "$b/mila/app/assets/fonts/noto"
  mkdir -p "$b/mila/app/assets/fonts/noto"
  cp ${notoFonts}/* "$b/mila/app/assets/fonts/noto/"

  mkdir -p "$b/protocol/test/fixtures" "$b/lyra/tests/fixtures"
  for f in app_routes machine_states porsche_client_results push_pokes ssh_command_lines ssh_host_certificates terminal_attach; do
    cp ${fixtures}/$f.json "$b/protocol/test/fixtures/$f.json"
  done
  cp ${../../../../lyra/tests/fixtures/workspace_sources.json} "$b/lyra/tests/fixtures/workspace_sources.json"

  mkdir -p "$b/third_party/monocypher"
  # Only the library and its licence; the documentation tree is symlinks.
  tar -xzf ${pkgs.monocypher.src} -C "$b/third_party/monocypher" --strip-components=1 \
    --wildcards '*/src/*' '*/LICENCE.md' '*/AUTHORS.md' '*/README.md'
  test -f "$b/third_party/monocypher/src/monocypher.c"

  ${unpack}

  cat > "$b/flake.nix" <<'EOF'
  # The mila-source-bundle root (nix/domains/artifacts/mila/source-bundle.nix).
  # mila-build finds its repository as the directory holding flake.nix and
  # mila/; this bundle builds Mila without Nix and exposes no outputs.
  { outputs = _: { }; }
  EOF

  chmod -R u+w,go-w "$b"
  links=$(find "$b" -type l)
  if [ -n "$links" ]; then echo "bundle must not contain symlinks:" >&2; echo "$links" >&2; exit 1; fi
  # Native Linux release inputs are source-only and must include their lock.
  test -f "$b/mila/native/linux/Cargo.lock"
  test -f "$b/mila/native/linux/Cargo.toml"
  # Android release inputs are source-only and must include the Compose project
  # plus the shared Rust workspace used to build every packaged JNI ABI.
  test -f "$b/mila/native/android/settings.gradle.kts"
  test -f "$b/mila/native/android/app/build.gradle.kts"
  test -f "$b/mila/native/android/gradle/wrapper/gradle-wrapper.properties"
  test -f "$b/mila/rust/Cargo.toml"
  # Windows release inputs are source-only and must retain the managed host,
  # C ABI and Rust workspace lock used to build mila_native.dll.
  test -f "$b/mila/windows-dotnet/Mila.Windows.csproj"
  test -f "$b/mila/windows-dotnet/native/mila_native.h"
  test -f "$b/mila/rust/Cargo.lock"
  if find "$b/mila/native/linux" -type d -name target -print -quit | grep -q .; then
    echo "native Linux bundle must not contain Cargo target output" >&2
    exit 1
  fi

  (cd "$b" && find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)

  mkdir -p $out
  tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
    --format=gnu -cf - "$name" | gzip -n -9 > $out/$name.tar.gz
  (cd $out && sha256sum $name.tar.gz > SHA256SUMS)
''
