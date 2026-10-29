---
digest: 8d38da4710069ad61b83622f8839d281f1a8a996a91d7f66df976317c995de4f
disposition: no-impact
kind: source
mapping_digest: 2272062390f820f27790d68b944163b5a8c4aa097bb58fe18257524d8b10bbd0
path: pyproject.toml
reviewed_chapters:
  marshall/priv/hldd/01-system.md: e746f0ac6783bb5037c9fd2785c8d8b6aee0f5b279cd263d673ad95462566aa2
  marshall/priv/hldd/17-reference.md: 9b7c3c0ba2c93d62cda3b8c5b3914af2ebbab0f7f9c1e6345bdb926d15c8e8cb
  marshall/priv/hldd/21-domains.md: 64cf0af44004d07c4e5c3402225bb22e5f4f29ae1e8a15b5c7690de8b769efb7
  marshall/priv/hldd/22-topology.md: 2ccae81ed5d94d6f1d3c3cf0a6d88b0a28e9e3f9932631580b5e93fe1c8fa6a4
state: present
version: 2
---

Static-analysis configuration only: ty now resolves the standard library for python-platform linux, the platform these sources run on, so the python-ty gate gives the CI result on a macOS checkout. No runtime behavior, dependency or documented verification scope changes.
