# ADR-0260: Underclass egress proxy without an exit node

- ID: ADR-0260
- Date: 2026-10-28
- Status: accepted
- Implementation: partial
- Components: NixOS services, Underclass, Tailscale, fleet networking
- Supersedes: none
- Superseded by: none

## Context

[ADR-0185](0185-underclass-tailnet-exit-egress.md) sends Underclass provider
traffic through a dedicated userspace tailnet node and the Australian `mac-mini`
exit node. The Underclass unit is confined to loopback, and a start gate
re-selects the exit node on every start.

Observed on Panterloons on 2026-10-28:

- `mac-mini` had been offline for two days. Every Codex request and every
  scheduled token rotation failed with a network error. As ADR-0185 intended,
  traffic failed closed rather than leaking.
- Clearing the preference by hand
  (`underclass-egress set --exit-node=`) restored provider traffic straight
  away, still through the egress node's proxy.
- The next automatic update (system generation 265, 07:32 UTC) restarted
  Underclass. The start gate re-selected `mac-mini`, and the outage resumed.
- In the module, `exitNode = null` also removes the proxy, the loopback
  confinement and the gate. So there was no configuration that kept the egress
  node wrapper without an exit node.

## Decision

The user's 2026-10-28 instruction ("remove mac-mini as egress (but keep
tailscale wrapper of underclass!)") authorizes this decision. It amends
ADR-0185 stage 2:

- `services.underclass.egress.route` is a separate option. Its default is
  `exitNode != null`, so existing configurations keep their meaning. Routing
  gives Underclass the proxy environment, the `IPAddressDeny=any` /
  `IPAddressAllow=localhost` confinement, the egress unit dependency and the
  privileged start gate, whether or not an exit node is set.
- Setting `exitNode` requires `route`.
- With `exitNode` set, the gate is unchanged from ADR-0185.
- With `route` and no `exitNode`, the gate clears any stored exit-node
  preference on every start. It refuses to start while the egress node is
  logged out or still reports an exit node. So a preference left over from an
  earlier configuration cannot keep traffic pointed at a dead exit node.
- The enrolled host profile sets `egress = { enable = true; route = true; }`.
  Provider traffic still passes only through the egress node's proxy, but
  leaves from each host's own address.

## Alternatives

- **Set `exitNode = null` with the existing module.** This drops the proxy and
  the loopback confinement, which the user explicitly asked to keep. Rejected.
- **Pick another exit node (for example `panterloons` or `dungarees`).** No
  Australian alternative exists, and a fleet host as exit node routes one
  host's provider traffic through another for no benefit. Not selected.
- **Gate on exit-node liveness and fall back to direct.** This turns an outage
  into a silent change of source address, which ADR-0185 rejected as a leak.
  Rejected.

## Consequences

Provider traffic now comes from each host's Hetzner address again. The
dependency on the Mac Mini and its home connection goes away, and so does the
Australian source address and DNS view. The egress node, its tag, its login
requirement and the loopback confinement all remain. Re-enabling an exit node
later means setting `exitNode` again, with no other module changes.

The egress node must still be logged in, or Underclass refuses to start, as in
ADR-0185.

## Invariants and verification

- With `route` false and no `exitNode`, Underclass has no proxy environment, no
  IP filter and no gate, as in ADR-0185 stage 1.
- With `route` set, the Underclass cgroup cannot reach a non-loopback address
  directly, and the gate runs before every start, with or without an exit node.
- With `route` set and no `exitNode`, each start clears a stale exit-node
  preference. Proxied traffic then reaches the internet with the host's own
  source address.
- `exitNode` without `route` fails evaluation.

The [configuration check](../../../nix/verification/tests/evaluation/underclass.nix)
covers the option wiring, the defaults and the new assertion. The
[machine check](../../../nix/verification/tests/machines/underclass-egress/default.nix)
switches a host to a route-only specialisation while its stored preference
still names an offline exit node. It then verifies that the preference is
cleared, the unit stays confined to the proxy, and the source seen upstream is
the host's address.

## Implementation evidence

The [NixOS module](../../../nix/domains/system/underclass.nix) adds `route` and
the two gate variants. The [enrolled host profile](../../../nix/platform/hosts/profile.nix)
selects routing without an exit node, and the
[enrollment check](../../../nix/verification/tests/evaluation/enrollment-configuration.nix)
asserts it.

Implementation remains partial until the change is activated on both hosts and
a provider request is observed succeeding through the egress node there.

## Open questions

None.

## Related decisions

Amends [ADR-0185](0185-underclass-tailnet-exit-egress.md) stage 2.
[ADR-0245](0245-underclass-egress-node-tag.md) tags the egress node, unchanged.
[ADR-0036](0036-automatic-host-updates.md) defines the update health that made
the exit-node gate re-apply on 2026-10-28.
