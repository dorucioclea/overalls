# ADR-0185: Underclass upstream egress through a tailnet exit node

- ID: ADR-0185
- Date: 2026-10-17
- Status: accepted
- Implementation: partial
- Components: NixOS services, Underclass, Tailscale, fleet networking, deployment health
- Supersedes: none
- Superseded by: none

## Context

Underclass ([ADR-0102](0102-local-underclass-monitor-socket.md)) runs one
independent subscription pool on each fleet host. Each pool calls provider
APIs directly from the host's own Hetzner address. The user wants Underclass's
provider traffic, and only that traffic, to leave from Australia. The user's
Mac Mini in Australia is already on the tailnet as `mac-mini` and already
advertises itself as an exit node.

Observed facts:

- On Linux, the Tailscale exit-node preference applies to the whole node. If a
  fleet host's own `tailscaled` selected an exit node, Marshall, Lilly,
  updates, ACME and DNS would all leave through Australia.
- Underclass runs as a systemd dynamic user, so its UID changes between starts
  and cannot be matched by owner-based policy routing.
- Underclass builds its upstream client with `reqwest` 0.13.5 and default
  features (`~/src/underclass/src/main.rs`). The `system-proxy` feature honours
  `HTTPS_PROXY`/`HTTP_PROXY` and does not fall back to a direct connection when
  a proxy is configured. HTTPS goes through `CONNECT host:port`, so Underclass
  does not resolve provider names itself.
- A userspace-networking `tailscaled` creates no TUN device or routes, and can
  expose a loopback HTTP proxy that routes through its selected exit node. With
  no exit node selected, that proxy dials destinations directly from the host.
- `underclass.service` is an activation consumer and a health unit of the
  auto-updater ([ADR-0036](0036-automatic-host-updates.md)). A deployment
  that leaves it failing is rolled back.

## Decision

The user's 2026-10-17 instruction ("I like the tailscale option") authorizes
this decision. The module adds `services.underclass.egress`, enabled in two
stages.

1. `egress.enable` runs `underclass-egress.service`: a separate
   `tailscaled --tun=userspace-networking` under a dynamic user. It has its own
   state directory (`/var/lib/underclass-egress`), its own socket
   (`/run/underclass-egress/tailscaled.sock`), no capabilities, no IPv6 socket
   family, an ephemeral WireGuard port and an outbound HTTP proxy on
   `127.0.0.1:1055` only. The host's own `tailscaled`, Tailscale Serve and
   `tailscale0` firewall trust are unchanged. The node starts logged out. The
   module holds no Tailscale credential; an operator joins it once per host with
   `sudo underclass-egress up` (a wrapper bound to that socket). This stage does
   not change Underclass's traffic.
2. `egress.exitNode` routes Underclass:
   - Underclass gets `HTTPS_PROXY`/`HTTP_PROXY` pointing at the egress proxy.
   - systemd `IPAddressDeny=any` with `IPAddressAllow=localhost` confines the
     Underclass cgroup to loopback, so no code path can bypass the proxy.
   - Underclass requires the egress unit.
   - A privileged (`+`) `ExecStartPre` gate re-asserts
     `--exit-node=<node> --exit-node-allow-lan-access=false` on every start. It
     refuses to start while the node is logged out or has no exit node selected.
     Underclass's existing `Restart=always` retries every five seconds.

The gate enforces the safety condition (an exit node is selected), not
liveness. When the exit node is offline, Underclass still starts, and its
requests fail. DNS for provider names is resolved at the exit node, through the
`CONNECT` hostname.

The enrolled host profile enables stage 1. Stage 2 sets
`egress.exitNode = "mac-mini"` in a separate push, after the egress node has
been logged in on both hosts. A host whose node is not logged in would
otherwise fail Underclass's update health check and roll back. LAN access
through the exit node stays disabled: provider APIs are public addresses, and
allowing LAN access would let proxied connections to the host's own subnets
skip the exit node.

## Alternatives

- **Selecting the Mac Mini as exit node on the host's main `tailscaled`.** This
  routes all host traffic through Australia. Rejected.
- **Policy routing (`ip rule`, nftables cgroup marks) on the main node.** This
  fights Tailscale's own routing-table rules, and the dynamic UID prevents
  owner matching. Rejected as fragile.
- **A forward proxy (tinyproxy) on the Mac Mini.** It needs no per-host login
  and resolves DNS at the Mac. But it adds a hand-supervised macOS daemon, and
  the host's main tailnet node would carry Underclass traffic. Not selected.
