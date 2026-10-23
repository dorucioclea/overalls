{ pkgs, elixir }:
let
  inherit (pkgs) lib;
  verifier = ./verify.ex;
  protocolSource = lib.fileset.toSource {
    root = ../../../../../protocol;
    fileset = lib.fileset.unions [
      ../../../../../protocol/lib/overalls_protocol/editor_release.ex
      ../../../../../protocol/lib/overalls_protocol/guest_agents.ex
      ../../../../../protocol/lib/overalls_protocol/image_manifest.ex
      ../../../../../protocol/lib/overalls_protocol/native_admission.ex
      ../../../../../protocol/priv/native
    ];
  };
  protocol = "${protocolSource}/lib/overalls_protocol";
  digest = value: builtins.isString value && builtins.match "[0-9a-f]{64}" value != null;
  compileVerifier = ''
    export ERL_FLAGS="+S 2:2"
    mkdir "$TMPDIR/verification-beams"
    elixirc --warnings-as-errors -o "$TMPDIR/verification-beams" \
      ${protocol}/editor_release.ex ${protocol}/guest_agents.ex \
      ${protocol}/image_manifest.ex ${protocol}/native_admission.ex ${verifier}
  '';
in
{
  checks = pkgs.runCommand "overalls-native-image-promotion-checks" {
    nativeBuildInputs = [ elixir ];
  } ''
    set -euo pipefail
    ${compileVerifier}
    elixir -pa "$TMPDIR/verification-beams" ${./test_verify.exs}
    touch "$out"
  '';

  # @cc [owner:ghuntley,label:build;deployment] native-published-candidate-fixed-output
  # The published input MUST be a recursive fixed-output store path. Ordinary
  # signature-verified substitution supplies it; the fallback MUST only refuse.
  publishedCandidate = { name, narHash }:
    assert lib.types.str.check name && builtins.match "overalls-native-[a-z0-9-]+" name != null;
    assert lib.types.str.check narHash && builtins.match "sha256-[A-Za-z0-9+/]{43}=" narHash != null;
    pkgs.runCommand name {
      outputHash = narHash;
      outputHashMode = "recursive";
      preferLocalBuild = true;
    } ''
      cat >&2 <<'PUBLICATION'
        The reviewed native candidate ${name} is absent from the signed Overalls cache.
        Publish the sealed directory using its reviewed recursive NAR hash:
          nix store add-path --name ${name} <sealed-directory>
        Verify the returned store path's NAR hash before publishing that exact
        path through the existing Overalls Cachix publisher. Do not rebuild or
        substitute a stock image. The candidate directory contains disk.raw and firmware.
      PUBLICATION
      exit 1
    '';

  # @cc [owner:ghuntley,label:security;deployment] native-retained-promotion-fixed-output
  # A promotion whose sealed candidate is no longer substitutable MAY be kept
  # only as the exact output its original verify_approved! build produced,
  # pinned by recursive NAR hash and substituted from the signed cache. The
  # fallback MUST only refuse; it MUST NOT verify or emit any other bytes.
  retained = { imageName, narHash, approval }:
    assert lib.types.str.check imageName && builtins.match "lilly-[a-z0-9_-]+-promoted" imageName != null;
    assert lib.types.str.check narHash && builtins.match "sha256-[A-Za-z0-9+/]{43}=" narHash != null;
    assert approval.version == 1;
    assert builtins.elem approval.manifest.os [ "freebsd" "illumos" ];
    assert lib.types.str.check approval.image_id && builtins.match "sha256:[0-9a-f]{64}" approval.image_id != null;
    pkgs.runCommand imageName {
      outputHash = narHash;
      outputHashMode = "recursive";
      preferLocalBuild = true;
      passthru = {
        os = approval.manifest.os;
        imageId = approval.image_id;
        nativeAdmission = true;
        imageAssemblyReady = true;
        runtimeValidated = true;
      };
    } ''
      cat >&2 <<'PUBLICATION'
        The retained promoted image ${imageName} is absent from the signed Overalls cache.
        Add the exact output of its original promotion build:
          nix store add-path --name ${imageName} <original-promoted-output>
        and verify the returned NAR hash before the Cachix publisher uploads it.
        Do not rebuild, re-promote or substitute a different image.
      PUBLICATION
      exit 1
    '';

  # @cc [owner:ghuntley,label:security;build] native-promoted-image-closed-output
  # Only explicitly reviewed approval data may select an admitted package. Its
  # build MUST verify exact artifacts and evidence before emitting the closed
  # firmware/disk.raw/manifest.json image directory; no test hook is installed.
  promote = { imageName, candidate, approval }:
    assert lib.isDerivation candidate;
    assert lib.types.attrs.check approval;
    assert approval.version == 1;
    assert builtins.elem approval.manifest.os [ "freebsd" "illumos" ];
    assert approval.manifest.version == 6;
    assert lib.types.str.check approval.image_id && builtins.match "sha256:[0-9a-f]{64}" approval.image_id != null;
    assert digest approval.vmm_sha256;
    let
      approvalFile = pkgs.writeText "${imageName}-approval.json" (builtins.toJSON approval);
    in
    pkgs.runCommand imageName {
      nativeBuildInputs = [ pkgs.coreutils elixir ];
      passthru = {
        inherit approvalFile candidate;
        os = approval.manifest.os;
        imageId = approval.image_id;
        nativeAdmission = true;
        imageAssemblyReady = true;
        runtimeValidated = true;
      };
    } ''
      set -euo pipefail
      mkdir "$out"
      cp --dereference --sparse=always ${candidate}/disk.raw "$out/disk.raw"
      cp --dereference ${candidate}/firmware "$out/firmware"
      ${compileVerifier}
      elixir -pa "$TMPDIR/verification-beams" -e \
        '[approval, output] = System.argv(); :ok = Overalls.NativeImagePromotion.verify_approved!(approval, output)' \
        ${approvalFile} "$out"
    '';
}
