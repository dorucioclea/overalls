{ pkgs }:
let
  evaluate = roots: (import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = "x86_64-linux";
    inherit pkgs;
    modules = [ ../../../domains/artifacts/guest/configuration.nix {
      overalls.privateServices = {
        enable = true;
        rootCertificates = roots;
        trustReceiver = pkgs.writeShellScriptBin "overalls-trustd" "exit 0";
      };
    } ];
  }).config;
  guest = evaluate [ ../../../../marshall/test/fixtures/tls/ca.pem ../../../../secrets/brady-root.pem ];
  missing = evaluate [];
  private = evaluate [ ../../../../marshall/test/fixtures/tls/localhost.key ];
  failures = config: builtins.filter (a: !a.assertion) config.assertions;
in
assert builtins.any (a: a.message == "Guest private services require public CA certificates, never private keys.") (failures missing);
assert builtins.any (a: a.message == "Guest private services require public CA certificates, never private keys.") (failures private);
assert guest.services.resolved.enable;
assert guest.services.resolved.settings.Resolve.Domains == [ "~." ];
assert guest.services.resolved.settings.Resolve.DNS == [ "1.1.1.1" "9.9.9.9" ];
assert builtins.elem "lilly-private-dns.service" guest.systemd.services.lilly-readiness.requires;
assert guest.security.pki.certificateFiles == [];
assert builtins.elem "overalls-guest-trust.service" guest.systemd.services.lilly-network.requires;
assert guest.systemd.services.overalls-guest-trust.serviceConfig.StateDirectory == "overalls-trust";
assert guest.systemd.services.overalls-guest-trust.serviceConfig.StateDirectoryMode == "0755";
assert guest.environment.etc."ssl/certs/ca-certificates.crt".source == "/var/lib/overalls-trust/current/ca-bundle.pem";
assert guest.environment.variables.SSL_CERT_FILE == "/etc/ssl/certs/ca-certificates.crt";
pkgs.runCommand "private-services-guest-config" {} ''
  test -s ${guest.security.pki.caBundle}
  touch $out
''
