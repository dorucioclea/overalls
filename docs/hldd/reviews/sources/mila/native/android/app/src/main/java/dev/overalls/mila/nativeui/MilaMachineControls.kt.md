---
digest: 504889b45f02bb110a99cfc9a89d7de9a3a8614fe46087df4041a3d48395a681
disposition: no-impact
kind: source
mapping_digest: 7f8defe6ddb2c25e6497006dc0096f15a491c6b938a993419fabd8af89498825
path: mila/native/android/app/src/main/java/dev/overalls/mila/nativeui/MilaMachineControls.kt
reviewed_chapters:
  marshall/priv/hldd/08-interactive.md: e30dfcfc4d7d1c2ad4dbfffeff050f40895971685e76bde8705c14598947227a
  marshall/priv/hldd/09-network.md: 225196b393bb0b27d8bdc3bac0a787b869f7d22e9d48ed72dc67ccec6d9ae79b
  marshall/priv/hldd/19-coverage.md: eec1a8133a836361d14be300a11c987603986208eafcb1cf9930c9fbc0e8d91a
  marshall/priv/hldd/20-security.md: 23fdebc69e8bdbe970942ca43234274500c4f4382f074a590e9238b1762939af
  marshall/priv/hldd/21-domains.md: 64cf0af44004d07c4e5c3402225bb22e5f4f29ae1e8a15b5c7690de8b769efb7
  marshall/priv/hldd/22-topology.md: b66172c618dc03b360046d5e1a6f2850265e5eb7acbe02e20c068a0efdf1569f
state: present
version: 2
---

Android deep links and external intents queue until sign-in and apply only on the signed-in path, deployment persistence stores several credential-free entries with a selected key, switching/forgetting a deployment closes the session, and PTY reattach resumes from the received byte cursor; consistent with the documented signed-out and reattach boundaries
