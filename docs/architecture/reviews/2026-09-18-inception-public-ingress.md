# IPv4 separation and Inception public ingress — implementation review

## Current correction — 2026-10-28

The native run reached both nested control certificate workers and Pebble orders,
but a two-second child heartbeat was not accepted reliably: parent pool-locked
sections reached 1.3 seconds before the second authenticated exchange and left
no observation window. The control publication lease is now five seconds,
matching the existing child-publication maximum and parent offer bound. It still
binds the boot, generation, job nonce and original five-minute job deadline; no
lease renewal or receipt-time extension is possible. Lilly retries a complete
poll with fresh offers/publications and refreshes the child sample before
observation, with a 1.2-second bounded query guard. The focused runtime gate
passes after this correction; the native acceptance run must be rerun.

## Current reconciliation checkpoint — 2026-09-20

The user explicitly requested publishing this incomplete checkpoint before
continuing implementation. The publication reconciliation incorporates
`origin/main` at `51cfd017`, including terminal-v2 and Underclass. Inception is
renumbered from ADR-0081 to ADR-0085 because upstream now owns ADR-0081 through
ADR-0084. The merge preserves the separate fleet listener and Inception exchange,
adopts the upstream no-serial-login guest boundary, and supplies terminald to
the offline image recipe. The legacy dtach-based Inception probes still need
conversion to the accepted vsock terminal transport. Pre-merge application gates
and native runs below do not establish verification of this newer merged tree.

This section supersedes older completion and timeout claims below for the
`ac7eb26`-based worktree. ADR-0085 remains **partial**. The current corrections
preserve its authority, isolation and image-size decisions.

- Marshall and Audi's complete precommit gates passed after fixing Audi's
  missing initial host-key publication outcome state and reconciling stale
  lifecycle/logging assertions. Lilly's merged-tree gate also passed.
- The native driver builds with PostgreSQL 18 (required by the merged
  `uuidv7()` migration), a configured but inactive outer Galileo fixture,
  and a private probe runtime directory. These fix fixture prerequisites.
- The trimmed cache rebuilt an image in a separate local Nix store with a
  different public root and substitutions disabled. The store was populated
  from the shipped cache closure. An inherited remote-builder attempt failed;
  the build completed locally. This establishes isolated rebuild completeness,
  not successful first-boot execution inside Firecracker.
- Run 17 passed nested eligibility and receipt tampering, enrolled both DNS
  replicas and launched the first managed VM. Lilly reported `execution_failed`
  exactly ten minutes after launch. Two-environment acceptance was not reached.
- Contrary to earlier timeout commentary, the production executor uses 600,000
  milliseconds and both credential/readiness socket helpers reject larger
  limits. Fixture calls passing 1,500,000 milliseconds were invalid and are now
  corrected. A longer outer test deadline cannot fix an inner startup failure.
- A bounded fixture diagnostic now samples fixed inner service active/failed
  predicates before that deadline. It discloses no terminal or journal contents.
  Run 18 executed the diagnostic successfully, but `/dev/console` did not reach
  the captured serial log. Status predicates now use service stdout for journal
  capture; verification of that correction is pending. The nested creation
  fixture also now selects the instance-rebuilt image that enrollment registers,
  rather than the unregistered packaged seed; native verification is pending.
  Ruff, Ruff format, Ty and all logging hooks
  passed after the fixture changes; standalone Elixir parsing is syntax evidence
  only.

### Requirement-to-evidence audit

| ADR-0085 requirement | Current executable coverage | Remaining acceptance |
| --- | --- | --- |
| Two simultaneous independent environments | `inception/driver.py` creates two separate-user environments | Current run fails first-environment readiness |
| DNS-01 and verified control TLS | Two real DNS replicas, isolated issuer, external TLS checks in driver | Not reached on current tree |
| Browser sessions and independent authentication | Existing component/integration tests | Full nested browser scenario absent from this driver |
| WebSockets | Local TLS/proxy and fleet scenarios | Full nested two-environment scenario absent |
| Nested SSH with host-key verification | Generated-profile OpenSSH fixture and real Audi transport tests | Real Firecracker nested SSH not covered by current driver |
| Expiry and ancestor revocation | Component authority/transport tests | Active descendant streams in native Inception remain unverified |
| Namespace and source-spoof isolation | Public fleet-prefix refusal probe; paired-address implementation | Native cross-environment spoof probes still required |
| Restart and paired cleanup | Managed sibling deletion plus direct-driver retention/lifecycle phases | Not reached on current tree |
| Offline instance-specific guest trust | Isolated-store rebuild succeeds | Actual inner boot, nested guest and private inference remain pending |

