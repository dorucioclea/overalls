{ pkgs, lib, root }:
let
  source = lib.cleanSourceWith {
    name = "mila-native-linux-source";
    src = root;
    filter = path: type:
      let
        text = toString path;
        name = builtins.baseNameOf path;
      in !(lib.hasInfix "/target" text || name == ".git" || name == ".hegel");
  };
in
pkgs.rustPlatform.buildRustPackage {
  pname = "mila-native-linux";
  version = "0.1.0";
  src = source;
  sourceRoot = "mila-native-linux-source/mila/native/linux";
  cargoLock.lockFile = root + "/mila/native/linux/Cargo.lock";
  nativeBuildInputs = [ pkgs.pkg-config pkgs.python3 ];
  buildInputs = [ pkgs.gtk4 pkgs.libadwaita ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/applications"
    binary=$(find target -type f -name mila-native-linux -perm -0100 | head -n 1)
    test -n "$binary"
    cp "$binary" "$out/bin/mila"
    cp data/dev.overalls.Mila.desktop "$out/share/applications/"
    runHook postInstall
  '';
  meta = {
    description = "Mila native GTK4/libadwaita Linux client";
    mainProgram = "mila";
    platforms = [ "x86_64-linux" ];
  };
}
