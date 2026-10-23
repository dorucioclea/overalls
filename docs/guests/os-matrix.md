# Guest operating-system matrix

The shared [fleet image list](../../fleet/guest-images.nix) declares seven OS
families. Its selected-package admission filter now yields seven catalog
entries: `omniosGuest` and `illumosGuest` select the exact reviewed immutable
OmniOS promotion. Catalog declaration, deployment, staged artifacts, native machine
execution and live fleet acceptance are separate evidence scopes.

The seven immutable identities recorded below have separately recorded successful
create/readiness, strict personal-account CLI SSH, stop with an independent
current-owner stopped checkpoint, same-VM restart, repeated strict SSH and
completed deletion. The [matrix review](../architecture/reviews/2026-10-18-guest-os-matrix.md)
binds the 49 stage receipts at their distinct times and execution revisions.
The source now selects editor-bearing replacement Arch/Alma images with passing
artifact checks and fresh production CLI lifecycles. Alma's complete isolated
browser suite passed; Arch's same-image diagnostic replay also passed all twelve
stages after an earlier broker-recovery failure. Evidence is tracked
separately in the [editor repair review](../architecture/reviews/2026-10-18-foreign-linux-browser-editor.md).

| Family | Selected package | Boot and agent contract | Current evidence and limit |
|--------|------------------|-------------------------|----------------------------|
| NixOS | `guest` | Linux kernel, version 4, `linux` | Exact selected `92114604` passed fresh `101111` strict personal-account CLI SSH, stop with separate stopped checkpoint, restart, repeat SSH and deleted cleanup. Existing native scopes remain separate; see [ADR-0011](../architecture/decisions/0011-nixos-guest-and-console.md). |
| Ubuntu 26.04 LTS | `ubuntuGuest` | Linux kernel, version 4, `linux` | Unchanged selected `8d468c67` retains the `075200` complete strict CLI lifecycle/deleted-cleanup evidence and final immutable artifact custody; see the [Ubuntu guide](ubuntu-guests.md). |
| Arch Linux | `archGuest` | Linux kernel, version 4, `linux` | Editor-bearing `0b3da3e8` passed actual-image checks and fresh `132308` strict CLI SSH/PAM/sudo, stop/checkpoint/restart, repeat checks and original owned deletion. Native fixture `b1c8ff76` passed all twelve browser stages on the captured diagnostic source. The earlier broker-restart 502 remains unexplained; neither result qualifies the later trunk merge or production browser sign-in. Earlier helper-fixed `99fa9876` retains its `114223` lifecycle pass. Earlier `8ab89c2d` failed SSH at PAM account management; historical failure and cleanup retain their own receipts. |
| AlmaLinux | `almaLinuxGuest` | Linux kernel, version 4, `linux` | Editor-bearing `65e7700b` passed actual-image checks and fresh `132308` strict CLI SSH/PAM/sudo, stop/checkpoint/restart, repeat checks and original owned deletion. Isolated browser fixture `90eca504` passed all twelve native subtests, including recovery and current-authority refusal. Earlier helper-fixed `473f9589` retains its `114223` lifecycle pass. Earlier `bed87c33` failed authentication; historical failure and cleanup remain separate. |
| FreeBSD 14.3 | `freebsdGuest` | CloudHv firmware, raw GPT/UFS, version 6, `freebsd-v1` | Exact promoted image; five native scenarios passed. Runs `072900` and `075200` passed CLI lifecycle and terminal deleted cleanup. The later cleanup required scoped idle rootless-namespace recovery; that manual recovery does not establish general automatic cleanup. |
| OmniOS r151050 | `illumosGuest` | CloudHv firmware, raw GPT/ZFS, version 6, `illumos-v1` | Exact promoted image is selected and admitted. Disk `a96f291b` (Nix KVM assembly carrying the `vioif` receive budget and growth disk-link fixes) passed all five Nix machine scenarios, transport, reset and power loss; the earlier `45983bb7` promotion stays admitted and staged for retained machines. The live CLI journeys below ran on `45983bb7` and do not transfer to `a96f291b`. Fresh `122228` passed the full 16 GiB strict CLI lifecycle, separate current-owner stopped checkpoint and completed deletion. Earlier `091638` retains its own lifecycle and original release-label oracle failure; it lacked that separate checkpoint. |
| Windows Server 2025 | `windowsGuestPublished` | CloudHv firmware, raw GPT, version 5, `windows-v1` | Repaired `8ca0a11f` passed installation, sealing, executable readback, signed publication and independent full-content substitution. Fresh `103842` passed create/readiness, exact strict CLI SSH, stop with separate stopped checkpoint, restart, repeat SSH and deleted cleanup. Its original warning-only failure is preserved; the runner admits only the exact stock Windows warning without changing trust/algorithms. Terminal, executor, workspace, growth and isolation remain separate. See the [Windows guide](windows-guests.md). |

