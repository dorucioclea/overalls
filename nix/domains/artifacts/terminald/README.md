# Lilly terminald

`lilly-terminald` is the Rust terminal multiplexer inside Overalls guests. It
creates shells on PTYs, retains bounded scrollback and keeps sessions alive
across browser disconnections, accepting authenticated control and attachments
from Lilly over vsock for the current guest boot.

```mermaid
flowchart LR
  Browser["Browser terminal"] --> Marshall["Marshall"]
  Marshall -->|"Authorized terminal stream"| Lilly["Lilly"]
  Lilly -->|"Authenticated vsock"| Terminald["Guest terminald"]
  Terminald --> Sessions["PTYs and guest shells"]
```

See the [multiplexer decision](../../../../docs/architecture/decisions/0082-guest-terminal-multiplexer.md).

`terminald.native` cross-links this same session engine for FreeBSD and illumos.
The native socket adapters use ADR-0190's sixteen-byte ABI: family45 with BSD
length/family bytes on FreeBSD, family40 with a flat family field on illumos.
Accepted addresses must match that ABI before the common host-CID2 and
boot-bound HMAC gates read requests. Firmware guests share the existing MMDS2
boot-identity client with Windows; Linux retains its kernel-command-line input.

Unix PTYs continue resolving and applying passwd credentials before exec.
FreeBSD uses `close_range` with close-on-exec flags. The pinned OmniOS libc
lacks `ptsname_r`, so illumos copies `ptsname` under a daemon mutex before fork.
Its child uses bounded `fcntl` calls rather than libc's post-fork-unsafe
`closefrom`/`fdwalk`, refusing infinite or larger-than1048576 hard descriptor
limits. The illumos slave checks and pushes `ptem`, `ldterm` and `ttcompat`
before setting the requested geometry and entering the common exec path.

The native package records both bounded ELF executables, exact SHA-256/byte
identities, guest interpreters, reviewed shared libraries and pinned toolchain
inputs. Native cross-links, Linux unit/property checks and service definitions
do not establish native guest transport, terminal journeys or image admission.
Each generated Linux PTY history retains its own concurrent sessions and workers;
the Nix gate runs top-level histories serially to isolate their finite resources.
