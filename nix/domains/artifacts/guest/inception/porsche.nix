{ packages, publicConfig }:
{ pkgs, ... }:
let
  certificates = import ../../../system/ssh-host-certificate.nix {
    inherit pkgs packages;
    role = "porsche";
    # Keep localhost as the TLS authority while the helper pins its connection
    # to IPv4 loopback. This matches the verified Python publication client:
    # localhost SNI/HTTP semantics over a raw IPv4 socket.
    origin = "https://localhost:5443";
    caFile = "/run/inception-public/ca.crt";
    credentialFile = "/var/lib/inception/porsche.token";
  };
in
{
  systemd.services.porsche-ssh-certificate = certificates.service;
  systemd.timers.porsche-ssh-certificate = certificates.timer;
  users.groups.porsche = {};
  users.users.porsche = { isSystemUser = true; group = "porsche"; };
  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 22 ];

  systemd.services.inception-porsche = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "inception-enrollment.service" "inception-namespace.service" "marshall-inception.service" ];
    after = [ "inception-enrollment.service" "inception-namespace.service" "marshall-inception.service" "inception-ssh-trust.service" ];
    script = ''
      export INCEPTION_CONFIG=${publicConfig}
      ${pkgs.python3}/bin/python3 ${./.}/prepare.py exec ${publicConfig} ${packages.marshall}/bin/marshall eval 'Code.eval_file("${./porsche.exs}")'
      exec ${pkgs.python3}/bin/python3 ${./.}/roles.py ${../.}
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

  # @cc [owner:ghuntley,label:security;recovery] inception-porsche-service-custody
  # Inner Porsche MUST run unprivileged with its own persistent host identity and
  # local credential. Root bootstrap inputs MUST enter via systemd credentials;
  # no administrative SSH service or root login may be enabled. Only IPv4 and
  # Unix sockets are permitted. Restart MUST preserve the existing private key.
  systemd.services.porsche = pkgs.lib.mkMerge [ certificates.startup {
    wantedBy = [ "multi-user.target" ];
    requires = [ "inception-porsche.service" ];
    after = [ "inception-porsche.service" "marshall-inception.service" "inception-ssh-trust.service" "lilly-network.service" ];
    path = [ pkgs.openssh ];
    environment = {
      PORSCHE_CONFIG_FILE = "/run/credentials/porsche.service/runtime.json";
      RELEASE_TMP = "/run/porsche";
      RELEASE_DISTRIBUTION = "none";
      ERL_CRASH_DUMP = "/dev/null";
      ERL_FLAGS = "+S 2:2";
    };
    preStart = ''
      ${pkgs.coreutils}/bin/install -m 0400 "$CREDENTIALS_DIRECTORY/gateway.token" /run/porsche/gateway.token
      ${pkgs.coreutils}/bin/mkdir -p -m 0700 /var/lib/porsche/keys
      if ! test -e /var/lib/porsche/keys/ssh_host_ed25519_key && ! test -L /var/lib/porsche/keys/ssh_host_ed25519_key; then
        ${pkgs.coreutils}/bin/rm -f /run/porsche/new-host-key /run/porsche/new-host-key.pub
        ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C "" -f /run/porsche/new-host-key
        ${pkgs.coreutils}/bin/mv /run/porsche/new-host-key /var/lib/porsche/keys/ssh_host_ed25519_key
      fi
      ${pkgs.openssh}/bin/ssh-keygen -y -f /var/lib/porsche/keys/ssh_host_ed25519_key > /run/porsche/host-key.export
      # OpenSSH preserves an existing key comment with -y. Publication accepts
      # only the canonical type and base64 fields, including after an upgrade.
      ${pkgs.coreutils}/bin/cut -d ' ' -f 1,2 /run/porsche/host-key.export > /run/porsche/host-key.pub
      ${pkgs.coreutils}/bin/mv /run/porsche/host-key.pub /var/lib/porsche/keys/ssh_host_ed25519_key.pub
      # The SSH listener requires its certificate before it can start. Issue
      # the first certificate from this already enrolled gateway service;
      # the separate renewal unit remains ordered after the running daemon.
      # systemd exposes CREDENTIALS_DIRECTORY to service commands, including
      # ExecStartPre on current releases. Keep the path explicit here as well:
      # the certificate helper is deliberately run before the long-lived
      # process and must resolve its two credentials from this unit's custody.
      # Marshall's FleetEndpoint is started by the same post-ready target and
      # can still be binding its TLS socket after the service transaction has
      # become active. Keep this service activating while the bounded helper
      # retries; a transient listener race must not strand Porsche inactive.
      for attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
        if CREDENTIALS_DIRECTORY=/run/credentials/porsche.service ${certificates.command}; then
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 5
      done
      exit 1
    '';
    script = ''
      export RELEASE_COOKIE
      RELEASE_COOKIE="$(${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/basenc --base16 -w0)"
      exec ${packages.porsche}/bin/porsche start
    '';
    serviceConfig = {
      Type = "exec"; User = "porsche"; Group = "porsche"; UMask = "0077";
      LoadCredential = [
        "gateway.token:/var/lib/inception/porsche.token"
        "runtime.json:/run/inception/porsche.json"
        "ca.pem:/run/inception-public/ca.crt"
      ];
      StateDirectory = "porsche"; StateDirectoryMode = "0700";
      RuntimeDirectory = "porsche"; RuntimeDirectoryMode = "0700";
      Restart = "on-failure"; RestartSec = 5; TimeoutStartSec = 900; TimeoutStopSec = 30;
      KillMode = "control-group"; CPUQuota = "200%"; MemoryMax = "1G";
      LimitNOFILE = 65536;
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      NoNewPrivileges = true; PrivateDevices = true; PrivateTmp = true;
      ProtectSystem = "strict"; ProtectHome = true;
      ProtectKernelTunables = true; ProtectKernelModules = true; ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" ];
      RestrictSUIDSGID = true; LockPersonality = true;
    };
  } ];
}