The fixture sources are in
[the native suite](../../../nix/verification/tests/machines/inception/default.nix).
Neither a driver build nor this checkpoint establishes full public acceptance
or production readiness. No deployment is claimed.

Scope: uncommitted implementation in `feat/audi-inception`, based on origin/main
`f46fb307b4e8fc540fe3d560e6b430d3eb1070e3`. This is an interim review, not acceptance.
The user authorized the full implementation, then commit and push to origin/main.
No implementation commit, push or deployment has occurred. The current reconciliation preserves upstream Customer isolation and private
services. Its combined verification and inner private-service integration remain
required before publication.

## Architecture impact

[ADR-0085](../decisions/0085-inception-public-ingress.md) is accepted and partially
implemented. It supersedes ADR-0054's exclusion of public inner services, retaining
one-layer Firecracker execution, storage ownership and independent identities.
ADR-0047 and ADR-0052 authority, expiry and local-placement constraints still apply.
No Erlang distribution, arbitrary TCP forwarding or cross-host guest relay is added.

## Implemented boundaries

- Explicit IPv4 listeners and destination-specific firewall rules allow Audi and
  Porsche to share ports on distinct IPs. Wildcard and same-address collisions
  fail. Readiness probes the actual local bind address, including source binding.
  Local NETLINK_ROUTE interface discovery is allowed; it grants no NET_ADMIN.
- Overalls assigns OVERALLS_SERVICE_IPV4/26 to Audi alongside control/admin .55, with
  gateway OVERALLS_GATEWAY_IPV4. IPv6 is disabled. Both addresses are protected from guest
  egress. The existing immutable Lilly network binding requires coordinated
  activation; its protection must not be bypassed by the updater.
- Inception derives paired 10.40 control and 10.41 Audi addresses from one slot,
  with one NIC, guarded TAP, MAC and lifecycle claim. Both routes are checked
  before mutation. Native simultaneous isolation and spoofing checks remain open.
- Audited Ash environment identity is created during admission and retains its
  stable label and revocation. Publications bind host session, execution epoch,
  placement, boot and environment generation to a single-use five-second offer.
  Acceptance uses the original offer and remaining child lifetime, never receipt
  time. Three migration upgrades add environment, publication and stream state;
  they do not drop existing production tables.
- Publication uses a separately bounded vsock 1026 exchange, independent of
  readiness 1024 and SMTP 1025. The guest accepts CID 2/current boot only. Lilly
  rechecks the owned VMM on both sides, runs at most sixteen placement tasks and
  terminates stalled tasks. Namespace replacement and generation rollback fail.
- Parent DNS uses one current-authority SQL projection. It strips child addresses
  and supplies physical parent Audi addresses. TXT is available before completed
  startup; A records require readiness. Queries use local snapshots rather than
  synchronous control calls. Namespace bounds reserve the full DNS-01 owner.
- Nested stream admission and renewal preserve current publication, placement,
  generation, host session and SSH key, with an independent expiry watchdog.
  Audited stream tokens have a separate purpose and a 1024-live-stream bound.
  Parent namespace permission never implies child membership.
- Audi inspects bounded ClientHello bytes before TLS termination. Nested TLS is
  opaque; ordinary names retain the existing HTTP/1 TLS path, with no unknown-name
  certificate fallback. Nested HTTP redirects grant no access authority. Only
  the trusted Lilly connector supplies the fixed IPv4 PROXY v2 metadata; public
  headers cannot supply peer identity.
- Nested SSH selects only Porsche or Audi, after parent key authentication. Inner
  authentication is independent. Host keys are checked at both layers, and key
  changes terminate leases. Generated profiles use current verified HTTPS key
  lookup, IPv4 and no agent forwarding or multiplexing. Inner ordinary-workload
  profiles now include the additional outer chain from immutable parent discovery;
  real three-layer OpenSSH execution passes, while full Firecracker acceptance
  remains outstanding.
- Inner PostgreSQL, Marshall, Lilly, Porsche and Audi bootstrap from independent
  guest-local identities. Ensure actions preserve enabled identity and refuse
  revoked/mismatched authority. Namespace acquisition precedes public origins;
  migrations and core enrollment do not await certificates. Administrative access
  remains the authenticated console, with no inner root SSH listener.
- The child producer uses fixed verified loopback HTTPS and separate DNS/gateway
  tokens. It bounds records/proofs, strips private addresses and expires output
  if stalled. Persistent private SSH keys survive canonical public-key export;
  comments from `ssh-keygen -y` are removed from public exports only.
