# Optional Android build of Mila (ADR-0227). It is a flake package only and
# is excluded from CI and every checks list: the Gradle dependency lock
# (`android-deps.json`) is recorded with nixpkgs' mitm-cache and has to be
# refreshed whenever the Android Gradle plugin, Kotlin, Firebase or a Flutter
# plugin changes:
#
#   nix build -o update .#tool-mila-android.mitmCache.updateScript
#   USE_BWRAP=0 ./update        # from the repository root; needs network
#
# (USE_BWRAP=0 because the script's bubblewrap sandbox loses the Nix daemon
# connection on this host.) The build itself runs offline in the sandbox.
#
# The build reuses the Linux package's source, pub lock, patched dartssh2 and
# postPatch, so it ships the same Dart code and assets. Signing uses the debug
# key from the template's release build type; store releases are signed
# outside Nix.
{ pkgs, app }:
let
  inherit (pkgs) lib;
  jdk = pkgs.jdk17;
  gradle = pkgs.gradle_9.override { java = jdk; };
  # Android SDK components are unfree; re-import the same pinned nixpkgs with
  # only the licence policy changed, like the Android guest's SDK.
  androidPkgs = import pkgs.path {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  androidEnvironment = androidPkgs.callPackage (pkgs.path + "/pkgs/development/mobile/androidenv") {
    licenseAccepted = true;
  };
  # Versions are the ones Flutter 3.47's Gradle plugin and AGP 9.1 ask for
  # (flutter.compileSdkVersion 36, flutter.ndkVersion 28.2.13676358).
  buildToolsVersion = "36.0.0";
  androidSdk = (androidEnvironment.composeAndroidPackages {
    cmdLineToolsVersion = "latest";
    platformToolsVersion = "latest";
    buildToolsVersions = [ buildToolsVersion ];
    platformVersions = [ "36" ];
    includeNDK = true;
    ndkVersions = [ "28.2.13676358" ];
    # Flutter's Gradle plugin configures a CMake project for the NDK.
    includeCmake = true;
    cmakeVersions = [ "3.22.1" ];
    includeEmulator = false;
    includeSystemImages = false;
  }).androidsdk;
  sdkRoot = "${androidSdk}/libexec/android-sdk";
in
app.multiShell.overrideAttrs (finalAttrs: old: {
  pname = "mila-android";
  outputs = [ "out" ];
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ gradle jdk ];
  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    attrPath = "tool-mila-android";
    data = ./android-deps.json;
  };
  ANDROID_HOME = sdkRoot;
  ANDROID_SDK_ROOT = sdkRoot;
  JAVA_HOME = jdk.home;
  # Gradle runs from the Android project; Flutter's Gradle plugin calls back
  # into `flutter assemble` for the Dart AOT snapshot.
  gradleFlags = [
    "-Dorg.gradle.java.home=${jdk.home}"
    # Maven's aapt2 is a generic Linux binary that cannot run in the sandbox.
    "-Pandroid.aapt2FromMavenOverride=${sdkRoot}/build-tools/${buildToolsVersion}/aapt2"
    "-Ptarget-platform=android-arm64"
  ];
  preConfigure = (old.preConfigure or "") + ''
    export ANDROID_USER_HOME="$NIX_BUILD_TOP/android-user"
  '';
  # After the pub configure hooks: write local.properties and Flutter's
  # plugin registrations against the offline package config, without
  # running Gradle or pub. The update script runs Gradle from here too.
  preBuild = (old.preBuild or "") + ''
    flutter config --no-analytics --android-sdk "${sdkRoot}" --jdk-dir "${jdk.home}" >/dev/null
    # Flutter's localization generator writes generated metadata alongside the
    # ARB inputs. The Nix source tree is read-only, so provide a writable copy
    # for the Android build and point l10n.yaml at it.
    localization_dir="$NIX_BUILD_TOP/mila-localization-catalogs"
    # The multiShell source root is app/, while the catalogs live beside it.
    cp -r ../localization/catalogs "$localization_dir"
    chmod -R u+w "$localization_dir"
    sed -i "s#../localization/catalogs#$localization_dir#" l10n.yaml
    flutter build apk --config-only --release --no-pub
    # Gradle writes into an included build's directory, so Flutter's Gradle
    # plugin cannot be built in place in the store: give it a writable copy
    # inside an SDK view that links everything else.
    sdk="$(dirname "$(dirname "$(command -v flutter)")")"
    view="$NIX_BUILD_TOP/flutter-sdk"
    mkdir -p "$view/packages/flutter_tools"
    for f in "$sdk"/* "$sdk"/.[!.]*; do [ "$(basename "$f")" = packages ] || ln -s "$f" "$view/"; done
    for f in "$sdk"/packages/*; do [ "$(basename "$f")" = flutter_tools ] || ln -s "$f" "$view/packages/"; done
    for f in "$sdk"/packages/flutter_tools/* "$sdk"/packages/flutter_tools/.[!.]*; do
      [ "$(basename "$f")" = gradle ] || ln -s "$f" "$view/packages/flutter_tools/"
    done
    cp -rL "$sdk/packages/flutter_tools/gradle" "$view/packages/flutter_tools/gradle"
    chmod -R u+w "$view/packages/flutter_tools/gradle"
    # Keep the version name and code `--config-only` wrote from pubspec.yaml.
    sed -i -e '/^flutter\.sdk=/d' -e '/^sdk\.dir=/d' android/local.properties
    printf '\nflutter.sdk=%s\nsdk.dir=%s\n' "$view" "${sdkRoot}" >> android/local.properties
    cd android
  '';
  gradleBuildTask = "assembleRelease";
  gradleUpdateTask = "assembleRelease";
  buildPhase = ''
    runHook preBuild
    gradle assembleRelease
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm644 ../build/app/outputs/flutter-apk/app-release.apk "$out/mila-release.apk"
    runHook postInstall
  '';
  # The APK is the only output: no Linux desktop entry and no pub cache.
  desktopItems = [ ];
  dontDartInstallCache = true;
  dontFixup = true;
  meta = (old.meta or { }) // {
    description = "Mila, the Overalls client (Android APK, debug-signed)";
    platforms = [ "x86_64-linux" ];
  };
})
