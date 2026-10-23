{ pkgs, elixir }:
let
  promotion = import ./. { inherit pkgs elixir; };
  candidate = promotion.publishedCandidate {
    name = "overalls-native-omnios-r151050-a96f291b";
    narHash = "sha256-JtShi7noaG35U4pUfUKVKQtNwOLna9acXFSi1lOOxTo=";
  };
  receipt = relative: sha256: { path = "${candidate}/evidence/${relative}"; inherit sha256; };
  approval = {
    version = 1;
    image_id = "sha256:6dc1a0840e50e508c964c2890e805c919b78c2cddb3e1e8e9d379e001c28617d";
    manifest = builtins.fromJSON (builtins.readFile ../../../../../protocol/priv/native/omnios-r151050-a96f291b.json);
    vmm_sha256 = "9815649a9bed84194ca45c5aef4c9307a596c7ffbe1f9f0e881c1ae536226d02";
    assembly = receipt "assembly.json" "3bb1dada687994082250cb82dfb47a4e4bdad9e511ed9a48200c6a9aa441d1e8";
    scenarios = [
      {
        name = "services";
        service = receipt "services.json" "0710bf88266bbce4135889dcf644a5f5fdeec128cc67b75825e7c50614bb50bf";
        supporting = [];
      }
      {
        name = "growth";
        service = receipt "growth-services.json" "9d330d31094ff2bb747265e04e31d31163e020765e9a07d75cb0c96970173a48";
        supporting = [ (receipt "growth.json" "32c4e70565e67d4cfec852eec254e06ea0f0683661edf85d3f8e30d91ac9412d") ];
      }
      {
        name = "isolation";
        service = receipt "isolation-services.json" "c8c6bff93be2caf9bac3171377e4975cac55f744783bef3ddced5e6c44f98f41";
        supporting = [
          (receipt "isolation/isolation-62e33ea9-73d9-4427-9764-f3dd0ddc7071.json" "35a1ea91e252b846984304ee5f77ee58c1858ac413a0008f33100f4403481b29")
          (receipt "isolation/isolation-c0c709bb-15e0-4aa5-83ad-acb5333e463c.json" "6b4b0e4cfa23f2000c6b67cdc4c941a9cc2f9c13b3ada3313b17bbb4f68d9479")
        ];
      }
      {
        name = "recovery";
        service = receipt "recovery-services.json" "4faef82a37dcc4972bae67b2b9afdad683e4573d32dc4c16ba6d03c2507f707b";
        supporting = [
          (receipt "recovery/recovery-90861232-abd6-4bcf-a0d7-a4e502396066.json" "5e542b77381f0627b2974e6f8197ff6eabb48df65c2f436543e5cbda2929e001")
          (receipt "recovery/recovery-f7287da5-c1f3-4596-bada-0d62e77f6bb4.json" "0d88a33105e2b5b2d6a36c83b0c684c4aa0806a97b8cd132c23bd35c8b36a5c4")
        ];
      }
      {
        name = "crash-recovery";
        service = receipt "crash-services.json" "7463109b25bad312e655247bc57b87820ae9e47796a72e88708cda18c8789a9f";
        supporting = [ (receipt "crash.json" "c52ede7300e6050da5e07fd070f8911d8f999d6f164e09ea65fc3a6791798b8c") ];
      }
    ];
  };
in
promotion.promote {
  imageName = "lilly-omnios-r151050-x86_64-a96f291b-promoted";
  inherit candidate approval;
}
