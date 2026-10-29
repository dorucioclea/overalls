---
digest: 325bbd8d34f5250e35f685cd331d7c434ee04b6e20161924019f693148026265
disposition: updated
kind: source
mapping_digest: 7f8defe6ddb2c25e6497006dc0096f15a491c6b938a993419fabd8af89498825
path: mila/native/apple/App/Info-ios.plist
reviewed_chapters:
  marshall/priv/hldd/08-interactive.md: 4f647a511001931a5de54096223d5e9e75e5405a6ec5547fc99749e3ee0ab68d
  marshall/priv/hldd/09-network.md: 225196b393bb0b27d8bdc3bac0a787b869f7d22e9d48ed72dc67ccec6d9ae79b
  marshall/priv/hldd/19-coverage.md: ca523f9fe4b1e2ca0bc8c086cc1e6909b1c8519e91add866cf43770a1121b57e
  marshall/priv/hldd/20-security.md: 24c7bf27384d09e4bc1af6f691e1da2462b03d62aee1605646cb27aa5eb94209
  marshall/priv/hldd/21-domains.md: 64cf0af44004d07c4e5c3402225bb22e5f4f29ae1e8a15b5c7690de8b769efb7
  marshall/priv/hldd/22-topology.md: 2ccae81ed5d94d6f1d3c3cf0a6d88b0a28e9e3f9932631580b5e93fe1c8fa6a4
state: present
version: 2
---

Apple App host package, rewritten mila-build (system Xcode, per-target Rust and Swift triples, Mila.app assembly, refusing and self-verifying release signing), mila-run, catalog-derived NSFaceIDUsageDescription, iOS List selection and resource-bundle fixes, and the WebKit navigation guard that previously never ran; documented in 08 Mila build targets and web, with scenario evidence in 19.
