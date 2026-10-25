{ pkgs, packages }:
pkgs.runCommand "inception-image-builder-check" {
  nativeBuildInputs = [ pkgs.nix ];
  # Keep the evaluator's state and channel lookups inside the sandbox; pure
  # local evaluation must not touch the host's /nix/var.
  HOME = "/build";
  NIX_STATE_DIR = "/build/nix-state";
  NIX_CONFIG_DIR = "/build/nix-conf";
  NIX_PATH = "";
} ''
  set -eu
  # The runtime cache must retain the recipe for the offline rebuild.
  test -f ${packages.imageBuilder.cache}/recipe.nix
  # The offline rebuild must preserve Inception's console-gated bootstrap;
  # otherwise a generic private guest reintroduces the SSH/Audi/namespace
  # readiness cycle before the child can receive its namespace.
  grep -q 'LILLY_SSH_UNIT=' ${packages.imageBuilder.recipe}
  test -e ${packages.imageBuilder.cache}/pinned-guest-source
  test -e ${packages.imageBuilder.cache}/pinned-nixpkgs-source
  test -e ${packages.imageBuilder.cache}/pinned-linux-cli
  test -z "$(find ${packages.imageBuilder.cache} -maxdepth 1 -type l -name '*-ext4-fs.img' -print -quit)"
  test -z "$(find ${packages.imageBuilder.cache} -maxdepth 1 -type l -name '*-lyra-rust-toolchain-*' -print -quit)"
  test -z "$(find ${packages.imageBuilder.cache} -maxdepth 1 -type l -name '*-cargo-zigbuild-*' -print -quit)"
  # The prewarmed cache must reference more than a single store path; a bare
  # recipe without its build graph cannot rebuild offline.
  linked=$(ls -1 ${packages.imageBuilder.cache} | wc -l)
  test "$linked" -gt 10
  # The first-boot unit uses the new CLI because legacy nix-build does not
  # accept --offline. Confirm the pinned CLI exposes that option, then evaluate
  # a public certificate without asking the sandbox to mutate the host store.
  nix --extra-experimental-features nix-command build --help | grep -q -- --offline
  nix-instantiate --eval -E \
    'builtins.isAttrs (import ${packages.imageBuilder.recipe} { rootCertificate = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"; })' \
    | grep -q true
  # Private-key material must be rejected before any store copy.
  bad=${pkgs.writeText "inception-bad-root.pem" "-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----\n"}
  if nix-instantiate --eval -E \
      "builtins.isAttrs (import ${packages.imageBuilder.recipe} { rootCertificate = \"$bad\"; })" \
      >/dev/null 2>&1; then
    echo "private key accepted as image trust input" >&2
    exit 1
  fi
  touch $out
''
