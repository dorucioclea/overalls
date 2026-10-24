---
digest: 2c0f545686c0d81ffdfcfcbe11b9ccd9b3f081a06fe96f08b723736b46050e75
disposition: no-impact
kind: source
mapping_digest: f7ae1015b8a6b22d2b48a9d01c1d52b5bf0d4191e2a4cb42263c24f5d17194fc
path: lilly/native/hostd/src/zfs_policy_tests.rs
reviewed_chapters:
  marshall/priv/hldd/04-lifecycle.md: f3c40798f402b553640bb25852bcb205c327c87d7ad6735b4f1b243c5616b4a2
  marshall/priv/hldd/05-storage.md: 20b3d88d2ba330cd1f7a06b8babe2fd180699c1b60432038b1092ff41f66b855
  marshall/priv/hldd/06-workflows.md: ad304114da706e2daaf6296aac5c058376e50742cc378ad4fc2a9d475d485124
  marshall/priv/hldd/07-guests.md: 35ad495b84f5dc5054c38e2b6f6d3bcab92f813eae44198773dea8777dd99ad8
  marshall/priv/hldd/09-network.md: 225196b393bb0b27d8bdc3bac0a787b869f7d22e9d48ed72dc67ccec6d9ae79b
  marshall/priv/hldd/17-reference.md: 9b7c3c0ba2c93d62cda3b8c5b3914af2ebbab0f7f9c1e6345bdb926d15c8e8cb
  marshall/priv/hldd/19-coverage.md: eec1a8133a836361d14be300a11c987603986208eafcb1cf9930c9fbc0e8d91a
  marshall/priv/hldd/20-security.md: 23fdebc69e8bdbe970942ca43234274500c4f4382f074a590e9238b1762939af
  marshall/priv/hldd/21-domains.md: 64cf0af44004d07c4e5c3402225bb22e5f4f29ae1e8a15b5c7690de8b769efb7
  marshall/priv/hldd/22-topology.md: b66172c618dc03b360046d5e1a6f2850265e5eb7acbe02e20c068a0efdf1569f
state: present
version: 2
---

hostd adds a test-only Hegel property that zfs_policy::mutation refuses create on the pool itself and allows strict descendants; production policy unchanged
