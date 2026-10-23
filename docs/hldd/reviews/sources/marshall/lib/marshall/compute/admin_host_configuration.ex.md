---
digest: 2a6e8cdd6e1aff7d275fe44179e542962620b881df9f691ea42b9d86c98cc3aa
disposition: updated
kind: source
mapping_digest: c5d6b9e33b777c90bbc22e5608c825ce6977ecc6384e262a6c79b99b4af3d9a2
path: marshall/lib/marshall/compute/admin_host_configuration.ex
reviewed_chapters:
  marshall/priv/hldd/02-control-plane.md: 6ca9a834408a12e1c9a666920927dc154ea406239616809492defdb1e6b1bbfe
  marshall/priv/hldd/03-access.md: 5e197b8346180c9f65c712048048da17934c117a500fe63cfca781cd8933dae6
  marshall/priv/hldd/04-lifecycle.md: f3c40798f402b553640bb25852bcb205c327c87d7ad6735b4f1b243c5616b4a2
  marshall/priv/hldd/06-workflows.md: ad304114da706e2daaf6296aac5c058376e50742cc378ad4fc2a9d475d485124
  marshall/priv/hldd/08-interactive.md: 3b2f40d7d3004923a6bfaa3b6b27287b36731de73182032b29a392be6daf8c0a
  marshall/priv/hldd/11-agents.md: 7d24214acefb26fbd3b08ce582578fd007e6ffa4bd55d986293050de8605356d
  marshall/priv/hldd/15-monitoring.md: 47cae9cafce18ef57d278be5b04ce1dce3799f6583aa1a5bfa8ff80babbf1a99
  marshall/priv/hldd/17-reference.md: 9b7c3c0ba2c93d62cda3b8c5b3914af2ebbab0f7f9c1e6345bdb926d15c8e8cb
  marshall/priv/hldd/19-coverage.md: eec1a8133a836361d14be300a11c987603986208eafcb1cf9930c9fbc0e8d91a
  marshall/priv/hldd/20-security.md: 23fdebc69e8bdbe970942ca43234274500c4f4382f074a590e9238b1762939af
  marshall/priv/hldd/21-domains.md: 64cf0af44004d07c4e5c3402225bb22e5f4f29ae1e8a15b5c7690de8b769efb7
  marshall/priv/hldd/22-topology.md: b66172c618dc03b360046d5e1a6f2850265e5eb7acbe02e20c068a0efdf1569f
state: present
version: 2
---

Guest-credential authentication (inference, Galileo, Peach) now locks hosts FOR KEY SHARE so it never queues behind exchanges; host enable, drain, retire and those credentials issue/rotate/revoke take a FOR UPDATE fence that excludes in-flight readers (02-control-plane host lock paragraph).
