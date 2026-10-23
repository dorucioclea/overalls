---
digest: e3c43ebe3d2b1aeb62caf3c069b576edf957175d0721e4083a5b5eee15077250
disposition: no-impact
kind: source
mapping_digest: 2272062390f820f27790d68b944163b5a8c4aa097bb58fe18257524d8b10bbd0
path: antithesis/nix/recorder-host.nix
reviewed_chapters:
  marshall/priv/hldd/01-system.md: e746f0ac6783bb5037c9fd2785c8d8b6aee0f5b279cd263d673ad95462566aa2
  marshall/priv/hldd/17-reference.md: 9b7c3c0ba2c93d62cda3b8c5b3914af2ebbab0f7f9c1e6345bdb926d15c8e8cb
  marshall/priv/hldd/21-domains.md: 64cf0af44004d07c4e5c3402225bb22e5f4f29ae1e8a15b5c7690de8b769efb7
  marshall/priv/hldd/22-topology.md: b66172c618dc03b360046d5e1a6f2850265e5eb7acbe02e20c068a0efdf1569f
state: present
version: 2
---

Reviewed 01-system, 17-reference, 21-domains and 22-topology: they describe spool custody, roles and metric recorder service names, not trace resource attributes; the new service.version/overalls.deployment.revision resource, revision validation and closed LiveView reason vocabulary are documented in 15-monitoring trace intake and signal table, and the Antithesis fixture only supplies the now-required field.
