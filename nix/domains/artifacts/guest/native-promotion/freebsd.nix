{ pkgs, elixir }:
let
  promotion = import ./. { inherit pkgs elixir; };
  candidate = promotion.publishedCandidate {
    name = "overalls-native-freebsd-14-3-5022d714";
    narHash = "sha256-jnULElxnAk9yzcohR6SPgdr8AprHiv1Oa9OTU6Va06E=";
  };
  receipt = relative: sha256: { path = "${candidate}/evidence/${relative}"; inherit sha256; };
  approval = {
    version = 1;
    image_id = "sha256:d141e4266c29da00a1378157b1d39369b1d48e577bca4ce7375e8ff6d399557b";
    manifest = builtins.fromJSON (builtins.readFile ../../../../../protocol/priv/native/freebsd-14.3.json);
    vmm_sha256 = "5dc9a44417e758c94fd70cb78113bd55f04f3d9170307215a9ff2e88aabd6c90";
    assembly = receipt "assembly.json" "18a9477c6dee89df68152b35b8bb67810531038d29943e9d0f50bb3b316a97d2";
    scenarios = [
      {
        name = "services";
        service = receipt "services.json" "b714d79e5aec0fc3ce639a6f1bb241d5b785ab12f6c2dc290f3e5c1006ebe390";
        supporting = [];
      }
      {
        name = "growth";
        service = receipt "growth-services.json" "5aa9eabcd08efa25724a76a07f574f5998fd2b00bcf1be005081cf615c8de214";
        supporting = [ (receipt "growth.json" "a4386a4c33030f1cff8b95dc9d977bcf98a682970e7ee82de5a04e6b6f0bb259") ];
      }
      {
        name = "isolation";
        service = receipt "isolation-services.json" "c32f620bcdc57f4385c62d771029aadc85d2b2d80295d3a2b28d59ad280ce9db";
        supporting = [
          (receipt "isolation/isolation-31e39d24-4da7-4431-bceb-2b8fc0992f25.json" "1879bf42c298a6fa6a84b1dd1279c7c5b7e62f417bcaf94ade9850a5c1c035e5")
          (receipt "isolation/isolation-771a6499-93c1-4ffa-be2a-01288508f9cb.json" "5ebc66b7b1d64a43840e4e0a5907499008d01a385f34d3cfc1055e1f871d97bd")
        ];
      }
      {
        name = "recovery";
        service = receipt "recovery-services.json" "a3f5f3f84914f2f741cda2a2ded4247daa874a802b0b8f25f2c9bdce9d5871ec";
        supporting = [
          (receipt "recovery/recovery-69a96baf-83f1-4aec-a9ad-bb7860b98838.json" "ea801e2bb165dc6b4245f240f4a62897bce7ea5a439ee278656bb62cc4487bc7")
          (receipt "recovery/recovery-d175d17e-3fc8-4f6a-812d-4379dec75bf4.json" "76998d209b04c1e904e285af1af2e1cd78a2fcc95fbb4552d81150fe51dc4f7a")
        ];
      }
      {
        name = "crash-recovery";
        service = receipt "crash-services.json" "192fc7a02adddcb24b745d4bfc17caccba1eda77c91b7294e503b4b51e36ff5d";
        supporting = [ (receipt "crash.json" "3518518e3e3396f543a93ee51cecfa20d1a62f09209fec11740eef9ea9c6a1cb") ];
      }
    ];
  };
in
# The sealed candidate above is no longer substitutable, so this keeps the
# exact output of its original verified promotion build. The candidate and
# receipts remain the review record of that verification.
promotion.retained {
  imageName = "lilly-freebsd-14_3-x86_64-promoted";
  narHash = "sha256-wcEv0jqRuJRZHRuTDi1IRQQhvQ+2NVOxVoHLFMaDl5Q=";
  inherit approval;
}