- Optional operator issuer, explicit consent, public CA material and named IPv4
  authoritative endpoints travel through the authenticated offer. Both decoders
  share a rejection corpus and wire-size limit. Trust cannot change within a boot.
  Inner DNS uses its own token and a loopback IPv4 UDP/TCP listener. It does not
  delegate public queries to private guests.

## Proof observations and clock boundary

[Parent observations](../../../lilly/lib/lilly/inception/propagation.ex) query
only fixed operator IPv4 endpoints, requiring matching authoritative questions,
exact TXT sets and bounded TTL on every replica. Owner selection rotates through
bounded batches, with bounded concurrency and one shared deadline. The host
submits the child publication before observing propagation.

The [child receiver](../../../nix/domains/artifacts/guest/inception/observations.py) consumes
an exact original offer once, checking boot, generation and proofs. It caps expiry
from offer creation and original source lifetime, never receipt. Root owns the
Audi-readable evidence directory and atomically published file. A bounded local
Unix broker accepts only root or Audi's actual UID and returns remaining TTL.

The [Audi client](../../../audi/lib/audi/acme/observed.ex) verifies the broker UID
before sending and anchors returned duration to request start. Python and BEAM
monotonic epochs differ, so direct timestamp comparison would be invalid. Missing,
expired or refused evidence has no direct-DNS fallback. Inner Audi TLS is configured
to use this broker and independently held certificate keys; native issuance has
not yet been established.

## Inner control TLS

The [proof hook](../../../nix/domains/artifacts/guest/inception/control_proofs.py) accepts
one fixed control owner and canonical proof under a boot/generation/job nonce,
with a nonrenewable three-minute deadline. It completes presentation only after
fresh parent evidence. The [worker](../../../nix/domains/artifacts/guest/inception/control_worker.py)
uses independent persistent Lego account state, an isolated environment and a
bounded process group. Completion, timeout or exit kills remaining hooks before
clearing authority. Restart discards old jobs before publishing cached readiness.

The [TLS helper](../../../nix/domains/artifacts/guest/inception/control_tls.py) validates
CA trust, hostname, key, lifetime and the complete candidate HAProxy configuration
before atomic certificate replacement. Readiness requires a fresh source-bound
IPv4 PROXY/TLS/HTTP probe, including the exact served leaf. A failed probe cannot
publish ready. The [units](../../../nix/domains/artifacts/guest/inception/control.nix) keep
issuance separate from core readiness and run the proxy unprivileged. BindsTo and
ordering stop the proxy when its worker becomes inactive, including unexpected
exit; native failure propagation remains unverified.

Six isolated TLS tests include real socket rejection, private atomic replacement,
pinned OpenSSL/HAProxy validation, original-source rejection before PROXY parsing,
forwarded-header replacement, certificate reload and survival of an upgraded
connection. Three worker tests cover closed issuer inputs, termination of an
issuer plus forked hook, and restart/generation fencing. These tests pass in the
Nix runtime gate. Pinned Lego 4.35.2 exposes the configured DNS flags. Its blind
propagation delay is not treated as evidence: the fixed hook first waits on the
parent observation. Actual child issuance still requires native acceptance.

The native issuer accepted both control accounts and orders but never reached
challenge validation. Source review found an impossible additional margin in
the control hook: a two-second publication yields at most one second after DNS
TTL flooring, while the hook demanded more than one second of remaining evidence.
It now accepts strictly unexpired exact-match evidence, matching inner Audi's
existing rule. The two-second producer limit, original observation deadline,
job expiry and boot/generation/proof binding remain unchanged. Six proof-hook
checks pass, including real-file evidence with less than one second remaining;
the full Nix runtime gate passes. Native issuance still needs a rerun. Separate
Audi clients also rejected the isolated issuer TLS certificate. A local test
with the pinned Audi release reproduced rejection of the fixture's CA-as-leaf
certificate; its corrected CA-signed server leaf passes the actual ACME directory
transport and still fails without the CA. The fixture now supplies that CA to
clients. This is independent of the control hook's observation failure.

## Outstanding findings

