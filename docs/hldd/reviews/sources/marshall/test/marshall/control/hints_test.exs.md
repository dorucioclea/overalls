---
digest: 571056efce23d48ffbba8602b521bce2661bc943cf1862fa64d7bbe42544a72b
disposition: updated
kind: source
mapping_digest: c5d6b9e33b777c90bbc22e5608c825ce6977ecc6384e262a6c79b99b4af3d9a2
path: marshall/test/marshall/control/hints_test.exs
reviewed_chapters:
  marshall/priv/hldd/02-control-plane.md: 8398bc3791875b6bc8cf22b6602a6efccb886c001a0f78d5a1500a3f5707ff3d
  marshall/priv/hldd/03-access.md: 9637f378d65cb4e5cd6ca8b852818cbad487a9a6d008a61ede50e7655fbd6669
  marshall/priv/hldd/04-lifecycle.md: f3c40798f402b553640bb25852bcb205c327c87d7ad6735b4f1b243c5616b4a2
  marshall/priv/hldd/06-workflows.md: 37821743fdd87afefc8e10be455a247a49c10cb8fced69dd60588fe573bce8de
  marshall/priv/hldd/08-interactive.md: 368f33fbb31c849c8558e3988b6199db2635f59e76065042873e1de42c9eaef3
  marshall/priv/hldd/11-agents.md: 7d24214acefb26fbd3b08ce582578fd007e6ffa4bd55d986293050de8605356d
  marshall/priv/hldd/15-monitoring.md: db740282f22afc4c76be24d9db3f9ef4f10bf2745089a754647c6cf7e8fdfeef
  marshall/priv/hldd/17-reference.md: 7d88fca8dbe56f67c71ea207b0ed860f4cfc005f7cb9f6ccde4ffe4bc718cda5
  marshall/priv/hldd/19-coverage.md: 9a6c6e497149225fa418d0ec0b2fa9bb578557f066fbd6a194e728073bca669b
  marshall/priv/hldd/20-security.md: cf1337ba6e78c460d2d00a269abbe3ad011151401179263eb51ab2d90bb4948f
  marshall/priv/hldd/21-domains.md: 64cf0af44004d07c4e5c3402225bb22e5f4f29ae1e8a15b5c7690de8b769efb7
  marshall/priv/hldd/22-topology.md: b66172c618dc03b360046d5e1a6f2850265e5eb7acbe02e20c068a0efdf1569f
state: present
version: 2
---

Committed Inception environment publications now emit a DNS snapshot hint in the same transaction as VM authority changes; the regression test asserts the dedicated hint and action mapping. This keeps short-lived child DNS records visible to replicas before certificate issuance.
