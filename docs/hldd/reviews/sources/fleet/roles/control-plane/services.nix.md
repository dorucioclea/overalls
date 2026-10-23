---
digest: a4b2a70bd237dc2dd7cf43610289b0bee4a6b1b27330cbe751869ec0788dcfa6
disposition: updated
kind: source
mapping_digest: 05e1761038133f69f40af77d180940fa94168af5fea92478049f84f74b8e9d48
path: fleet/roles/control-plane/services.nix
reviewed_chapters:
  marshall/priv/hldd/07-guests.md: 075e5b7b4bc10c66bc2498efded4eace86bbb0c3427337e20bcfe407c3a728be
  marshall/priv/hldd/12-configuration.md: 5318d494cf8479636aa2e2c3c61cb5505cb4cb8386e39b935cf62c62b997169f
  marshall/priv/hldd/13-deployment.md: 0bc4fe19bb9cdf60d5edc24c3777c7f54b170426d9ae5d1f611a2240053c3350
  marshall/priv/hldd/14-operations.md: 68c72d0e6fde22edd5d892f824dedd44f1843d68ece6c96ff5b3e2c1e50051c9
  marshall/priv/hldd/15-monitoring.md: 47cae9cafce18ef57d278be5b04ce1dce3799f6583aa1a5bfa8ff80babbf1a99
  marshall/priv/hldd/16-recovery.md: 194fe77196ac4a25ab764d5cf4aee7558da547cd7b59726f32a302019b26136c
  marshall/priv/hldd/17-reference.md: 9b7c3c0ba2c93d62cda3b8c5b3914af2ebbab0f7f9c1e6345bdb926d15c8e8cb
  marshall/priv/hldd/18-options.md: aa4a6b24dd1fac9b6d2eb6657444423d5a530f3bd5a8e3ef21db1e6b95671dc0
  marshall/priv/hldd/19-coverage.md: eec1a8133a836361d14be300a11c987603986208eafcb1cf9930c9fbc0e8d91a
  marshall/priv/hldd/20-security.md: 23fdebc69e8bdbe970942ca43234274500c4f4382f074a590e9238b1762939af
  marshall/priv/hldd/21-domains.md: 64cf0af44004d07c4e5c3402225bb22e5f4f29ae1e8a15b5c7690de8b769efb7
  marshall/priv/hldd/22-topology.md: b66172c618dc03b360046d5e1a6f2850265e5eb7acbe02e20c068a0efdf1569f
state: present
version: 2
---

Hosts set system.configurationRevision; the spool config carries the build revision; a dedicated collector pipeline exports one overalls_deployment_info series per host and guest traces gain overalls.host.deployment.revision; operations dashboard adds deployed revision, deployment annotations, pool waiting-callers and failed-query panels (25 panels) and Marshall pages adds a failed-callback reason table (14 panels); production poolSize 20; machine tests assert the inventory and series (15-monitoring).