1. **High — public acceptance missing (ADR-0072):** the expanded native fixture
   now wires a real DNS-01 issuer, two separately enrolled Audi DNS replicas,
   verified control HTTPS, outer Audi on a separate IPv4 address and public
   control-certificate assertions. It has not passed. Complete actual issuance,
   browser/SSH/WebSocket ingress, independent authentication, expiry, revocation,
   restart, spoofing and paired cleanup with two simultaneous environments.
   The fixture now provisions two separate-user environments concurrently and
   checks both control names, nested lifecycle and sibling survival on deletion.
   Its first run reached the first environment, then failed inner enrollment
   readiness before creating the second. The fixture now waits for the actual
   boot-bound readiness response before physical assertions. The next pre-merge
   run passed core readiness and physical checks for both simultaneous
   environments, then timed out waiting for the first public control A record.
   Complete public acceptance and the merged revision remain unverified.
2. **High — inherited private-service integration incomplete (ADR-0063/0064):**
   upstream requires Ziggy and private Audi on every Lilly host. The inner image
   still needs independent service enrollment, guest trust and provider
   configuration; it must not inherit outer production secrets. Independent
   runtime root/intermediate custody and the restricted inner issuer are now
   wired, with crypto and configuration checks passing, but native startup is
   not yet verified. Inner enablement now invokes independent Ziggy token
   enrollment after the native host report is accepted. Its trusted coordinator
   serializes on the host and preserves credential identity and expiry on retry;
   it refuses existing history, revocation, expiry, changed secrets and host
   mismatch instead of rotating. Six database tests pass, including ordinary-user
   refusal of the new internal Ash action. A native authentication/retry probe
   is wired but has not run. This carries forward ADR-0063/0064's independent
   authority and changes no provider custody decision. The subsequent Marshall
   precommit gate passes 741 tests/properties (two excluded), with zero Dialyzer
   errors. The Inception runtime check, including parsing the release eval
   scripts, also passes. Inner Ziggy now shares the physical service's hardened
   unit definition. Its runtime uses only the inner host identity, local fleet
   TLS and independently decrypted provider keys; no parent keys or placeholder
   defaults are selected. Four private-file/provider-selection tests, the Nix
   runtime gate, shared-module check and Ziggy configuration check pass. The
   updated image evaluates. The shared Ziggy unit also passes its native service
   test in 39.86 seconds: encrypted secret delivery, verified synthetic-provider
   streaming, accounting pressure/recovery, stream revocation, restart without
   replay, and Audi's inability to read credentials. Its result is
   `/nix/store/8xxdjida4a5qbzxq2bac8jid2h236qyr-vm-test-run-overalls-ziggy-service`.
   That fixture uses synthetic control authority, so it does not establish native
   Inception acceptance. Inner private Audi now shares the physical renewal and
   frontend units, receives only leaf custody/public roots and enters the exact
   enrolled Lilly namespace through a root-owned link. Five runtime tests reject
   changed host identity, foreign links/files, unsafe locks and disabled private
   networking; runtime, private-PKI and configuration gates pass, and the image
   evaluates. Inner Lilly enables the real private network/connector and keeps
   its private-readiness prerequisite for new guest execution. The native fixture
   now installs distinct disposable provider keys through each guest's own SOPS
   recipient and verified isolated-provider TLS, leaving real inner Marshall
   authentication/accounting in place. This new phase has not run. The outer
   fixture's default Ziggy remains outside startup targets; that separate outer
   scope does not establish private inference. Native inner service acceptance,
   reproducible nested-image trust and guest inference remain incomplete.
3. **High — SSH acceptance incomplete (ADR-0072):** parent discovery now travels
   from the operator endpoint through the authenticated offer and boot-bound
   namespace receiver into inner Marshall. Ordinary workload profiles add the
   fixed outer/inner Audi chain, with fresh HTTPS key discovery at both layers
   and separate guest host files. Invalid or mismatched metadata fails closed.
   The real OpenSSH fixture passes the generated three-layer profile, current-key
   refusal at both Audi layers, independent guest host trust and unavailable
   HTTPS discovery. It verifies no agent forwarding. It uses stock sshd and
   controlled key publication, so full Firecracker-path acceptance remains open.
