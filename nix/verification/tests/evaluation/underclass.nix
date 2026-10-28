{ pkgs, nixpkgs, module }:
let
  inherit (pkgs) lib;
  system = "x86_64-linux";
  evaluate = extra: (nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      module
      {
        system.stateVersion = "26.05";
        boot.loader.grub.enable = false;
        fileSystems."/" = { device = "/dev/vda"; fsType = "ext4"; };
      }
      extra
    ];
  }).config;
  bare = evaluate { };
  enabled = evaluate {
    services.tailscale.enable = true;
    services.underclass = {
      enable = true;
      environmentFile = "/run/overalls-secrets/underclass/environment";
      secretUnits = [ "overalls-secrets-underclass.service" ];
    };
  };
  noTailscale = evaluate { services.underclass.enable = true; };
  egressNodeOnly = evaluate {
    services.underclass = { enable = true; tailscaleServe.enable = false; egress.enable = true; };
  };
  routed = evaluate {
    services.underclass = {
      enable = true;
      tailscaleServe.enable = false;
      egress = { enable = true; exitNode = "mac-mini"; };
    };
  };
  routedDirect = evaluate {
    services.underclass = {
      enable = true;
      tailscaleServe.enable = false;
      egress = { enable = true; route = true; };
    };
  };
  exitWithoutRoute = evaluate {
    services.underclass = {
      enable = true;
      tailscaleServe.enable = false;
      egress = { enable = true; exitNode = "mac-mini"; route = false; };
    };
  };
  routedWithoutNode = evaluate {
    services.underclass = { enable = true; tailscaleServe.enable = false; egress.exitNode = "mac-mini"; };
  };
  service = enabled.systemd.services.underclass;
  startPre = unit: lib.concatStringsSep "\n" (lib.toList unit.serviceConfig.ExecStartPre);
  egressUnit = egressNodeOnly.systemd.services.underclass-egress;
  routedService = routed.systemd.services.underclass;
  routedDirectService = routedDirect.systemd.services.underclass;
  publication = enabled.systemd.services.underclass-tailscale-serve;

  # @cc [owner:ghuntley,label:verification] underclass-configuration-check
  # This check MUST verify opt-in reuse, loopback-only execution, runtime secret
  # ordering, bounded hardening, tailnet-only publication and opt-in egress
  # confinement without claiming a live tailnet or provider account.
  cases = {
    optIn = !bare.services.underclass.enable && !(bare.systemd.services ? underclass);
    hostCommands = builtins.elem enabled.services.underclass.package enabled.environment.systemPackages;
    loopbackOnly = service.serviceConfig.ExecStart
      == "${lib.getExe enabled.services.underclass.package} serve --bind 127.0.0.1:8080"
      && enabled.networking.firewall.allowedTCPPorts == [ ];
    runtimeSecrets = service.serviceConfig.EnvironmentFile
      == "/run/overalls-secrets/underclass/environment"
      && lib.hasInfix ''test "$UNDERCLASS_PROXY_KEY" != "$UNDERCLASS_UI_TOKEN"'' (startPre service)
      && builtins.elem "overalls-secrets-underclass.service" service.requires
      && builtins.elem "overalls-secrets-underclass.service" service.after;
    bounded = service.serviceConfig.DynamicUser
      && service.serviceConfig.StateDirectory == "underclass"
      && service.serviceConfig.RuntimeDirectory == "underclass"
      && service.serviceConfig.RuntimeDirectoryMode == "0755"
      && service.environment.UNDERCLASS_MONITOR_SOCKET == "/run/underclass/monitor.sock"
      && service.serviceConfig.RestrictAddressFamilies == [ "AF_UNIX" "AF_INET" ]
      && service.serviceConfig.MemoryMax == "1G"
      && service.serviceConfig.CPUQuota == "200%"
      && service.serviceConfig.TasksMax == 512
      && service.serviceConfig.LimitNOFILE == 8192;
    tailnetOnly = lib.hasInfix " serve --yes --https=443 http://127.0.0.1:8080"
      publication.serviceConfig.ExecStart
      && !(lib.hasInfix " --bg " publication.serviceConfig.ExecStart)
      && !(lib.hasInfix "funnel" publication.serviceConfig.ExecStart)
      && publication.serviceConfig.Type == "exec"
      && publication.serviceConfig.Restart == "always"
      && !(publication.serviceConfig ? ExecStop)
      && builtins.elem "tailscaled.service" publication.requires
      && builtins.elem "underclass.service" publication.requires;
    tailscaleRequired = !(lib.all (item: item.assertion) noTailscale.assertions);

    # @cc [owner:ghuntley,label:verification;security] underclass-egress-configuration-check
    # Egress MUST stay opt-in in two stages: the node alone leaves Underclass's
    # direct egress untouched, and only routing (implied by a selected exit node)
    # confines Underclass to loopback behind the privileged start gate.
    egressOptIn = !(enabled.systemd.services ? underclass-egress)
      && !(service.environment ? HTTPS_PROXY)
      && !(service.serviceConfig ? IPAddressDeny)
      && builtins.length (lib.toList service.serviceConfig.ExecStartPre) == 1;
    egressNodeIsolated = let start = egressUnit.serviceConfig.ExecStart; in
      lib.hasInfix " --tun=userspace-networking " start
      && lib.hasInfix " --socket=/run/underclass-egress/tailscaled.sock " start
      && lib.hasSuffix " --outbound-http-proxy-listen=127.0.0.1:1055" start
      && egressUnit.serviceConfig.DynamicUser
      && egressUnit.serviceConfig.StateDirectory == "underclass-egress"
      && egressUnit.serviceConfig.CapabilityBoundingSet == ""
      && !(builtins.elem "AF_INET6" egressUnit.serviceConfig.RestrictAddressFamilies)
      && !(egressNodeOnly.systemd.services.underclass.environment ? HTTPS_PROXY)
      && builtins.any (p: (p.name or "") == "underclass-egress") egressNodeOnly.environment.systemPackages;
    egressRouted = routedService.environment.HTTPS_PROXY == "http://127.0.0.1:1055"
      && routedService.environment.HTTP_PROXY == "http://127.0.0.1:1055"
      && routedService.serviceConfig.IPAddressDeny == "any"
      && routedService.serviceConfig.IPAddressAllow == "localhost"
      && lib.hasInfix "+/nix/store/" (startPre routedService)
      && lib.hasInfix "underclass-egress-gate" (startPre routedService)
      && builtins.elem "underclass-egress.service" routedService.requires
      && builtins.elem "underclass-egress.service" routedService.after;
    egressRoutedDirect = routedDirect.services.underclass.egress.exitNode == null
      && routedDirectService.environment.HTTPS_PROXY == "http://127.0.0.1:1055"
      && routedDirectService.environment.HTTP_PROXY == "http://127.0.0.1:1055"
      && routedDirectService.serviceConfig.IPAddressDeny == "any"
      && routedDirectService.serviceConfig.IPAddressAllow == "localhost"
      && lib.hasInfix "underclass-egress-gate" (startPre routedDirectService)
      && startPre routedDirectService != startPre routedService
      && builtins.elem "underclass-egress.service" routedDirectService.requires
      && routed.services.underclass.egress.route
      && !egressNodeOnly.services.underclass.egress.route;
    egressNodeRequired = !(lib.all (item: item.assertion) routedWithoutNode.assertions);
    exitNodeRequiresRoute = !(lib.all (item: item.assertion) exitWithoutRoute.assertions);
    egressJoinTags = let cli = lib.findFirst (p: (p.name or "") == "underclass-egress") null
      egressNodeOnly.environment.systemPackages; in
      egressNodeOnly.services.underclass.egress.tags == [ "tag:underclass" ]
      && cli != null && lib.hasInfix "--advertise-tags=tag:underclass" cli.text;
  };
  failed = builtins.attrNames (lib.filterAttrs (_: result: !result) cases);
in
assert lib.assertMsg (failed == [ ]) "Underclass configuration checks failed: ${lib.concatStringsSep ", " failed}";
pkgs.writeText "overalls-underclass-configuration-check.json" (builtins.toJSON cases)
