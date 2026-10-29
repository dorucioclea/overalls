---
digest: ff3755829c07deaa1e63428d689c37fc234788b58fb33f1c5a04c56b40fe21bd
disposition: no-impact
kind: source
mapping_digest: 05e1761038133f69f40af77d180940fa94168af5fea92478049f84f74b8e9d48
path: devenv.yaml
reviewed_chapters:
  marshall/priv/hldd/07-guests.md: 7ae19b50cf45b3c14133dce10b3539f089564fa61accbdc3024126baed9351dc
  marshall/priv/hldd/12-configuration.md: 5318d494cf8479636aa2e2c3c61cb5505cb4cb8386e39b935cf62c62b997169f
  marshall/priv/hldd/13-deployment.md: 0bc4fe19bb9cdf60d5edc24c3777c7f54b170426d9ae5d1f611a2240053c3350
  marshall/priv/hldd/14-operations.md: 68c72d0e6fde22edd5d892f824dedd44f1843d68ece6c96ff5b3e2c1e50051c9
  marshall/priv/hldd/15-monitoring.md: 47cae9cafce18ef57d278be5b04ce1dce3799f6583aa1a5bfa8ff80babbf1a99
  marshall/priv/hldd/16-recovery.md: 194fe77196ac4a25ab764d5cf4aee7558da547cd7b59726f32a302019b26136c
  marshall/priv/hldd/17-reference.md: 9b7c3c0ba2c93d62cda3b8c5b3914af2ebbab0f7f9c1e6345bdb926d15c8e8cb
  marshall/priv/hldd/18-options.md: 36eb75282edf617a1de06e4077c3cd20b396b14b150b9a36fb25e0256b069326
  marshall/priv/hldd/19-coverage.md: ca523f9fe4b1e2ca0bc8c086cc1e6909b1c8519e91add866cf43770a1121b57e
  marshall/priv/hldd/20-security.md: 24c7bf27384d09e4bc1af6f691e1da2462b03d62aee1605646cb27aa5eb94209
  marshall/priv/hldd/21-domains.md: 64cf0af44004d07c4e5c3402225bb22e5f4f29ae1e8a15b5c7690de8b769efb7
  marshall/priv/hldd/22-topology.md: 2ccae81ed5d94d6f1d3c3cf0a6d88b0a28e9e3f9932631580b5e93fe1c8fa6a4
state: present
version: 2
---

devenv.nix/yaml change only the Darwin developer shell: the same Rust 1.97.1 from rust-overlay with iOS std targets, and mila-build/mila-run wrappers. Deployed hosts, Nix packages and the mila-rust Nix check keep the nixpkgs toolchain; the developer-facing facts are in 08 Mila build targets.