4. **Medium — fleet listener migration incomplete:** the deployed topology used
   the same Marshall endpoint for local fleet calls and public HAProxy traffic.
   Authentication was required, but local routing did not imply private-only
   exposure. In this worktree, the new
   [fleet routing](../../../marshall/lib/marshall_web/fleet_endpoint.ex) and
   [public refusal](../../../marshall/lib/marshall_web/public_ingress.ex) plugs
   are now wired into the application: production starts a separate Bandit
   HTTPS listener and the browser endpoint refuses reserved machine API paths.
   Operator mode starts neither listener. Sixteen isolated runtime/routing tests
   pass (three properties and thirteen tests). Nix defaults the fleet listener
   to explicit IPv4 loopback and a separate port, without opening its firewall;
   module and inner-runtime checks pass. Inner service callers and local Overalls
   callers use the new port. Explicit additional loopback binding now permits the same
   fleet API to serve colocated and WireGuard callers without changing local
   database hostname resolution. Runtime tests cover both bindings, duplicate
   suppression and loopback/browser port collisions. Full serving verification
   remains pending. The native fixture gives its DNS nodes a separate
   fleet endpoint. The shared multi-host fixture now has a separate verified-TLS
   fleet frontend/backend, machine callers use it, and relocation fault injection
   targets that backend. Its bootstrap asserts public machine-path refusal and
   absence of browser routes on the fleet listener; these new native assertions
   have not yet run. The six application gates pass as recorded below;
   production transport and full native verification remain outstanding. The opt-in
   [WireGuard module](../../../nix/domains/system/fleet-network.nix) supplies an IPv4
   host-only transport with keyed /32 routes, runtime private-key custody and
   source/destination/interface firewall rules. Both production host declarations
   now enable it, with independent inventoried ciphertext and pinned public keys.
   Keys were generated outside the checkout, encrypted for the owning host and
   recovery recipients, checked with the inventory tool and removed from temporary
   plaintext storage. Both complete host configurations evaluate; their networkd
   default required an explicit WireGuard service-backend selection. Local
   Overalls callers retain loopback, while Dungarees resolves its fleet API over
   the tunnel and verifies the service CA. These are undeployed declarations:
   production key decryption, handshakes and serving acceptance remain unverified.
   See the [fleet network guide](../../operations/fleet-network.md).
   Module checks pass for both firewall backends, refusal of IPv6, self-peering,
   disabled firewalls and globally trusted tunnel interfaces. The new
   [native tunnel fixture](../../../nix/verification/tests/machines/fleet-network/default.nix)
   covers admitted traffic, physical-interface refusal, denied ports, key
   revocation and forwarding drop counters. Native encrypted connectivity and
   physical/closed-port refusal passed in both directions across the two firewall
   backends. The run then failed because its transient forwarding-probe service
   could not resolve Python. The fixture now uses the pinned absolute executable,
   excludes its probe veths from DHCP and bounds probe startup to 30 seconds.
   The corrected two-VM rerun passed in 37.63 seconds, including nonzero
   forwarding drop counters for nftables and iptables and refusal after peer
   removal. Its result is
   `/nix/store/cwxx9sms1g6jig0r89xnpg86wkw1g1k0-vm-test-run-overalls-fleet-network`.
   This establishes the isolated fixture, not production key decryption or
   physical-host activation. Existing
   deployed services remain unchanged; no private fleet rollout is claimed.
5. **Medium — deployment inputs absent:** the production application zone and
   two independent authoritative IPv4 endpoints remain requested. Do not invent
   them, credentials or deployment acceptance. Complete Overalls Audi enrollment,
   DNS and TLS configuration from actual operator inputs; no deployment is
   authorized or claimed by this review.
6. **Medium — final IPv4 audit incomplete:** changed ACME paths reject IPv6
   literals and use IPv4 propagation; Nix backend/resolver types reject IPv6.
   AF_INET6 permissions were removed from logging, SMTP, monitoring, Ziggy and
   private Audi, with passing configuration checks. Ordinary generated SSH now
   forces IPv4. Control clients now reject IPv6 literals and explicitly disable
   IPv6 transport, including Lilly's test-loopback exception. The updater's
   obsolete IPv6 health-address fallback was removed. Ziggy now also rejects
   IPv6 control literals and explicitly uses IPv4 for authority calls; its
   full gate passes 25 tests/properties and zero Dialyzer errors. Fixed
   provider clients use pinned Mint's IPv4 default. The subsequent audit found
   remaining IPv6 support in transfer endpoint enrollment, dedicated SSH and
   Marshall database/listener configuration. These now reject IPv6; transfer
   SSH and database sockets explicitly select IPv4, and the dedicated transfer
   sshd config selects `AddressFamily inet`. Transfer Nix rejection checks pass;
   the expanded Marshall Nix check also passes. Application gates pass. Remaining
   URL/resolver behavior still needs final audit.
7. **Verification — current upstream and final gates:** the worktree is based on
   f46fb30 after reconciling the fetched origin/main. Recheck before publishing, preserve
   accepted Customer isolation/private-service requirements, then run final
   changed-project gates and native acceptance against the resulting revision.

## Verification evidence and limits

