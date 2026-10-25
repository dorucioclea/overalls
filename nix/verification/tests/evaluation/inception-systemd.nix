{ pkgs }:
let
  inherit (pkgs) lib;
  # Module evaluation only needs store paths for package inputs.  Keep these
  # placeholders cheap so this check exercises service wiring without building
  # the complete nested image.
  fake = pkgs.writeText "inception-systemd-test-input" "";
  seed = pkgs.runCommand "inception-systemd-test-seed" { } ''
    mkdir -p "$out"
    touch "$out/manifest.json"
  '';
  packages = {
    guest = fake;
    marshall = fake;
    lilly = fake;
    audi = fake;
    porsche = fake;
    ziggy = fake;
    smtprelay = fake;
    toolchain = { elixir = fake; erlang = fake; };
    secretTools = { sops = fake; ssh-to-age = fake; };
    imageBuilder = { inherit seed; };
  };
  module = import ../../../domains/artifacts/guest/inception { inherit packages; };
  evaluated = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = pkgs.system;
    modules = [
      ../../../domains/artifacts/guest/configuration.nix
      module
      { _module.args = { inherit packages; }; }
    ];
  };
  config = evaluated.config;
  namespace = config.systemd.services.inception-namespace;
  ingress = config.systemd.services.inception-ingress;
  outerFixture = builtins.readFile ../machines/inception/outer.exs;
in
# @cc [owner:ghuntley,label:verification;recovery] inception-namespace-wiring-evaluation
# The namespace waiter MUST be pulled in by the long-running ingress listener,
# ordered after that listener, and free of a reverse requirement that would make
# systemd reject the startup graph as a dependency cycle.
assert namespace.wantedBy == [ "inception-ingress.service" ];
assert namespace.after == [ "inception-ingress.service" ];
assert namespace.requires == [ ];
assert ingress.wantedBy == [ "multi-user.target" ];
# The native admission fixture MUST retain enough bounded retry time for a
# fresh Lilly capacity report after enrollment; the driver deadline covers it.
assert lib.hasInfix "900_000" outerFixture;
assert lib.hasInfix "timeout=1200" (builtins.readFile ../machines/inception/driver.py);
pkgs.writeText "inception-systemd-evaluation" "passed\n"
