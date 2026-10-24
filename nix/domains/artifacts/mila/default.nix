# Mila, the Overalls Flutter client (ADR-0220, ADR-0227). The Linux bundle is
# built here for tests and the desktop machine test; iOS and Android release
# builds happen outside Nix with the same pinned Flutter.
{ pkgs, libhegelDart }:
let
  inherit (pkgs) lib;
  flutter = pkgs.flutterPackages.v3_47;
  root = ../../../../mila;
  version = lib.head (lib.splitString "+"
    (lib.head (builtins.match ".*\nversion: ([^\n]+)\n.*" (builtins.readFile (root + "/app/pubspec.yaml")))));
  # @cc [owner:ghuntley,label:build] mila-source-closed
  # Builds MUST read only tracked Mila sources: no build output, tool cache,
  # Hegel example database or platform-generated plugin registrants.
  source = lib.cleanSourceWith {
    name = "mila-source";
    src = root;
    filter = path: type:
      let name = builtins.baseNameOf path;
      in !(builtins.elem name [
        "build" "target" ".dart_tool" ".hegel" ".idea" "ephemeral" ".flutter-plugins"
        ".flutter-plugins-dependencies" "local.properties" "Generated.xcconfig"
        "flutter_export_environment.sh" ".nix"
      ] || lib.hasPrefix "app_localizations" name || lib.hasPrefix "GeneratedPluginRegistrant" name
        || lib.hasSuffix ".iml" name);
  };
  # Formatting is pinned on the command line: in the sandbox the analysis
  # options' package include and the language version are not resolved the
  # way an interactive checkout resolves them.
  # The hegel build hook reads its engine from a pubspec user-define, never
  # the network, inside the sandbox.
  hegelEngine = ''
    cat >> pubspec.yaml <<EOF

    hooks:
      user_defines:
        hegel:
          libhegel_path: ${libhegelDart}/lib/libhegel.so
    EOF
  '';
  fonts = pkgs.makeFontsConf { fontDirectories = [ ]; };
  # dartssh2 with the host-certificate patch (nix/platform/dartssh2.nix).
  # mila_transport's path dependency `.nix/dartssh2` resolves to this store
  # path; nothing resolves dartssh2 from pub.dev.
  dartssh2 = (import ../../../platform/dartssh2.nix pkgs pkgs).dartssh2-overalls.overrideAttrs (old: {
    passthru = (old.passthru or { }) // { packageRoot = "."; };
  });
  # The sandbox's build user has no login shell, which stock sshd refuses;
  # nss_wrapper gives sshd alone a passwd entry with one.
  sandboxSshd = pkgs.writeShellScriptBin "sshd" ''
    passwd="$TMPDIR/mila-sshd-passwd"
    printf '%s:x:%s:%s::%s:%s\n' "$(id -un)" "$(id -u)" "$(id -g)" "$HOME" "${pkgs.bash}/bin/sh" > "$passwd"
    export NSS_WRAPPER_PASSWD="$passwd" NSS_WRAPPER_GROUP=/etc/group
    export LD_PRELOAD=${pkgs.nss_wrapper}/lib/libnss_wrapper.so
    exec ${pkgs.openssh}/bin/sshd "$@"
  '';
  # The pinned Noto fallbacks (ADR-0207); pubspec.yaml declares them under
  # the gitignored `assets/fonts/noto`, which devenv links to the same path.
  notoFonts = import ./fonts.nix { inherit pkgs; };
  copyNotoFonts = ''
    rm -rf assets/fonts/noto
    mkdir -p assets/fonts/noto
    cp ${notoFonts}/* assets/fonts/noto/
    chmod -R u+w assets/fonts/noto
  '';
  # Run from a package directory beside packages/mila_transport.
  linkDartssh2 = transport: ''
    chmod u+w ${transport}
    mkdir -p ${transport}/.nix
    ln -sfn ${dartssh2} ${transport}/.nix/dartssh2
  '';
  patchedDartssh2 = {
    dartssh2 = { version, ... }: assert version == "4.1.0"; dartssh2;
  };
  # `dart test` resolves packages through pub before running build hooks, and
  # pub does not accept nixpkgs' generated package config. Offer pub a hosted
  # cache made of the locked store paths and resolve offline against the
  # committed lock, so no version can differ from the one Nix fetched.
  offlinePub = tool: ''
    export PUB_CACHE="$NIX_BUILD_TOP/pub-cache"
    mkdir -p "$PUB_CACHE/hosted/pub.dev" "$PUB_CACHE/hosted-hashes/pub.dev"
    jq -r '.packages[] | select(.rootUri | startswith("file:///nix/store/")) | "\(.name) \(.rootUri)"' \
      .dart_tool/package_config.json | while read -r name uri; do
      dir=''${uri#file://}; dir=''${dir%/.}
      [ "$(jq -r --arg n "$name" '.packages[$n].source // empty' pubspec.lock.json)" = hosted ] || continue
      version=$(jq -r --arg n "$name" '.packages[$n].version' pubspec.lock.json)
      sha=$(jq -r --arg n "$name" '.packages[$n].description.sha256 // empty' pubspec.lock.json)
      ln -s "$dir" "$PUB_CACHE/hosted/pub.dev/$name-$version"
      if [ -n "$sha" ]; then printf '%s' "$sha" > "$PUB_CACHE/hosted-hashes/pub.dev/$name-$version.sha256"; fi
    done
    rm -f pubspec.lock
    cp pubspec.lock.json pubspec.lock
    chmod u+w .dart_tool/package_config.json
    ${tool} pub get --offline --enforce-lockfile
  '';

  coreCheck = pkgs.buildDartApplication {
    pname = "mila-core-check";
    inherit version;
    src = source;
    sourceRoot = "mila-source/packages/mila_core";
    pubspecLock = lib.importJSON (root + "/packages/mila_core/pubspec.lock.json");
    dartEntryPoints = { };
    postPatch = hegelEngine;
    # Shared vectors live beside the server code that owns them.
    preBuild = ''
      mkdir -p ../../../lyra/tests/fixtures ../../../protocol/test/fixtures
      cp ${../../../../lyra/tests/fixtures/workspace_sources.json} ../../../lyra/tests/fixtures/workspace_sources.json
      for f in app_routes machine_states porsche_client_results push_pokes ssh_command_lines ssh_host_certificates terminal_attach; do
        cp ${../../../../protocol/test/fixtures}/$f.json ../../../protocol/test/fixtures/$f.json
      done
    '';
    nativeBuildInputs = [ pkgs.jq ];
    buildPhase = ''
      runHook preBuild
      dart format --line-length 100 --language-version=3.9 --set-exit-if-changed lib test
      # Analyze against pub's package config, which records each package's
      # language version; nixpkgs' generated config does not.
      ${offlinePub "dart"}
      dart analyze --fatal-infos
      dart test --reporter expanded
      runHook postBuild
    '';
    # A check produces only a stamp; the builder's pub cache output stays empty.
    installPhase = ''
      touch $out
      mkdir -p $pubcache
    '';
  };

  # mila-build's planner (ADR-0235): the dev and release targets as data,
  # with the release contract as a property test.
  toolCheck = pkgs.buildDartApplication {
    pname = "mila-tool-check";
    inherit version;
    src = source;
    sourceRoot = "mila-source/tool";
    pubspecLock = lib.importJSON (root + "/tool/pubspec.lock.json");
    dartEntryPoints = { };
    postPatch = hegelEngine;
    buildPhase = ''
      runHook preBuild
      dart format --line-length 100 --language-version=3.9 --set-exit-if-changed bin lib test
      ${offlinePub "dart"}
      dart analyze --fatal-infos
      dart test --reporter expanded
      runHook postBuild
    '';
    installPhase = ''
      touch $out
      mkdir -p $pubcache
    '';
  };

  # The transport tests include a stock OpenSSH server presenting a host
  # certificate; MILA_REQUIRE_SSHD turns a missing sshd into a failure.
  transportCheck = pkgs.buildDartApplication {
    pname = "mila-transport-check";
    inherit version;
    src = source;
    sourceRoot = "mila-source/packages/mila_transport";
    packageRoot = "packages/mila_transport";
    pubspecLock = lib.importJSON (root + "/packages/mila_transport/pubspec.lock.json");
    customSourceBuilders = patchedDartssh2;
    dartEntryPoints = { };
    postPatch = hegelEngine + linkDartssh2 ".";
    nativeBuildInputs = [ pkgs.jq sandboxSshd pkgs.openssh ];
    MILA_REQUIRE_SSHD = "1";
    buildPhase = ''
      runHook preBuild
      dart format --line-length 100 --language-version=3.9 --set-exit-if-changed bin lib test
      # Analyze against pub's package config, which records each package's
      # language version; nixpkgs' generated config does not.
      ${offlinePub "dart"}
      dart analyze --fatal-infos
      dart test --reporter expanded
      runHook postBuild
    '';
    installPhase = ''
      touch $out
      mkdir -p $pubcache
    '';
  };

  # The production transport as a command, for machine tests against Porsche.
  probe = pkgs.buildDartApplication {
    pname = "mila-probe";
    inherit version;
    src = source;
    sourceRoot = "mila-source/packages/mila_transport";
    packageRoot = "packages/mila_transport";
    pubspecLock = lib.importJSON (root + "/packages/mila_transport/pubspec.lock.json");
    customSourceBuilders = patchedDartssh2;
    postPatch = linkDartssh2 ".";
    dartEntryPoints."bin/mila-probe" = "bin/mila_probe.dart";
    meta.mainProgram = "mila-probe";
  };

  appArgs = {
    pname = "mila";
    inherit version;
    src = source;
    sourceRoot = "mila-source/app";
    # Locates the `../packages/mila_core` path dependency inside `source`.
    packageRoot = "app";
    pubspecLock = lib.importJSON (root + "/app/pubspec.lock.json");
    customSourceBuilders = patchedDartssh2;
    targetFlutterPlatform = "linux";
    # The app has no property-test engine: its pure property tests live in
    # mila_core and mila_transport, so no build hook fetches one.
    postPatch = linkDartssh2 "../packages/mila_transport" + copyNotoFonts;
    flutterBuildFlags = [ "--dart-define=MILA_DEMO=${lib.boolToString false}" ];
    # The desktop entry claims overalls:// links; the runner passes the link
    # to Dart's main as its argument (ADR-0221).
    nativeBuildInputs = [ pkgs.copyDesktopItems ];
    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "dev.overalls.mila";
        desktopName = "Mila";
        comment = "Overalls client";
        exec = "mila %u";
        categories = [ "Development" ];
        mimeTypes = [ "x-scheme-handler/overalls" ];
      })
    ];
    meta = {
      description = "Mila, the Overalls client (Linux build for testing)";
      mainProgram = "mila";
      platforms = [ "x86_64-linux" ];
    };
  };

  # Linux targets (ADR-0235): `release` is the production bundle the
  # machine tests drive; `dev` is a debug bundle (asserts, the VM service)
  # that also accepts `--dart-define=MILA_DEMO=true` from `mila-build`.
  app = flutter.buildFlutterApplication appArgs;
  nativeLinux = import ./native-linux.nix { inherit pkgs lib; root = ../../../../.; };
  linuxDev = flutter.buildFlutterApplication (appArgs // {
    pname = "mila-dev";
    flutterMode = "debug";
    flutterBuildFlags = [ ];
  });
  # The release bundle as a reproducible tarball with its checksum.
  linuxRelease = pkgs.runCommand "mila-linux-release-${version}" { } ''
    mkdir -p $out
    name=mila-${version}-linux-x86_64.tar.gz
    tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
      -czf $out/$name -C ${nativeLinux} .
    (cd $out && sha256sum $name > SHA256SUMS)
  '';

  # The demo flavour talks to an in-memory deployment; the desktop machine
  # test drives it under a headless compositor.
  demo = app.overrideAttrs (old: {
    pname = "mila-demo";
    flutterBuildFlags = [ "--dart-define=MILA_DEMO=true" ];
  });

  # The production build plus the screen probe (lib/integration_probe.dart)
  # the mila-desktop machine test reads; it talks to a real deployment.
  integration = app.overrideAttrs (old: {
    pname = "mila-integration";
    flutterBuildFlags = [ "--dart-define=MILA_INTEGRATION=true" ];
  });

  appCheck = app.overrideAttrs (old: {
    pname = "mila-check";
    FONTCONFIG_FILE = fonts;
    preBuild = (old.preBuild or "") + ''
      cp -r ${../../../../marshall/lib/marshall_web/components} /build/core_components_source
      mkdir -p ../../marshall/lib/marshall_web
      ln -s /build/core_components_source ../../marshall/lib/marshall_web/components
      # Flutter gen-l10n writes generated metadata beside the ARB inputs.
      # The source tree is read-only in Nix, so provide a writable copy.
      localization_dir="$NIX_BUILD_TOP/mila-localization-catalogs"
      cp -r ../localization/catalogs "$localization_dir"
      chmod -R u+w "$localization_dir"
      sed -i "s#../localization/catalogs#$localization_dir#" l10n.yaml
      # The localization test checks Mila's locales against Porsche's catalogs.
      mkdir -p ../../porsche/priv
      ln -s ${../../../../porsche/priv/gettext} ../../porsche/priv/gettext
    '';
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.jq ];
    buildPhase = ''
      runHook preBuild
      dart format --line-length 100 --language-version=3.13 --set-exit-if-changed lib test
      ${offlinePub "flutter"}
      flutter gen-l10n
      flutter analyze --fatal-infos
      flutter test --reporter expanded
      runHook postBuild
    '';
    outputs = [ "out" ];
    installPhase = ''touch $out'';
    dontFixup = true;
  });

  # The JSON lock Nix reads MUST describe the same packages as pubspec.lock.
  lockSync = pkgs.runCommand "mila-lock-sync" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
    for d in packages/mila_core packages/mila_transport tool app; do
      yq -o=json ${source}/$d/pubspec.lock > generated.json
      yq -o=json . ${source}/$d/pubspec.lock.json > committed.json
      if ! cmp -s generated.json committed.json; then
        echo "mila/$d/pubspec.lock.json is stale; regenerate it with yq -o=json" >&2
        exit 1
      fi
    done
    touch $out
  '';
  # Sources, patched dartssh2, fonts, Monocypher and a pinned pub cache for
  # hosts that build without Nix (ADR-0235).
  sourceBundle = import ./source-bundle.nix { inherit pkgs source dartssh2 notoFonts version root; };
  windowsSourceBundle = import ./windows-source-bundle.nix { inherit pkgs version root; };
  # Optional Android APK; a flake package only, never a CI check (ADR-0227).
  android = import ./android.nix { inherit pkgs app; };
in
{
  # Native GTK4 Linux client. Keep this as a first-class tool target so CI can
  # exercise the release implementation without pulling in Flutter.
  linuxNative = nativeLinux;
  inherit app linuxDev linuxRelease sourceBundle windowsSourceBundle demo integration probe coreCheck transportCheck toolCheck appCheck lockSync android;
}