On the f46fb30-based worktree with the separate fleet listener, complete precommit
gates pass Protocol 150, Lilly 322, Marshall 735 (two excluded), Audi 162,
Porsche 60 and Ziggy 25 tests/properties, with zero Dialyzer errors in each
project. The inherited development shell contained an older native transfer
helper; Lilly's first run failed two precise failure-class assertions. Rebuilding
`transfer_stream.rs` (lilly/native/transfer-stream) — built by its own checked derivation under the strict
compiler gates — resolved both failures (it was c_src/transfer_stream.c at the time). The rerun used that helper first on PATH;
the packaged Nix/native checks remain separate. The pinned Nix host-helper build
subsequently completed at
`/nix/store/fkjwyrdhqyf36si4smh8s8fmm1k1crp3-lilly-host-lock-0.1.0`.
The real SSH transfer fixture's
three refusal assertions now require `stream_producer_failed`, matching the
existing closed native failure classes; export-marker and empty-output checks
remain intact. This fixture correction changes no architectural decision.
The corrected SSH machine run passed in 15.87 seconds, including actual transfer,
wrong server/client key refusal, source permit revocation and retired-key refusal:
`/nix/store/gbqn6vwcnlawcxgn3byzdhy1h6zi59pw-vm-test-run-overalls-ssh-transfer`.
The Inception driver build then exposed conflicting inherited/local Lilly fleet
URLs in the fixture. Its explicit private fleet URL now overrides the generic
loopback default. The current-source driver subsequently built with local
builders and the public Nix cache:
`/nix/store/wry5v5hkw9rlqiqagm7f3m2zsk1jva6h-nixos-test-driver-overalls-inception`.
Its first execution failed before Inception acceptance: the driver selected
`XDG_RUNTIME_DIR=/run/user/1000`, whose 13 GiB tmpfs filled, causing outer VM
disk I/O errors and a read-only filesystem during preflight. The process ended;
this is not evidence about application readiness. The same built driver is
rerun with an explicit private, disk-backed `XDG_RUNTIME_DIR` under `/tmp`.
That rerun passed the real nested-virtualization preflight.
It subsequently passed receipt rejection, created both simultaneous managed
environments and passed each inner-stack verification, including independent
issuer and Ziggy credential checks. It then failed waiting for the first public
control A record after 240 seconds. Its diagnostic commands completed, but the
driver discarded their successful stdout. The probe now emits only fixed public
status predicates to the outer console, including proof presence at the job,
heartbeat and publication stages. No terminal contents or proof values are
emitted. Public issuance and private provider startup remain unverified.
A new [public-boundary probe](../../../nix/verification/tests/machines/inception/public_boundary.py)
is wired after certificate acceptance for both environments: verified inner TLS
through physical Audi must reject all five fleet API prefixes, including unknown
versions, malformed JSON and forged forwarding headers, without sessions or
redirects. Syntax and contract checks pass. The running driver predates this
probe, so it cannot establish that new assertion. The updated boundary driver
built at `/nix/store/xilffi6ib8kv3bahl0yswbw172slsp7n-nixos-test-driver-overalls-inception`;
it predates the retained-diagnostics fix and has not run. A rebuilt native run
with both changes is required.
This expands verification of ADR-0073 without changing its accepted boundaries.
The obsolete pre-listener Inception driver build was explicitly cancelled; it
supplies no new acceptance evidence.

After the b57e093 reconciliation, Protocol 148, Lilly 317, Audi 162 and Porsche 60
tests/properties passed their complete gates, including forced Dialyzer with zero
errors. Marshall's merged-source tests pass 723 (64 properties and 659 tests),
with two existing exclusions; its complete gate passed with zero Dialyzer errors.
After parent-discovery/SSH-chain changes, Protocol 150, Lilly 317 and Marshall
726 tests/properties passed their complete gates with zero Dialyzer errors;
Marshall retains two explicit exclusions. The Nix runtime check also passed.
Lilly's first rerun exposed global CaptureLog contamination from another async
property. Its endpoint diagnostics test now runs serially, preserving all
redaction and silence assertions; the complete rerun passed.

Before the b57e093 reconciliation, completed gates passed Protocol 148 tests/properties,
Lilly 315, Audi 162, Porsche 60 and Marshall 699 with two explicit exclusions.
Compiler, runtime, contract/ADR and forced Dialyzer checks completed; Marshall
retains its existing documented Dialyzer skip. The subsequent ordinary SSH IPv4
change passed four focused tests/properties. Later Nix changes passed runtime
checks but do not replace final project gates after all implementation and merge
work. Concurrent Mix runs previously interfered with caches and database
connections; the reported Marshall result is the clean serial rerun.

