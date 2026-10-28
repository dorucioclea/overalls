# @cc [owner:ghuntley,label:verification;security] underclass-egress-machine
# This check MUST exercise a real tailnet (private headscale control server,
# kernel exit node and the dedicated userspace egress node) and observe the
# source address at a separate internet host. It MUST show that Underclass's
# unit reaches that host only through the exit node, refuses to start before
# the egress node is logged in, and fails rather than leaks when the exit node
# goes away. It MUST also show that routing without an exit node clears a stale
# exit-node preference, keeps the unit confined to the egress proxy, and leaves
# from the host's own address. It does not exercise live providers or the
# production tailnet.
{ pkgs, module, ... }:
let
  tls = pkgs.runCommand "underclass-egress-tls" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    mkdir -p $out
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 3650 \
      -subj /CN=headscale -addext "subjectAltName=DNS:headscale" \
      -keyout $out/headscale.key -out $out/headscale.pem 2>/dev/null
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 3650 \
      -subj /CN=internet -addext "subjectAltName=DNS:internet,DNS:upstream.test,DNS:provider.test" \
      -keyout $out/internet.key -out $out/internet.pem 2>/dev/null
  '';
  trust = { security.pki.certificateFiles = [ "${tls}/headscale.pem" "${tls}/internet.pem" ]; };
