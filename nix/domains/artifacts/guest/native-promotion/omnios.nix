{ pkgs, elixir }:
let
  promotion = import ./. { inherit pkgs elixir; };
  candidate = promotion.publishedCandidate {
    name = "overalls-native-omnios-r151050-45983bb7";
    narHash = "sha256-JrTq1siY+meAVhpqYBdddLVgs+eagD79taqn+wZivsU=";
  };
  receipt = relative: sha256: { path = "${candidate}/evidence/${relative}"; inherit sha256; };
  approval = {
    version = 1;
    image_id = "sha256:98b23b7931bc52d55b3c5b38cc20c97c1c967be96cf301940f88b01c715530d8";
    manifest = builtins.fromJSON (builtins.readFile ../../../../../protocol/priv/native/omnios-r151050.json);
    vmm_sha256 = "ba91e85a7af3f96d02f845df543daec07353ed6bff4aaee0abf524c751476b68";
    assembly = receipt "assembly.json" "aaf9aeeee25b73c6454a395b69b78eb4a207b59dcbcd363b088e8839592edb04";
    scenarios = [
      {
        name = "services";
        service = receipt "services.json" "b8fc867e0d1e5484c05da231bb5012ae00411937320ae91e0764be296efb30de";
        supporting = [];
      }
      {
        name = "growth";
        service = receipt "growth-services.json" "20a80022f74c77b5dd466a38b568eae78ca20e2da4c2c8314c741939d2dc8327";
        supporting = [ (receipt "growth.json" "9bf6e81ed15487c1a59b1bbb8a906bb8e0c2e5c24657f721601842e4dfda7687") ];
      }
      {
        name = "isolation";
        service = receipt "isolation-services.json" "a3989f659d994c8284d972f2978efabd38f66dc08aa5eb1bcb0365e35e0f951f";
        supporting = [
          (receipt "isolation/isolation-b4ae488c-b347-46d9-8da1-7fa5805a6213.json" "00ab191de3bc01409fb103a4c141747a846f51f3da834270713226f99268eb6e")
          (receipt "isolation/isolation-4371bb38-3fd7-496b-849b-f0934fd4988a.json" "755364ad7dcc22b6e9a1d1d64e9e8b1fbcf7ad691c82db58a8eb1d1f31acaabc")
        ];
      }
      {
        name = "recovery";
        service = receipt "recovery-services.json" "76548d39bdb7d9d56fd358e782a30ef0893275ce6e5f64171cc6ef361db552a6";
        supporting = [
          (receipt "recovery/recovery-043f6e73-81dd-47cc-8eba-f8664def6393.json" "6698a0518bd357d538acff8afc8c2cf1b7b0e9d228338284748ab1bea7471ae0")
          (receipt "recovery/recovery-c7eb6d84-4770-4d9f-9d7b-bebea48e371f.json" "7f9516da1d503863bc5b9a2e8a4a7fa5449ba2ccb347273f501249ab784ba85f")
        ];
      }
      {
        name = "crash-recovery";
        service = receipt "crash-services.json" "567b7f86af09518d27358f97757acc55f5a4b273dce1da8e4fcf93de2b46ad8f";
        supporting = [ (receipt "crash.json" "107c94080ab189c2a718e1fbe38dd7dda9c778b933c14e9ac8f15e335796a483") ];
      }
    ];
  };
in
# The sealed candidate above is no longer substitutable, so this keeps the
# exact output of its original verified promotion build. The candidate and
# receipts remain the review record of that verification.
promotion.retained {
  imageName = "lilly-omnios-r151050-x86_64-promoted";
  narHash = "sha256-qKv00aAEuM+ObUg2GpzEvepykgDpn3EE9aoG3EKWAhs=";
  inherit approval;
}
