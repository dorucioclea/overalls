# Underclass egress without an exit node review (2026-10-28)

## Scope

This review covers the change that implements
[ADR-0260](../decisions/0260-underclass-egress-without-exit-node.md). The change
keeps Underclass behind the dedicated egress node's proxy and loopback
confinement, but removes the `mac-mini` exit node. It also bumps the Underclass
pin from `c58a972` to `d7a0ccf`. The base is `origin/trunk` at `295f026cf`.
Changed areas:

- `services.underclass.egress.route` and the two start-gate variants in
  `nix/domains/system/underclass.nix`;
- the enrolled profile in `nix/platform/hosts/profile.nix`;
- the `underclass-configuration` and `enrollment-configuration` evaluation
  checks;
- a new route-only subtest in the `underclass-egress` machine check;
- the package pin in `nix/domains/artifacts/underclass/default.nix`.

The review dimensions are isolation, network transport, deployment health and
recovery.

## Findings

1. **A stale preference outlived the dead exit node (high, resolved).** On
   Panterloons, `mac-mini` was offline for two days, and all provider traffic
   failed closed as ADR-0185 intended. Clearing the preference by hand was
   undone at 07:32 UTC, when the automatic update restarted Underclass and the
   gate re-selected `mac-mini`. In route-only mode the gate now clears any stored
   preference and refuses to start if one remains. The machine subtest starts
   from a stored preference that names an offline exit node.
2. **`exitNode = null` used to drop the confinement (medium, resolved).** Before
   this change, the only way to stop using the exit node was to also remove the
   proxy environment, the IP filter and the gate. `route` now controls those
   separately. Its default, `exitNode != null`, keeps existing configurations
   evaluating the same way, and the configuration check asserts both defaults.
3. **Source address change (accepted).** Provider traffic now leaves from each
   host's own address. The user requested this explicitly.
4. **Pin bump (low).** `d7a0ccf` adds a manual token-refresh admin endpoint and
   CLI (upstream ADR 0026). The instrumentation patch applies with offsets. The
   Cargo lock is unchanged, so the vendor hash is unchanged.

## Verification

From base `295f026cf` plus this change, on 2026-10-28:

- `nix build .#tool-underclass` built `underclass-0.1.0-d7a0ccf`, and its
  `underclass refresh --help` lists the new command.
- `underclass-configuration` passed, including `egressRoutedDirect` and
  `exitNodeRequiresRoute`.
- `underclass-egress` passed all 12 subtests, including "routing without an
  exit node clears a stale one and leaves directly"; the test script finished in
  108.33 s.

Not verified: activation on the production hosts, and a live provider request
through the egress node there.
