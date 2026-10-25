{ lib, checks }:
let
  # @cc [owner:ghuntley,label:verification] ci-check-selection
  # Every exported check MUST carry `meta.ci` so GitHub Actions derives its
  # matrices by evaluation rather than a hand-maintained list. A check is
  # excluded from CI only by name here, never by omission from the catalog.
  excluded = [
  ];

  # Checks that run NixOS machine tests without being one themselves.
  machineAggregates = [ "host-conversion" ];

  # @cc [owner:ghuntley,label:verification] ci-lazy-required-features
  # Feature discovery MUST preserve enabled NixOS tester requirements, including
  # nested-kvm, without forcing a lazy driver's derivation or guest-image build.
  # The tester exposes requirements through config instead of its lazy wrapper.
  features = check:
    if check ? requiredSystemFeatures then check.requiredSystemFeatures
    else if check ? config && builtins.isAttrs check.config then
      lib.attrNames (lib.filterAttrs (_: enabled: enabled) (check.config.requiredFeatures or { }))
    else [ ];

  ciMeta = name: check: {
    enable = !(builtins.elem name excluded);
    machine = check ? driver || builtins.elem "kvm" (features check)
      || builtins.elem name machineAggregates;
    nestedKvm = builtins.elem "nested-kvm" (features check);
  };
in
lib.mapAttrs (name: check:
  check // { meta = (check.meta or { }) // { ci = ciMeta name check; }; }
) checks
