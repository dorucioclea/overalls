{ packages }:
{ config, lib, pkgs, ... }:
let
  runtime = "/run/credentials/ziggy.service/runtime.json";
  cfg = {
    package = packages.ziggy;
    # The shared Ziggy unit accepts an optional release-independent
    # configuration file. Inception uses the immutable runtime descriptor
    # directly, so keep this explicitly null rather than relying on a module
    # option that is not present in this local service record.
    configurationFile = null;
    cpuCores = 2;
    memoryMiB = 1024;
    caFile = "/run/inception-public/ca.crt";
    credentialFile = "/var/lib/inception/ziggy.token";
    openaiKeyFile = "/run/overalls-secrets/inception-ziggy/openai.key";
    anthropicKeyFile = "/run/overalls-secrets/inception-ziggy/anthropic.key";
    secretUnits = [ "inception-ziggy-runtime.service" "overalls-secrets-inception-ziggy.service" ];
  };
  service = import ../../../system/ziggy-service.nix { inherit pkgs cfg runtime; };
in {
  # @cc [owner:ghuntley,label:security] inception-provider-secret-boundary
  # Inner provider keys MUST come from this instance's own SOPS document and SSH
  # decryption identity, independently of parent credentials and public readiness.
  # Missing operator credentials MUST NOT select a placeholder or parent fallback.
  # Generating the decryption identity MUST NOT enable administrative SSH login.
  assertions = [{
    assertion = !config.services.openssh.enable;
    message = "Inception secret custody must not enable administrative SSH.";
  }];
  services.overallsSecrets.enable = true;
  environment.systemPackages = [ packages.secretTools.sops packages.secretTools.ssh-to-age ];
  services.overallsSecrets.bundles.inception-ziggy = {
    encryptedFile = "/var/lib/inception/ziggy-providers.enc.json";
    outputs = {
      "openai.key" = { format = "raw"; secrets = [ "OPENAI_API_KEY" ]; };
      "anthropic.key" = { format = "raw"; secrets = [ "ANTHROPIC_API_KEY" ]; };
    };
  };
  users.groups.ziggy = {};
  users.groups.ziggy-proxy = {};
  users.users.ziggy = { isSystemUser = true; group = "ziggy"; extraGroups = [ "ziggy-proxy" ]; };
  users.users.audi.extraGroups = [ "ziggy-proxy" ];

  systemd.services.inception-ziggy-runtime = {
    after = [ "inception-enrollment.service" ];
    requires = [ "inception-enrollment.service" ];
    serviceConfig = {
      Type = "oneshot"; RemainAfterExit = true; UMask = "0077";
      ExecStart = "${pkgs.python3}/bin/python3 ${./.}/ziggy_runtime.py";
      TimeoutStartSec = 30;
      CapabilityBoundingSet = [];
      NoNewPrivileges = true; PrivateDevices = true; PrivateNetwork = true; PrivateTmp = true;
      ProtectSystem = "strict"; ProtectHome = true;
      ReadWritePaths = [ "/run/inception" ];
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };
  };
  systemd.services.ziggy = lib.recursiveUpdate service {
    after = service.after ++ [ "inception-enable.service" ];
    serviceConfig.LoadCredential = service.serviceConfig.LoadCredential ++ [
      "runtime.json:/run/inception/ziggy.json"
    ];
  };
}