- **A network namespace for Underclass with a kernel-mode Tailscale node.** This
  needs privileged namespace setup, TUN and routing inside it. Not selected; the
  userspace node with cgroup IP filtering gives the same confinement with no
  host routing changes.
- **Gating on exit-node liveness.** This would make an offline Mac stop
  Underclass and fail deployments. Rejected: requests already fail closed.

## Consequences

Underclass provider traffic appears to come from the Mac Mini's Australian
connection, and provider DNS answers come from there too. Every host's pool now
depends on one home machine and its internet connection. Mac sleep, macOS
update reboots and ISP outages make all Underclass provider requests fail on
both hosts at once. The existing proxy-completion objective reports this as
Underclass failure. Latency rises by the round trip to Australia, plus DERP
relay time when no direct path exists.

Each host gains a second tailnet node identity (`<host>-underclass-egress`) to
approve, expire and audit. Tailnet policy must allow that node to use the exit
node (`autogroup:internet`). Root on the host can still clear the exit-node
preference through the egress socket. Underclass's proxied traffic then
leaves directly until the next Underclass start re-asserts it. This is
treated as an operator action, not an isolation boundary.

Rollback deletes the `exitNode` setting: Underclass returns to direct egress
on the next activation, and the egress node can stay logged in.

## Invariants and verification

- Without `egress.enable`, there is no egress unit, proxy environment or IP
  filter. With only `egress.enable`, Underclass's environment and filters are
  unchanged.
- The egress node creates no TUN device or routing rules. Its proxy listens only
  on `127.0.0.1`. Its unit has no capabilities and no `AF_INET6`.
- With `exitNode` set, Underclass does not start before the egress node is
  logged in with that exit node selected, and every start re-asserts a cleared
  preference.
- The Underclass cgroup cannot reach a non-loopback address directly. Through
  the proxy, it reaches the internet with the exit node's source address, and
  names are resolved at the exit node.
- Stopping the exit node makes proxied requests fail. The destination never
  sees the host's own address. Underclass still restarts while the exit node is
  offline.
- Egress node state survives a host reboot.

The [configuration check](../../../nix/verification/tests/evaluation/underclass.nix)
covers the opt-in stages and the unit wiring. The
[machine check](../../../nix/verification/tests/machines/underclass-egress/default.nix)
covers the runtime properties above, using a private headscale tailnet and a
kernel exit node.

## Implementation evidence

The [NixOS module](../../../nix/domains/system/underclass.nix) implements the
egress node, the wrapper command, the proxy environment, the cgroup IP filter
and the start gate. The [auto-updater](../../../nix/domains/system/auto-update/default.nix)
adds `underclass-egress.service` to activation consumers and health units. The
[enrolled host profile](../../../nix/platform/hosts/profile.nix) enables stage 1,
and a separate later change selects `mac-mini` for stage 2;
the [enrollment check](../../../nix/verification/tests/evaluation/enrollment-configuration.nix)
asserts the selected stage.

On 2026-10-17, from base `5910bdd79` plus this change:

- `underclass-configuration` passed all 11 cases.
- `underclass-egress` passed all 11 subtests (test script finished in 87.71 s).

The [review](../reviews/2026-10-17-underclass-tailnet-egress.md) records these
runs and their scope.

Implementation remains partial. Live login of both egress nodes, tailnet policy
for the new identities, stage-2 activation and a provider request observed from
the Mac Mini's address have not happened. The machine check uses headscale and a
Linux exit node, not the production Tailscale control plane or a macOS exit node.

## Open questions

Decide whether the egress node identities should be tagged and given key expiry
exemptions. Measure provider latency and throttling from the Australian address
before relying on it. Decide whether an offline Mac Mini needs its own alert
separate from Underclass proxy completion. Consider a periodic preference check
if the root-operator window above becomes a concern.

## Related decisions

[ADR-0260](0260-underclass-egress-without-exit-node.md) amends stage 2: the
enrolled profile keeps routing through the egress node with no exit node, after
`mac-mini` went offline on 2026-10-28.
[ADR-0245](0245-underclass-egress-node-tag.md) tags the egress node
`tag:underclass`.
[ADR-0102](0102-local-underclass-monitor-socket.md) keeps the independent pools,
loopback listener and tailnet-only publication that this decision preserves.
[ADR-0075](0075-fleet-overlay-and-source-access.md) defines the tailnet as the
fleet's management overlay. [ADR-0036](0036-automatic-host-updates.md) defines
update health. [ADR-0033](0033-nixos-machine-verification.md) defines local
verification claim boundaries.
