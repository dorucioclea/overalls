---
digest: 17cfb6da906b11027bdba18fe55e2a28fce248e8b32b351eb8261c0712541698
disposition: no-impact
kind: source
mapping_digest: f5fc9d76317e24062e0e2b16713ab5e149eff5538f68346d30e34292f21dbae4
path: lyra/src/telemetry.rs
reviewed_chapters:
  marshall/priv/hldd/08-interactive.md: 3b2f40d7d3004923a6bfaa3b6b27287b36731de73182032b29a392be6daf8c0a
  marshall/priv/hldd/09-network.md: 225196b393bb0b27d8bdc3bac0a787b869f7d22e9d48ed72dc67ccec6d9ae79b
  marshall/priv/hldd/10-services.md: 4781fd8156d5372fe680254a665a2af19d11deba4fc73fe010fe04aaef057556
  marshall/priv/hldd/11-agents.md: 7d24214acefb26fbd3b08ce582578fd007e6ffa4bd55d986293050de8605356d
  marshall/priv/hldd/17-reference.md: 9b7c3c0ba2c93d62cda3b8c5b3914af2ebbab0f7f9c1e6345bdb926d15c8e8cb
  marshall/priv/hldd/19-coverage.md: eec1a8133a836361d14be300a11c987603986208eafcb1cf9930c9fbc0e8d91a
  marshall/priv/hldd/20-security.md: 23fdebc69e8bdbe970942ca43234274500c4f4382f074a590e9238b1762939af
  marshall/priv/hldd/21-domains.md: 64cf0af44004d07c4e5c3402225bb22e5f4f29ae1e8a15b5c7690de8b769efb7
  marshall/priv/hldd/22-topology.md: b66172c618dc03b360046d5e1a6f2850265e5eb7acbe02e20c068a0efdf1569f
state: present
version: 2
---

Reviewed 08-11, 17 and 19-22: Lyra still emits fixed counters, duration and an identity-free fixed-name span after terminal acknowledgment (20-security row); adding the constant crate version as service.version adds no identity or payload, and the guest revision split is documented in 15-monitoring.
