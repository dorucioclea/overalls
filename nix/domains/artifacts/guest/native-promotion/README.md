# Native image promotion

The staging constructors and native assemblers produce candidates with admission
disabled. This separate constructor promotes a reviewed, immutable candidate;
it does not repeat native assembly or reinterpret a stock image as a candidate.

`promote` takes a candidate directory and an explicit version-1 approval:

| Field | Required content |
| --- | --- |
| `image_id` | Exact identity returned by the shared version-6 manifest validator |
| `manifest` | Complete reviewed version-6 native manifest |
| `vmm_sha256` | Exact Firecracker binary used by all five scenario executions |
| `assembly` | Absolute immutable receipt path and its reviewed SHA-256 |
| `scenarios` | Exactly `services`, `growth`, `isolation`, `recovery`, `crash-recovery` |

Each scenario has `name`, a hash-bound `service` receipt, and `supporting`
receipts. Growth and crash require one supporting receipt; isolation and daemon
recovery require two, one per boot. Service receipts must bind the same image,
kernel, firmware and VMM, retain distinct boot identities and the exact named
service checks, and record clean exits except the crash scenario's observed
SIGKILL. The immutable FreeBSD approval retains its 22 reviewed checks. OmniOS
requires 25, additionally covering workspace Git ownership and unrelated-root
refusal, executor heartbeat withdrawal and whole-process-group cancellation.
Those historical sets remain unchanged for manifests without Git identity support.
An explicit `git_identity_version = 1` manifest requires all 25 current baseline
checks on either OS, plus `all-boots-current-mmds-git-config-and-commit-attribution`.
The capability is validated by the shared manifest validator and binds the image
identity; receipt contents cannot enable it. Missing, substituted, duplicate or
extra oracle names refuse, including equal-count substitutions.
Supporting receipts must cover those same boots. All original candidate
receipts retain `native_admission=false`; the approval and runtime capability
registry are separate authorities.

Verification streams the final disk and firmware through SHA-256 and validates
the image ID with the shared protocol implementation. The builder writes
`manifest.json` only after evidence verification passes. The published image
directory contains exactly `disk.raw`, `firmware` and `manifest.json`; installation
media, debugging hooks and evidence files do not enter that directory.

The approved manifest must also enter the protocol's exact-image native
admission registry. Constructing an admitted Nix package alone does not grant
capabilities to arbitrary manifests or retained native image records.

## Publishing a sealed native candidate

`publishedCandidate` declares a recursive fixed-output derivation with a reviewed
NAR SHA-256. It uses ordinary signature-verified substitution from the existing
Overalls Cachix cache. It requires neither `fetch-closure` nor a token in Nix
evaluation. Its only fallback prints publication instructions and refuses;
it cannot manufacture artifact bytes after a cache miss.

Prepare a directory containing the exact reviewed `disk.raw`, a regular
dereferenced `firmware` file and the public assembly/scenario receipts under
`evidence/`. Preserve the original candidate and test outputs. Then:

```sh
nix store add-path --name overalls-native-OS-RELEASE-DIGEST /path/to/sealed-directory
nix path-info --json /nix/store/RETURNED-PATH
```

Record the returned content-addressed store path and recursive `narHash` in the
review and constructor. The existing host-custodied Cachix publisher uploads
that store path without exposing its token. Verify public cache availability,
its trusted signature and exact NAR contents before catalog activation. A fresh
store substitution provides an independent publication check.

Evidence paths in the approval interpolate this fixed-output candidate, so
remote builds fetch the same evidence rather than reading another machine's
temporary files or relying on the retention of an old test-output store path.
This is an immutable artifact promotion workflow. It does not establish
reproducible native image assembly, physical isolation, power-loss durability,
or Marshall-driven fleet acceptance.

The `native-image-promotion` check exercises both native manifest families and
refuses mutated artifacts, foreign or changed evidence, replayed boot IDs,
incomplete scenarios and extra output files. It is a host verifier test, not
native runtime acceptance. Passing this structural verifier does not qualify a
new image, enter it in the exact admission registry, publish its bytes or activate
its catalog selection; each remains a separate reviewed prerequisite.

## Retained promotions

The registry is an input of every `promote` build, so a registry change rebuilds
every promotion and needs each sealed candidate again. `retained` keeps a promotion
whose candidate is no longer substitutable. It takes the exact output of the
original verified promotion build and pins it by recursive NAR hash. Before
publishing a retained output:

- run `nix store verify --no-trust` on the original promoted path;
- compare its `manifest.json` with the reviewed manifest under `protocol/priv/native`;
- check the disk and firmware SHA-256 against that manifest.

Then add it:

```sh
nix store add-path --name lilly-OS-...-promoted /nix/store/ORIGINAL-PROMOTED-PATH
```

The Cachix publisher uploads the returned path. A cache miss refuses. A retained
image is not re-verified against later registry revisions; runtime admission still
uses the compiled registry.