in
pkgs.testers.runNixOSTest ({ nodes, ... }: let
  internetAddress = nodes.internet.networking.primaryIPAddress;
  # A public-style address outside every local subnet, as provider APIs are.
  upstreamAddress = "203.0.113.10";
  upstreamRoute = { address = "203.0.113.0"; prefixLength = 24; via = internetAddress; };
in {
  name = "overalls-underclass-egress";

  # The fleet is IPv4-only (module-ipv4-service-sandboxes); match it so the
  # observed source address is unambiguous.
  defaults.networking.enableIPv6 = false;

  nodes = {
    # Tailnet control plane with an embedded DERP relay on the underlay only.
    headscale = {
      virtualisation.vlans = [ 1 ];
      services.headscale = {
        enable = true;
        port = 8080;
        settings = {
          server_url = "https://headscale";
          prefixes.v4 = "100.64.0.0/10";
          derp = {
            server = {
              enabled = true;
              region_id = 999;
              stun_listen_addr = "0.0.0.0:3478";
            };
            urls = [ ];
          };
          dns = {
            base_domain = "tailnet";
            override_local_dns = false;
          };
          # The fleet user owns the egress node's advertised tag.
          policy.path = pkgs.writeText "underclass-egress-policy.json" (builtins.toJSON {
            tagOwners."tag:underclass" = [ "fleet@" ];
            acls = [{ action = "accept"; src = [ "*" ]; dst = [ "*:*" ]; }];
          });
        };
      };
      services.nginx = {
        enable = true;
        virtualHosts.headscale = {
          addSSL = true;
          sslCertificate = "${tls}/headscale.pem";
          sslCertificateKey = "${tls}/headscale.key";
          locations."/" = {
            proxyPass = "http://127.0.0.1:8080";
            proxyWebsockets = true;
          };
        };
      };
      networking.firewall.allowedTCPPorts = [ 80 443 ];
      networking.firewall.allowedUDPPorts = [ 3478 ];
      environment.systemPackages = [ pkgs.headscale pkgs.jq ];
    };

    # Stands in for the Australian Mac Mini: a tailnet exit node with its own
    # path to the internet host.
    exit = {
      imports = [ trust ];
      # Only the exit node can resolve upstream.test, so a proxied request by
      # that name proves resolution happens at the exit, as it would in Australia.
      networking.interfaces.eth2.ipv4.routes = [ upstreamRoute ];
      networking.resolvconf.enable = false;
      environment.etc."resolv.conf".text = "nameserver ${internetAddress}\n";
      virtualisation.vlans = [ 1 2 ];
      services.tailscale = {
        enable = true;
        useRoutingFeatures = "server";
      };
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
    };

    # Echoes the TCP source address of every request, over HTTP and HTTPS.
    internet = {
      virtualisation.vlans = [ 2 ];
      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = false;
        settings = {
          no-resolv = true;
          address = [ "/upstream.test/${upstreamAddress}" "/provider.test/${upstreamAddress}" ];
        };
      };
      networking.firewall.allowedUDPPorts = [ 53 ];
      networking.interfaces.eth1.ipv4.addresses = [ { address = upstreamAddress; prefixLength = 32; } ];
      services.nginx = {
        enable = true;
        virtualHosts.internet = {
          addSSL = true;
          sslCertificate = "${tls}/internet.pem";
          sslCertificateKey = "${tls}/internet.key";
          locations."/" = {
            return = "200 $remote_addr";
            extraConfig = "default_type text/plain;";
          };
        };
      };
      networking.firewall.allowedTCPPorts = [ 53 80 443 ];
    };

    # Fleet host: reaches the internet host directly and the tailnet underlay.
    host = {
      imports = [ module trust ];
      virtualisation.vlans = [ 1 2 ];
      virtualisation.memorySize = 1536;
      networking.interfaces.eth2.ipv4.routes = [ upstreamRoute ];
      networking.hosts.${upstreamAddress} = [ "provider.test" ];
      services.underclass = {
        enable = true;
        tailscaleServe.enable = false;
        environmentFile = "/etc/underclass-test.env";
        egress = {
          enable = true;
          exitNode = "exit";
        };
      };
      # ADR-0260: the same egress node and loopback confinement, with no exit node.
      specialisation.routed-direct.configuration.services.underclass.egress = {
        exitNode = pkgs.lib.mkForce null;
        route = true;
      };
      environment.etc."underclass-test.env".text = ''
        UNDERCLASS_PROXY_KEY=synthetic-proxy-key
        UNDERCLASS_UI_TOKEN=synthetic-admin-token
      '';
      environment.systemPackages = [ pkgs.curl pkgs.jq ];
    };
  };

  testScript = ''
    import json
    import shlex

    from test_driver.machine import QemuMachine

    EGRESS = "underclass-egress"
    PROXY = "http://127.0.0.1:1055"
    UNDERCLASS_CGROUP = "/sys/fs/cgroup/system.slice/underclass.service/cgroup.procs"


    def vlan2_address(node: QemuMachine) -> str:
        output: str = node.succeed("ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1")
        return next(a for a in output.split() if a.startswith("192.168.2."))


    def in_underclass_unit(command: str) -> str:
        # Run inside Underclass's own cgroup so its systemd IP filter applies.
        inner = f"echo $$ > {UNDERCLASS_CGROUP} && exec {command}"
        return f"sh -c {shlex.quote(inner)}"


    def source_seen(url: str, proxy: bool) -> str:
        via = f"-x {PROXY} " if proxy else ""
        output: str = host.succeed(f"curl -sf --max-time 20 {via}{url}")
        return output.strip()


    def expect_source(url: str, proxy: bool, expected: str) -> None:
        seen = source_seen(url, proxy)
        assert seen == expected, f"{url} proxy={proxy}: saw {seen!r}, expected {expected!r}"


    start_all()
    headscale.wait_for_unit("headscale.service")
    headscale.wait_for_open_port(443)
    internet.wait_for_open_port(443)
    host.wait_for_unit("underclass-egress.service")

    host_address = vlan2_address(host)
    exit_address = vlan2_address(exit)

    with subtest("the host has a direct route to the internet host"):
        expect_source("https://provider.test/", proxy=False, expected=host_address)

    with subtest("Underclass refuses to start before the egress node logs in"):
        host.wait_until_succeeds(
            "journalctl -u underclass.service --no-pager | grep -q 'cannot select exit node exit'"
        )
        host.fail("systemctl is-active underclass.service")
        host.fail("ss -ltn | grep -F '127.0.0.1:8080'")

    with subtest("the egress node never touches the host network stack"):
        host.fail("ip link show tailscale0")
        host.succeed("ss -ltnH | awk '{print $4}' | grep -qx '127.0.0.1:1055'")
        host.fail("ss -ltnH | awk '{print $4}' | grep -E '^(0\\.0\\.0\\.0|\\*|\\[::\\]):1055$'")
        host.succeed("test \"$(ip rule | wc -l)\" -eq 3")

    headscale.succeed("headscale users create fleet")
    users = json.loads(headscale.succeed("headscale users list -o json"))
    user_id = next(u["id"] for u in users if u["name"] == "fleet")
    authkey = headscale.succeed(f"headscale preauthkeys create -u {user_id} --reusable").strip().splitlines()[-1]
    login = f"--login-server https://headscale --auth-key {authkey}"

    exit.succeed(f"tailscale up {login} --hostname=exit --advertise-exit-node")
    nodes = json.loads(headscale.succeed("headscale nodes list -o json"))
    exit_id = next(n["id"] for n in nodes if n["given_name"] == "exit")
    headscale.succeed(f"headscale nodes approve-routes -i {exit_id} -r 0.0.0.0/0,::/0")

    # Production joins Tailscale with `underclass-egress up`, which advertises
    # tag:underclass. Headscale, this test's stand-in control server, refuses
    # client-requested tags on auth-key joins and takes them from the key, so the
    # node joins through the raw socket CLI with a key carrying the tag.
    tagged = headscale.succeed(
        f"headscale preauthkeys create -u {user_id} --reusable --tags tag:underclass"
    ).strip().splitlines()[-1]
    host.succeed(
        "${pkgs.tailscale}/bin/tailscale --socket=/run/underclass-egress/tailscaled.sock up"
        f" --login-server https://headscale --auth-key {tagged} --hostname=host-underclass-egress"
    )

    with subtest("the egress node carries tag:underclass"):
        status = json.loads(host.succeed(f"{EGRESS} status --json"))
        assert "tag:underclass" in (status["Self"].get("Tags") or []), status["Self"]

    with subtest("Underclass starts once the exit node is selected"):
        host.wait_for_unit("underclass.service")
        host.wait_for_open_port(8080)
        status = json.loads(host.succeed(f"{EGRESS} status --json"))
        assert status["ExitNodeStatus"]["Online"], status["ExitNodeStatus"]
        host.succeed("curl -sf -H 'Authorization: Bearer synthetic-proxy-key' http://127.0.0.1:8080/v1/models")

    with subtest("proxied HTTPS leaves through the exit node and resolves there"):
        host.fail("getent hosts upstream.test")
        host.wait_until_succeeds(f"curl -sf --max-time 20 -x {PROXY} https://upstream.test/", timeout=120)
        expect_source("https://upstream.test/", proxy=True, expected=exit_address)
        expect_source("http://upstream.test/", proxy=True, expected=exit_address)

    with subtest("the host's own traffic still leaves directly"):
        expect_source("https://provider.test/", proxy=False, expected=host_address)
        host.fail("tailscale status")

    with subtest("Underclass's unit reaches the internet only through the egress proxy"):
        host.fail(in_underclass_unit("curl -sf --max-time 5 https://provider.test/"))
        seen = host.succeed(in_underclass_unit(f"curl -sf --max-time 20 -x {PROXY} https://upstream.test/"))
        assert seen.strip() == exit_address, seen
        unit_env = host.succeed("systemctl show underclass.service -p Environment --value")
        assert f"HTTPS_PROXY={PROXY}" in unit_env, unit_env

    with subtest("losing the exit node fails requests instead of leaking"):
        internet.succeed("truncate -s0 /var/log/nginx/access.log")
        exit.succeed("systemctl stop tailscaled.service")
        host.wait_until_fails(f"curl -sf --max-time 10 -x {PROXY} https://provider.test/", timeout=120)
        host.fail(f"curl -sf --max-time 10 -x {PROXY} http://provider.test/")
        internet.fail(f"grep -F {host_address} /var/log/nginx/access.log")

    with subtest("Underclass restarts while the exit node is offline"):
        host.succeed("systemctl restart underclass.service")
        host.wait_for_unit("underclass.service")
        host.fail(f"curl -sf --max-time 10 -x {PROXY} https://provider.test/")
        internet.fail(f"grep -F {host_address} /var/log/nginx/access.log")

    with subtest("each Underclass start re-asserts a cleared exit node"):
        exit.succeed("systemctl start tailscaled.service")
        host.succeed(f"{EGRESS} set --exit-node=")
        host.succeed("systemctl restart underclass.service")
        host.wait_for_unit("underclass.service")
        status = json.loads(host.succeed(f"{EGRESS} status --json"))
        assert status.get("ExitNodeStatus", {}).get("ID"), status.get("ExitNodeStatus")
        host.wait_until_succeeds(f"curl -sf --max-time 20 -x {PROXY} https://upstream.test/", timeout=120)
        expect_source("https://upstream.test/", proxy=True, expected=exit_address)

    with subtest("routing without an exit node clears a stale one and leaves directly"):
        # The stored preference still names the exit node, as production did when
        # its exit node went offline; the gate must clear it on start.
        exit.succeed("systemctl stop tailscaled.service")
        host.succeed(
            "/run/current-system/specialisation/routed-direct/bin/switch-to-configuration test"
        )
        host.succeed("systemctl restart underclass.service")
        host.wait_for_unit("underclass.service")
        status = json.loads(host.succeed(f"{EGRESS} status --json"))
        assert not (status.get("ExitNodeStatus") or {}).get("ID"), status.get("ExitNodeStatus")
        host.wait_until_succeeds(f"curl -sf --max-time 20 -x {PROXY} https://provider.test/", timeout=120)
        expect_source("https://provider.test/", proxy=True, expected=host_address)
        host.fail(in_underclass_unit("curl -sf --max-time 5 https://provider.test/"))
        seen = host.succeed(in_underclass_unit(f"curl -sf --max-time 20 -x {PROXY} https://provider.test/"))
        assert seen.strip() == host_address, seen
        unit_env = host.succeed("systemctl show underclass.service -p Environment --value")
        assert f"HTTPS_PROXY={PROXY}" in unit_env, unit_env
        exit.succeed("systemctl start tailscaled.service")
        host.succeed("/run/current-system/bin/switch-to-configuration test")
        host.succeed("systemctl restart underclass.service")
        host.wait_for_unit("underclass.service")

    with subtest("the egress node's state survives a reboot"):
        host.reboot()
        host.wait_for_shutdown()
        host.start()
        host.wait_for_unit("underclass.service")
        host.wait_until_succeeds(f"curl -sf --max-time 20 -x {PROXY} https://upstream.test/", timeout=180)
        expect_source("https://upstream.test/", proxy=True, expected=exit_address)
  '';
})
