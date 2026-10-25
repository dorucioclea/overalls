{ config, lib, pkgs, ... }:
let
  cfg = config.overalls.privateServices;
  bundle = "/etc/ssl/certs/ca-certificates.crt";
in {
  options.overalls.privateServices = {
    enable = lib.mkEnableOption "private platform DNS and certificate trust";
    rootCertificates = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = "Public platform root certificates; reproducible build inputs, never private keys.";
    };
    trustReceiver = lib.mkOption {
      type = lib.types.package;
      description = "Guest trust receiver binary package.";
    };
  };

  # @cc [owner:ghuntley,label:security] guest-private-service-public-trust
  # Enabled private services MUST require explicit public root certificates.
  # Private keys MUST NOT be accepted as image inputs. The current host's roots
  # MUST be installed before networking while ordinary public roots stay
  # trusted; enabling private trust MUST NOT disable TLS verification.
  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.rootCertificates != [] && lib.all (path:
        let
          pem = builtins.readFile path;
          # Line-wise scanning keeps each regex bounded; whole-file hasInfix
          # overflows Nix's regex stack on large CA bundles.
          pemLines = lib.splitString "\n" pem;
        in lib.any (line: lib.hasInfix "BEGIN CERTIFICATE" line) pemLines
           && !(lib.any (line: lib.hasInfix "PRIVATE KEY" line) pemLines)
      ) cfg.rootCertificates;
      message = "Guest private services require public CA certificates, never private keys.";
    }];
    # The platform set is delivered by the current Lilly host on every boot.
    # Keep the distribution roots in the immutable base bundle.
    environment.etc."ssl/certs/ca-certificates.crt".source =
      lib.mkForce "/var/lib/overalls-trust/current/ca-bundle.pem";
    environment.etc."ssl/certs/ca-bundle.crt".source =
      lib.mkForce "/var/lib/overalls-trust/current/ca-bundle.pem";
    systemd.services.overalls-guest-trust = {
      description = "Install current Lilly platform trust before guest networking";
      wantedBy = [ "multi-user.target" ];
      before = [ "lilly-network.service" "systemd-networkd.service" "sshd.service" ];
      unitConfig.ConditionKernelCommandLine = "lilly.boot_challenge";
      serviceConfig = {
        Type = "notify";
        NotifyAccess = "main";
        TimeoutStartSec = "180s";
        StateDirectory = "overalls-trust";
        StateDirectoryMode = "0755";
        ExecStart = "${cfg.trustReceiver}/bin/overalls-trustd nixos ${config.security.pki.caBundle}";
      };
    };
    # @cc [owner:ghuntley,label:security;recovery] guest-workspace-receiver-unit
    # The repository receiver MUST listen only after platform trust is
    # installed, clone with that CA bundle and plain git, and remain outside
    # readiness (never in LILLY_REQUIRED_UNITS or ordered before
    # lilly-readiness): GitHub availability MUST NOT affect VM readiness.
    systemd.services.overalls-workspace = {
      description = "Clone the Lilly-delivered public repository into /workspace";
      wantedBy = [ "multi-user.target" ];
      # The vsock listener must not wait for network-online; clone attempts
      # retry until guest egress works.
      after = [ "overalls-guest-trust.service" ];
      wants = [ "network-online.target" ];
      unitConfig.ConditionKernelCommandLine = "lilly.boot_challenge";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.trustReceiver}/bin/overalls-workspaced nixos ${bundle} ${pkgs.git}/bin/git";
        StateDirectory = "overalls-workspace";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "overalls-workspace";
        RuntimeDirectoryMode = "0755";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/workspace" ];
      };
    };
    systemd.tmpfiles.rules = [ "d /workspace 0755 root root -" ];
    # Checkouts are root-owned and shared by every sudo-capable login account.
    programs.git = {
      enable = true;
      config.safe.directory = "/workspace/*";
      config.include.path = [
        "/run/overalls-workspace/git-identity/gitconfig"
        "/etc/overalls/github.gitconfig"
      ];
    };
    systemd.services.lilly-network = {
      requires = [ "overalls-guest-trust.service" ];
      after = [ "overalls-guest-trust.service" ];
    };
    services.resolved = {
      enable = true;
      settings.Resolve = {
        # Route public names to the explicit recursive servers below.  The
        # lilly-private-dns link installs the more-specific ~internal route;
        # Audi remains authoritative for that suffix and is never a public
        # fallback.
        Domains = [ "~." ];
        DNS = [ "1.1.1.1" "9.9.9.9" ];
        DNSOverTLS = "no";
        DNSSEC = "no";
        FallbackDNS = "";
      };
    };
    environment.variables = {
      NODE_EXTRA_CA_CERTS = bundle;
      REQUESTS_CA_BUNDLE = bundle;
      SSL_CERT_FILE = bundle;
      NIX_SSL_CERT_FILE = bundle;
    };

    # @cc [owner:ghuntley,label:security] guest-private-dns-routing
    # Only the internal suffix MUST use the local authoritative resolver. The
    # internal route MUST never be a default DNS route or fall back to public
    # DNS. Routing is configured only after the validated guest network exists.
    systemd.services.lilly-private-dns = {
      description = "Route private service DNS to local Audi";
      wantedBy = [ "multi-user.target" ];
      requires = [ "lilly-network.service" "systemd-resolved.service" ];
      after = [ "lilly-network.service" "systemd-resolved.service" ];
      before = [ "lilly-readiness.service" ];
      unitConfig.ConditionKernelCommandLine = "lilly.ipv4";
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        ${pkgs.systemd}/bin/resolvectl dns eth0 169.254.254.1
        ${pkgs.systemd}/bin/resolvectl domain eth0 '~internal'
        ${pkgs.systemd}/bin/resolvectl default-route eth0 no
      '';
    };
    systemd.services.lilly-readiness = {
      requires = [ "lilly-private-dns.service" ];
      after = [ "lilly-private-dns.service" ];
    };
  };
}