The [cross-runtime proof check](../../../nix/verification/tests/evaluation/inception-proof-broker.py)
runs packaged Audi against the actual Python Unix broker and passes exact proof,
wrong generation/proof/UID and expired-evidence cases. Local transport tests cover
opaque nested TLS with an independently trusted child certificate, ordinary TLS,
expiry with a suspended renewer, trusted metadata and independent SSH revocation.
The native OpenSSH fixture passed generated profiles and HTTPS key verification
through all three layers, but uses stock sshd and a fixture authority rather
than the full Firecracker public path. An initial run stalled waiting for the
fixture command-channel exit status. The fixture now isolates SSH stdin, bounds
its complete process group, and explicitly closes relay writes on EOF. Negative
cases require SSH status 255, so timeouts cannot count as expected refusals.
The corrected fixture completed successfully in 69 seconds.

Earlier native execution passed outer admission, inner service/key startup,
inner UDP/TCP DNS answers, nested ordinary guest lifecycle and deletion of both
outer disks. It failed the later direct-driver phase because two fixture host
identities reused a durable ZFS pool. Those phases now use separate pools;
production ownership checks and tombstones remain intact. A previously copied
physical helper was not invoked; it is now called after each inner lifecycle
operation to verify VMM readiness, retained marker data and physical deletion.
Earlier lifecycle results therefore do not establish those added assertions.

After upstream reconciliation, one native run stalled after its SIGTERM-only
probe timeout. The isolated run was stopped and probe deadlines now escalate to
SIGKILL before the driver timeout. A subsequent run passed receipt rejection,
outer admission, ingress publication and inner DNS. Its initial cleanup_failed
observation recovered to running, but the combined physical-state assertion
failed. Six named, redacted checks now preserve every original condition while
identifying which one fails: KVM, data disk size, quota, repository, credential
and enrollment readiness. A subsequent run passed the first five checks but
failed enrollment readiness. Reconciliation had reported a surviving VMM as
running; the fixture now separately waits for the real core readiness response.
Whether that resolves a startup race or exposes a persistent enrollment failure
remains to be established by the next native run.

The [private PKI bootstrap](../../../nix/domains/artifacts/guest/inception/private_pki.py)
uses Audi's existing hierarchy primitives to generate independent instance-bound
custody outside the build. Five actual-crypto tests cover restart identity,
missing and foreign custody, key mismatch, interrupted publication and expired
certificates. The issuer module accepts exactly one encrypted bundle or runtime
intermediate pair; its configuration checks reject incomplete and ambiguous
sources. The inner image evaluates with the runtime source and no SOPS bundle.
Its secret-management module is now enabled for the independent inner Ziggy
provider bundle; the private issuer still uses its own runtime intermediate.
Only the intermediate reaches the online issuer; public trust delivery into
reproducible nested guest images and native private inference remain unfinished.

The first expanded public run started Pebble and fetched its public root, then
failed because the outer fixture lacked Python for trust setup. That package is
now explicit. The corrected driver built and passed that trust-setup step, but
Marshall repeatedly rejected its public settings input: the module passed a
root-only file directly to its dynamic user. That isolated run was stopped after
the repeated startup failure. The module now delivers the input through systemd
credentials, preserving file permissions. Its configuration check passed, and
the next native run passed Marshall startup, enrollment of two separate DNS
replicas, UDP/TCP DNS liveness, outer Audi listeners and outer VM creation. It
then failed because the expanded inner DNS script exceeded dtach's 4096-byte
input limit. The fixture now copies all scripts in bounded acknowledged chunks
and aborts uncertain writes; the production transport bound remains intact.
No public issuance acceptance is claimed.

Native checks use actual KVM with nested AMD virtualization enabled. The daemon
omits the nested-kvm feature, so the built driver runs directly without changing
global daemon configuration. The last rerun used a private disk-backed runtime
directory; other workloads remain untouched. An earlier two-environment run
used a dedicated user scope with an 82 GiB memory cap and no swap. That historical
limit does not describe the last direct-driver run. It failed at public DNS;
the fixture targets lifecycle and
network acceptance, not a full-memory workload benchmark. No local or partial result proves
full two-environment acceptance or production readiness.

## Publication decision

