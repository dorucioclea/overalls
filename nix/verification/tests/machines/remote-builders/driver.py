"""Exercise real reciprocal Nix caches, local-build placement, custody and failure."""

import shlex

start_all()
pairs = [(alpha, beta), (beta, alpha)]
for node, _peer in pairs:
    node.wait_for_unit("sshd.service")
    node.succeed(f"printf '%s\\n' {node.name} > /builder-id")
    node.succeed(
        "install -d -m700 /run/fixture; ssh-keygen -q -t ed25519 -N '' -f /run/fixture/client"
    )
for node, peer in pairs:
    public = peer.succeed("cat /run/fixture/client.pub").strip()
    pin = peer.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub").strip()
    node.succeed("rm /etc/ssh/authorized_keys.d/nix-ssh /etc/ssh/overalls-builders-known-hosts")
    node.succeed(
        f"printf '%s\\n' {shlex.quote('restrict ' + public)} > /etc/ssh/authorized_keys.d/nix-ssh"
    )
    node.succeed(
        f"printf '%s\\n' {shlex.quote('overalls-builder-' + peer.name + ' ' + pin)} > /etc/ssh/overalls-builders-known-hosts"
    )
    node.succeed(
        "python /etc/seal.py; systemctl restart overalls-secrets-remote-builders; systemctl restart nix-daemon"
    )
    node.succeed("test $(stat -c %a /run/overalls-secrets/remote-builders/id_ed25519) = 600")
    node.fail('su -s /bin/sh nobody -c "cat /run/overalls-secrets/remote-builders/id_ed25519"')
    node.fail('su -s /bin/sh nix-ssh -c "cat /run/overalls-secrets/remote-builders/id_ed25519"')

with subtest("no build delegation: every derivation executes locally on both peers"):
    for node, _peer in pairs:
        paths = node.succeed(
            f"nix-build /etc/jobs.nix --argstr batch {node.name} --no-out-link",
            timeout=120,
        ).splitlines()
        assert len(paths) == 6
        for path in paths:
            assert node.succeed(f"cat {path}/host").strip() == node.name, path
        node.succeed('test -z "$(nix config show builders)"')
        node.fail("test -e /etc/nix/machines")

with subtest("reciprocal unsigned peer substitution avoids rebuilding"):
    for node, peer in pairs:
        batch = "cached-" + node.name
        source = node.succeed(
            f'nix-build /etc/jobs.nix --argstr batch {batch} --arg count 1 --no-out-link --option builders "" --option substitute false'
        ).strip()
        fetched = peer.succeed(
            f'nix-build /etc/jobs.nix --argstr batch {batch} --arg count 1 --no-out-link --option builders "" --max-jobs 0',
            timeout=60,
        ).strip()
        assert source == fetched
        assert peer.succeed(f"cat {fetched}/host").strip() == node.name

with subtest("SSH command and forwarding restrictions"):
    alpha.succeed(
        'timeout 5 ssh -T overalls-builder-beta "touch /tmp/forbidden-shell" </dev/null >/dev/null 2>&1 || true'
    )
    beta.fail("test -e /tmp/forbidden-shell")
    code, output = alpha.execute(
        "timeout 10 ssh -N -o ExitOnForwardFailure=yes -R 19999:localhost:22 overalls-builder-beta 2>&1"
    )
    assert code == 255 and "remote port forwarding failed" in output, (code, output)
    # Wrong host pin refuses the connection without changing authoritative identity.
    alpha.succeed(
        "cp /etc/ssh/overalls-builders-known-hosts /run/fixture/pins; sed -i s/overalls-builder-beta/unknown/ /etc/ssh/overalls-builders-known-hosts"
    )
    alpha.fail("nix store ping --store ssh-ng://nix-ssh@overalls-builder-beta")
    alpha.succeed("cp /run/fixture/pins /etc/ssh/overalls-builders-known-hosts")

with subtest("overlapping client-key rotation and retirement"):
    alpha.succeed(
        "cp /run/fixture/client /run/fixture/retired; rm /run/fixture/client /run/fixture/client.pub; ssh-keygen -q -t ed25519 -N '' -f /run/fixture/client"
    )
    public = alpha.succeed("cat /run/fixture/client.pub").strip()
    beta.succeed(
        f"printf '%s\\n' {shlex.quote('restrict ' + public)} >> /etc/ssh/authorized_keys.d/nix-ssh"
    )
    retired_probe = 'NIX_SSHOPTS="-F /dev/null -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/etc/ssh/overalls-builders-known-hosts -o HostKeyAlias=overalls-builder-beta -o BatchMode=yes -p 2222" nix store ping --store "ssh-ng://nix-ssh@beta?ssh-key=/run/fixture/retired"'
    alpha.succeed(retired_probe)
    alpha.succeed(
        "python /etc/seal.py; systemctl restart overalls-secrets-remote-builders; systemctl restart nix-daemon"
    )
    alpha.succeed("nix store ping --store ssh-ng://nix-ssh@overalls-builder-beta")
    beta.succeed(
        f"printf '%s\\n' {shlex.quote('restrict ' + public)} > /etc/ssh/authorized_keys.d/nix-ssh"
    )
    alpha.fail(retired_probe)
    alpha.succeed("nix store ping --store ssh-ng://nix-ssh@overalls-builder-beta")

with subtest("peer outage and failed key preparation preserve local execution"):
    beta.succeed("systemctl stop sshd")
    path = alpha.succeed(
        "nix-build /etc/jobs.nix --argstr batch outage --arg count 1 --no-out-link", timeout=90
    ).strip()
    assert alpha.succeed(f"cat {path}/host").strip() == "alpha"
    alpha.succeed("rm /run/fixture/keys.enc.json; systemctl stop overalls-secrets-remote-builders")
    alpha.fail("systemctl start overalls-secrets-remote-builders")
    alpha.succeed("systemctl start nix-daemon")
    path = alpha.succeed(
        "nix-build /etc/jobs.nix --argstr batch missing-key --arg count 1 --no-out-link", timeout=90
    ).strip()
    assert alpha.succeed(f"cat {path}/host").strip() == "alpha"
