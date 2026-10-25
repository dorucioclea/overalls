{ packages, publicConfig }:
{ pkgs, ... }:
let
  certificates = import ../../../system/ssh-host-certificate.nix {
    inherit pkgs packages;
    role = "audi";
    # Keep localhost as the TLS authority while the helper pins its connection
    # to IPv4 loopback. This matches the verified Python publication client:
    # localhost SNI/HTTP semantics over a raw IPv4 socket.
    origin = "https://localhost:5443";
    caFile = "/run/inception-public/ca.crt";
    credentialFile = "/var/lib/inception/audi.token";
  };
in
{
  systemd.services.audi-ssh-certificate = certificates.service;
  systemd.timers.audi-ssh-certificate = certificates.timer;
  users.groups.audi = {};
  users.users.audi = { isSystemUser = true; group = "audi"; };
  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 22 80 443 ];
  # Setgid provides socket group access; Lilly still checks the exact Audi UID.
  systemd.tmpfiles.rules = [
    "d /run/lilly-ingress 2750 root audi -"
    "d /run/inception-proofs 0750 root audi -"
  ];

  systemd.services.inception-audi = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "inception-enrollment.service" "inception-namespace.service" "marshall-inception.service" ];
    after = [ "inception-enrollment.service" "inception-namespace.service" "marshall-inception.service" "inception-ssh-trust.service" ];
    script = ''
      export INCEPTION_CONFIG=${publicConfig}
      ${pkgs.python3}/bin/python3 ${./.}/roles.py ${../.}
      exec ${pkgs.python3}/bin/python3 ${./.}/prepare.py exec ${publicConfig} ${packages.marshall}/bin/marshall eval 'Code.eval_file("${./audi.exs}")'
    '';
    serviceConfig = {
      Type = "oneshot"; RemainAfterExit = true; UMask = "0077";
      # The authority registration calls Marshall's Fleet API immediately
      # after its process starts. Retry the bounded bootstrap when the API is
      # still coming up; a failed first transaction must not strand the
      # dependent gateway in an inactive state.
      Restart = "on-failure"; RestartSec = 5; StartLimitIntervalSec = 0;
    };
  };

  # @cc [owner:ghuntley,label:security;recovery] inception-audi-service-custody
  # Inner Audi MUST run unprivileged with its own persistent host identity and
  # local credential. Root bootstrap inputs MUST enter via systemd credentials;
  # no administrative SSH service or root login may be enabled. IP transports
  # MUST be IPv4; local Netlink is only for interface discovery. Restart MUST
  # preserve the SSH host key. Public wildcard material comes from inner
  # Marshall's authenticated control API and stays in Audi memory.
  systemd.services.audi = pkgs.lib.mkMerge [ certificates.startup {
    wantedBy = [ "multi-user.target" ];
    requires = [ "inception-audi.service" ];
    after = [ "inception-audi.service" "marshall-inception.service" "inception-ssh-trust.service" "lilly-network.service" "lilly.service" ];
    path = [ pkgs.openssh ];
    environment = {
      AUDI_CONFIG_FILE = "/run/credentials/audi.service/runtime.json";
      RELEASE_TMP = "/run/audi";
      RELEASE_DISTRIBUTION = "none";
      ERL_CRASH_DUMP = "/dev/null";
      ERL_FLAGS = "+S 2:2";
    };
    preStart = ''
      ${pkgs.coreutils}/bin/install -m 0400 "$CREDENTIALS_DIRECTORY/gateway.token" /run/audi/gateway.token
      ${pkgs.coreutils}/bin/mkdir -p -m 0700 /var/lib/audi/keys
      if ! test -e /var/lib/audi/keys/ssh_host_ed25519_key && ! test -L /var/lib/audi/keys/ssh_host_ed25519_key; then
        ${pkgs.coreutils}/bin/rm -f /run/audi/new-host-key /run/audi/new-host-key.pub
        ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C "" -f /run/audi/new-host-key
        ${pkgs.coreutils}/bin/mv /run/audi/new-host-key /var/lib/audi/keys/ssh_host_ed25519_key
      fi
      ${pkgs.openssh}/bin/ssh-keygen -y -f /var/lib/audi/keys/ssh_host_ed25519_key > /run/audi/host-key.export
      # OpenSSH preserves an existing key comment with -y. Publication accepts
      # only the canonical type and base64 fields, including after an upgrade.
      ${pkgs.coreutils}/bin/cut -d ' ' -f 1,2 /run/audi/host-key.export > /run/audi/host-key.pub
      ${pkgs.coreutils}/bin/mv /run/audi/host-key.pub /var/lib/audi/keys/ssh_host_ed25519_key.pub
      # The SSH listener requires its certificate before it can start. Issue
      # the first certificate from this already enrolled gateway service;
      # the separate renewal unit remains ordered after the running daemon.
      # Keep the credential directory explicit for this ExecStartPre helper;
      # host certificate issuance must use this unit's systemd credentials.
      # Marshall's FleetEndpoint is started by the same post-ready target and
      # can still be binding its TLS socket after the service transaction has
      # become active. Keep this service activating while the bounded helper
      # retries; a transient listener race must not strand Audi inactive.
      for attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
        if CREDENTIALS_DIRECTORY=/run/credentials/audi.service ${certificates.command}; then
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 5
      done
      exit 1
    '';
    script = ''
      export RELEASE_COOKIE
      RELEASE_COOKIE="$(${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/basenc --base16 -w0)"
      exec ${packages.audi}/bin/audi start
    '';
    serviceConfig = {
      Type = "exec"; User = "audi"; Group = "audi"; UMask = "0077";
      LoadCredential = [
        "gateway.token:/var/lib/inception/audi.token"
        "runtime.json:/run/inception/audi.json"
        "ca.pem:/run/inception-public/ca.crt"
        "issuer-trust.pem:/run/inception/audi-trust.pem"
      ];
      StateDirectory = "audi"; StateDirectoryMode = "0700";
      RuntimeDirectory = "audi"; RuntimeDirectoryMode = "0700";
      Restart = "on-failure"; RestartSec = 5; TimeoutStartSec = 900; TimeoutStopSec = 30;
      KillMode = "control-group"; CPUQuota = "200%"; MemoryMax = "1G";
      LimitNOFILE = 65536;
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      NoNewPrivileges = true; PrivateDevices = true; PrivateTmp = true;
      ProtectSystem = "strict"; ProtectHome = true;
      ProtectKernelTunables = true; ProtectKernelModules = true; ProtectControlGroups = true;
      # getifaddrs uses local Netlink to verify the configured probe address.
      # CAP_NET_ADMIN is absent; no IPv6 transport socket is permitted.
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_NETLINK" ];
      RestrictSUIDSGID = true; LockPersonality = true;
    };
  } ];
}