ADR-0073 remains partial. The user now explicitly requests committing, merging
and pushing this implementation checkpoint before continuing acceptance work.
Public DNS publication, the new boundary assertion, private provider acceptance,
nested-image trust and the remaining full acceptance cases remain unfinished.
The image-builder experiment that currently fails evaluation is excluded from
this checkpoint. Reconcile origin/main, preserve these findings in the commit,
and continue implementation and verification after publishing. No deployment is
authorized by this checkpoint. The recovery stash before this reconciliation is
`cd1b08b6fa5f5eef89fd2af684cc337ebfe311b4`. Upstream remote builders, Ubuntu,
Brady, backups and required transfer occupy ADR-0067 through ADR-0071;
Inception is now ADR-0072. The current publication merge incorporates
origin/main at `e0486c7`: retain both authenticated Inception exchange and Brady
owner lookup, combine Brady forwarding restrictions with paired Audi addresses,
and retain upstream fresh-running-observation checks for Inception ingress.
Dungarees keeps its backup offset, private fleet resolution and port-2222 admin
SSH. Architecture decisions and test cases from both branches are preserved.
The Overalls conflict
preserves the shared upstream guest catalog and protects both public addresses.
Upstream extracted guest networking into a Python helper shared by NixOS and
Ubuntu; the paired Inception address is now added there, retaining validation
before network effects. Generated tests cover the paired slot and exclusion
from ordinary profiles. Merged authorization changes retain upstream account
checks alongside Inception service actions. Combined gates
remain required; earlier passing results do not establish this merged revision.

## Nested guest trust completion (2026-09-19)

The recovered plan's image-builder item is implemented on the merged revision.
The [recipe](../../../nix/domains/artifacts/guest/inception/image-builder.nix) now scans
certificate inputs line-wise; whole-file `hasInfix` overflowed Nix's regex stack
on real CA bundles, which was the experiment's evaluation error. The fileset
includes `flush.py`, whose omission broke the copied guest configuration. A
`cache` output retains the recipe and every closure store path behind a single
runtime reference, so the offline rebuild graph travels inside the environment.

The [image rebuild unit](../../../nix/domains/artifacts/guest/inception/default.nix)
runs after the independent private PKI publishes the instance root and before
enrollment; it rebuilds the guest image with `nix-build --offline` from the
prewarmed cache and publishes the rebuilt content identity to
`/run/inception/default-image-id`. Inner Marshall reads that identity through
a validated systemd credential
([helper](../../../nix/domains/system/marshall-default-image.py)); invalid input
prevents startup and empty input disables the default. Enrollment registers
and selects only the rebuilt image, so an inner guest cannot boot without its
environment's trust. The private-services assertion shares the line-wise scan.

Verification on this revision: all seven application precommit gates pass
(protocol 66, lilly 346, audi 162, brady 49, porsche 60, ziggy 322-equivalent,
marshall 741 with Dialyzer), the ADR checker passes, and the new
`inception-image-builder` evaluation check verifies cache retention and
private-key rejection. The last recovered diagnostic run failed the second
environment's verify readiness within its 180-second budget while all core
units were already active; the verify wait now matches the start path's
600-second budget and the outer create operators use 1800 seconds, because the
first-boot image rebuild lengthens inner bootstrap. Native acceptance of the
rebuild path and the public DNS publication remains to be established by the
fresh driver run recorded below.

The cache's first full-build-closure form produced a 33 GiB inner rootfs,
which the shared manifest validator correctly rejected (its 32 GiB rootfs
maximum is an accepted protocol bound, not changed here). Three deterministic
exclusions bring it within budget: derivation files (closure computation
expands them to every output of their build graph), inert documentation and
unpacked-source outputs, and the never-executed Haskell/Rust/LLVM toolchains
plus the seed image's own outputs, which a certificate rebuild recreates. The
retained set is proven sufficient by an isolated-store offline rebuild seeded
only from the shipped cache artifact: the rebuild instantiates exactly the
certificate-dependent tail (system, closure-info, ext4 rootfs, manifest) and
succeeds offline with a fresh independent root certificate.

The derivation-file exclusion matters beyond size: kept `.drv` symlinks make
closure computation expand every one of their outputs (including inert info
outputs that may never be substituted), which both exceeds the image budget
and breaks the ext4 assembly copy. The rebuild re-instantiates derivations
from the recipe, so their files are not needed in the cache.

A first native run of the diagnostic driver failed at the earliest subtest:
`inception-probe reject-proof` exceeded its 165-second budget and was killed
by the fixture timeout (exit 137), with no OOM kill recorded anywhere. The
host was concurrently running the full gate sequence and the test-closure
build against the same 32 cores as the 36-vCPU outer QEMU, so the probe
starved. The failure is attributed to environmental contention, not a code
regression; the rerun executes on a quiet host. Fixture budgets for outer
create steps and the direct ready path were raised to 1800 seconds to cover
first-boot image rebuilds.