The helper repair following the Arch/Alma rows' failed SSH attempts is now implemented in exact
rebuilt Arch `99fa9876` and Alma `473f9589` images. The root-only guest oneshot
recreates only pinned PAM's compiled `unix_chkpwd` helper before SSH, preserving
owned key-only policy and existing nosuid mounts. Actual-image custody,
independent rootfs/package rebuilds and the isolated VM root-account
success/expiry/unsafe-path checks passed. The exact rebuilt images subsequently
passed fresh guest SSH/sudo and lifecycle acceptance in `114223`, including
the same reviewed read-only checks after restart. Runtime helper storage remained
nosuid; the result establishes the observed root PAM/sudo paths, not direct
unprivileged helper setuid elevation.

The [foreign Linux evaluation](../../nix/verification/tests/evaluation/foreign-linux-guests.nix)
checks the Arch/Alma inputs, manifests and offline closure. It does not execute
either distribution. Distribution display names and the website's OS labels
also do not prove what kernel or root actually ran.

The seven CLI journeys do not prove browser editor support. In particular, the
helper-fixed Arch `99fa9876` and Alma `473f9589` images omit the editor runtime,
broker and immutable descriptor; the browser correctly refuses them. The
[editor repair review](../architecture/reviews/2026-10-18-foreign-linux-browser-editor.md)
tracks new editor-bearing images and separate browser acceptance. Host updates
do not add the editor to existing disks.

The qualified FreeBSD image ID is
`sha256:d141e4266c29da00a1378157b1d39369b1d48e577bca4ce7375e8ff6d399557b`.
The [compiled registry](../../protocol/lib/overalls_protocol/native_admission.ex)
also qualifies the selected OmniOS image
`sha256:6dc1a0840e50e508c964c2890e805c919b78c2cddb3e1e8e9d379e001c28617d`
and retains the earlier
`sha256:98b23b7931bc52d55b3c5b38cc20c97c1c967be96cf301940f88b01c715530d8`
in reviewed history.
It requires the complete validated immutable identity; a family name, image ID alone, stock
disk or changed candidate cannot activate native capabilities. Unqualified
`freebsd-v1` and `illumos-v1` rows remain all false. Exact qualification
enables readiness, trust, terminal, workspace, flush, SSH and agent execution;
editor and Inception remain disabled. Windows also keeps editor and Inception
disabled. Inception is known broken and outside this acceptance work.

[ADR-0190](../architecture/decisions/0190-native-kernel-provenance-and-admission.md)
and the [native admission review](../architecture/reviews/2026-10-17-native-image-admission.md)
govern per-image native promotion. The [OS matrix review](../architecture/reviews/2026-10-18-guest-os-matrix.md)
records the exact OmniOS promotion, publication and current source gates. The [native kernel review](../architecture/reviews/2026-10-17-native-kernel-attestation.md)
records full artifact identities and the scoped OmniOS receipts. None of those
records establishes direct native peer-VM or physical-host isolation,
interrupted growth, physical durability, relocation or acceptance of every
enabled capability. The scoped SSH/lifecycle milestone does not complete every
requirement of the custom native-kernel plan; ADR-0190 remains accepted/partial.

The opt-in [Porsche acceptance runner](../acceptance/porsche-acceptance.md)
provides a separate path to collect live catalog, creation, SSH OS-identity and
lifecycle evidence using explicit image IDs. The seven families were executed
as separate identity-bound journeys; no simultaneous same-revision seven-OS
run is claimed. New runs still require every selected image to pass the
selected-package admission and live availability gates.
