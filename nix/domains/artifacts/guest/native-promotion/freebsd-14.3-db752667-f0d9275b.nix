{ pkgs, elixir }:
let
  promotion = import ./. { inherit pkgs elixir; };
  candidate = promotion.publishedCandidate {
    name = "overalls-native-freebsd-14-3-db752667-f0d9275b";
    narHash = "sha256-Kp+Yf4qE/ewDYSM15H7dLkvpYSU8GftQHOgpzBzhckg=";
  };
  receipt = relative: sha256: { path = "${candidate}/evidence/${relative}"; inherit sha256; };
  approval = {
    version = 1;
    image_id = "sha256:0150b6d1aee0b30892b937eb0566a3dcebf2c5ca4cec75f7a252bd9ae00beac6";
    manifest = builtins.fromJSON (builtins.readFile ../../../../../protocol/priv/native/freebsd-14.3-db752667.json);
    vmm_sha256 = "f0d9275b2dcf2e788a1a643722622950402a5c8fe6d442b294f1306a5e0e9fd9";
    assembly = receipt "assembly.json" "a39b77325abf9507284e4dffdbf520af89f69ad09b713ea3a5b8d990c7ee9029";
    scenarios = [
      {
        name = "services";
        service = receipt "services-services.json" "1701321213e53edef9eac82fa74996a89ab25909745d96bf4853a97f2ade19c0";
        supporting = [
        ];
      }
      {
        name = "growth";
        service = receipt "growth-services.json" "2abca69240a6cc7a19cd60432c9ae410856d04e511e256ec108b4782a9b6ad10";
        supporting = [
          (receipt "growth/growth-receipt.json" "19d276625e53564791cfe25def018790ba2fa3815e089d36253b8e6caf489ab9")
        ];
      }
      {
        name = "isolation";
        service = receipt "isolation-services.json" "083283dedc56760c3a47483a197f12f60d1e194cbaec67192075fe010f8a698a";
        supporting = [
          (receipt "isolation/isolation-45bfc798-085e-4a6a-ac89-e7fb68b12d84.json" "dea603c2cb3d24e02011716a1ff065192261a0f762da7bb70e5a73066b1b2c99")
          (receipt "isolation/isolation-da891b2d-b617-416f-ad76-a5ee432db7a8.json" "afe0ca6105ee278ae5e06d9c3b4992af8d01e1ce872a2573974c37f73faa03c9")
        ];
      }
      {
        name = "recovery";
        service = receipt "recovery-services.json" "576a79638bef8952f98ce08a68e54a3c79db36f8b4280f46737e3c952970f14d";
        supporting = [
          (receipt "recovery/recovery-ecfa1176-1543-45d4-bcec-2e42fc1037b5.json" "958bcd1165143396a831bc7b3366a74834366971d9bbd8a667d536641cabf194")
          (receipt "recovery/recovery-f4374db9-c0ec-44ec-a701-2ca90b4ead04.json" "e65eb7602ee8f85c090fc20b75fdd4353cc8e326c9f5e5fac8d531a7531b8767")
        ];
      }
      {
        name = "crash-recovery";
        service = receipt "crash-recovery-services.json" "f92e553e901a773edad48183159433b6e61761be6fe7f7a6a04f32a946b3a32f";
        supporting = [
          (receipt "crash-recovery/crash-recovery-receipt.json" "8eace6ffe675228ca1acd625a795caf1935ffcac532bac0f4caee1b33dcdc125")
        ];
      }
    ];
  };
in
# The sealed candidate above is no longer substitutable, so this keeps the
# exact output of its original verified promotion build. The candidate and
# receipts remain the review record of that verification.
promotion.retained {
  imageName = "lilly-freebsd-14_3-x86_64-db752667-f0d9275b-promoted";
  narHash = "sha256-1yb/GR2tb9luP+mHPHMp/K66QFG+mrIuzQBrm3Bo7jQ=";
  inherit approval;
}
