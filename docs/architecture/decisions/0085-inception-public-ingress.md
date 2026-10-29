# ADR-0085: IPv4 service separation and public Inception ingress

- ID: ADR-0085
- Date: 2026-09-18
- Status: superseded
- Implementation: partial
- Components: Audi, Marshall Ingress, Lilly network and VM, protocol, Nix
- Supersedes: ADR-0054
- Superseded by: ADR-0105, ADR-0199

## Context

[ADR-0199](0199-memory-suspension-and-demand-wake.md) replaces only the
memory-migration/stopped-source and cross-host-relay prohibitions where this
record carries them, and extends owner pins with automatic-suspension prevention
and wake. Unrelated requirements and historical rationale remain in force.


ADR-0105 supersedes the public certificate custody and nested hostname/TLS
shape in this record. Its independent child authentication and isolation
requirements continue to apply; the implementation evidence below is historical
until the new public wildcard path is complete.

The user authorized implementing public Audi and full single-layer Inception,
with Audi on an additional physical IPv4 address, Porsche alongside Marshall,
no IPv6 and no compatibility requirement. Overalls retains OVERALLS_PRIMARY_IPV4/26 for
control and administration and adds OVERALLS_SERVICE_IPV4/26 for Audi, using gateway
OVERALLS_GATEWAY_IPV4. Public IPs are shared by environments; each environment does not
receive its own public IP. Work starts from origin/main in an isolated worktree.

## Decision

Carry forward ADR-0054 and its inherited decisions except its exclusion of
Inception Audi/Porsche and public browser ingress. Support exactly one Inception
layer creating ordinary guests. Inception relocation remains unavailable.
Preserve [ADR-0064](0064-customer-workspace-isolation.md)'s Customer isolation and
its inherited private-service requirements. Nested service admission must not
restore Customer web access or egress.

Keep Erlang distribution disabled. Cross-host control uses authenticated HTTPS
and the shared PostgreSQL authority; guest ingress remains host-local through
Lilly's fenced connector. ZFS replication retains the separate restricted
OpenSSH transfer service and per-transfer authority, not administrative SSH.

Marshall machine APIs use a separate IPv4 HTTPS listener. The public browser
listener refuses their reserved paths, regardless of supplied credentials or
forwarding headers, while retaining current public SSH host-key discovery.
Colocated services use verified loopback HTTPS. Cross-host fleet connectivity
uses an IPv4 WireGuard host network with explicit peer keys, /32 routes and
interface-scoped firewall policy. HTTPS and purpose-bound credentials remain
mandatory inside the tunnel. No guest subnet or forwarded guest traffic enters
this transport; the browser frontend must never act as its fallback.

Use explicit IPv4 listener addresses and destination-specific firewall rules.
Reject IPv6 configuration. Readiness must probe the actual listener address.
Distinct explicit addresses may reuse ports; wildcard overlaps must fail.

An Inception guest uses one virtual NIC with two private IPv4 identities: its
control address and a separate Audi address. Reserve, retain, route, fence and
release both as one placement. The guest cannot choose another environment's
address. This does not permit direct communication between guests.

Outer Marshall owns immutable environment namespaces and fixed nested service
kinds (control HTTPS, Porsche SSH, Audi HTTPS and SSH), bound to placement,
execution epoch and service generation. A separate bounded, versioned vsock
exchange delivers configuration and publishes child state through the owning
Lilly. Do not share parent credentials with the child or reuse SMTP's channel.

The parent publishes bounded child A/TXT records in its authoritative snapshots.
A records reference the physical Audi address; private guest addresses never
become public delegation targets. DNS queries never make synchronous control
calls. Publish ACME proofs before requiring certificate readiness. The child
owns its certificate keys and independently authenticates its users.

Audi routes nested TLS by the assigned namespace before TLS termination, through
an authorized local connector. Inner Audi terminates TLS, preserving its login
callbacks and cookies. Forward client identity only over a trusted connector
protocol. SSH uses explicit bounded service selectors and verifies host keys at
each layer without agent forwarding. Parent namespace permission does not imply
membership in the inner deployment. No peer may select arbitrary destinations.

Both layers independently expire stream authority. Stopping or revoking an
ancestor closes descendant streams. The full inner image includes PostgreSQL,
Marshall, Lilly, Porsche, Audi and DNS with unique durable identities. Inception administrative access remains the authenticated console; Audi and
Porsche are application gateways, not root SSH. Their explicit console-only Nix
mode forbids administrative OpenSSH, while physical-host defaults retain the
2222 administrative SSH prerequisite. Split core
bootstrap from public readiness so certificates and namespace publication cannot
deadlock initial execution readiness. Preserve developer edits and data.

## Alternatives

Distributed Erlang does not replace service authentication or placement fencing.
A second NIC adds a device without establishing isolation; the required boundary
is address allocation and enforcement. Generic HTTP proxy chaining would consume
inner login paths/cookies. Public NS delegation to private addresses cannot work.
Unbounded recursion and cross-host guest relays are outside the authorized scope.

## Consequences

This requires coordinated protocol, authority, network and image changes. A
partially updated fleet must not expose nested services. Live public acceptance
also requires the operator's DNS zone, two independent authoritative endpoints
and runtime credentials; these must never be fabricated as production defaults.

## Invariants and verification

- Test explicit IPv4 binds, wildcard collisions and both firewall backends.
- Verify both private addresses are fenced across stop/start, failure and deletion.
- Reject stale, forged, cross-environment and unbounded vsock publications.
- Exercise two concurrent Inception environments through public browser and SSH
  paths, independent authentication, WebSockets, certificate issuance and DNS.
- Verify restart, expiry, revocation, namespace isolation and IPv4-only operation.
- Run changed project precommit gates, contract checks, ADR validation and native
  Nix machine checks. Unit/evaluation results do not establish native acceptance.

## Implementation evidence

The [2026-09-22 completion audit](../reviews/2026-09-22-inception-completion-audit.md)
updates the earlier
[reconciliation checkpoint](../reviews/2026-09-18-inception-public-ingress.md).
The later native run confirmed the dedicated 1028 vsock listener and namespace,
then found the offline nested image rebuild still starting when the former
ten-minute core readiness wait ended. A rerun also exhausted the twenty-minute
wait while the image unit was still starting. Lilly now allows a bounded
forty-minute Inception core wait while preserving the separate SMTP delivery
bound; completion within that window remains unverified.
The nested image builder passes pure flake evaluation, retains the evaluator
sources required by its offline runtime recipe and has separate-public-trust
rebuild evidence. The focused Marshall, Lilly, protocol and Nix checks pass.
Native acceptance remains incomplete; the browser and WebSocket fixture has
been added but has not passed natively, and nested SSH, revocation and
spoof-isolation acceptance are still missing. Earlier historical
test results below do not establish acceptance of the current tree.

[Public settings](../../../protocol/lib/overalls_protocol/inception_public.ex)
carry only bounded operator issuer/trust/DNS configuration and explicit consent
through authenticated parent offers and the boot-bound vsock exchange. Nil leaves
certificate/DNS setup disabled. The [guest validator](../../../nix/domains/artifacts/guest/inception/public_settings.py)
shares a rejection corpus with the protocol library. Changes to this public trust
configuration require a new guest boot; they cannot silently replace a running
instance's trust. The [inner DNS unit](../../../nix/domains/artifacts/guest/inception/dns.nix)
uses its own enrolled DNS token and verified local Marshall snapshots, listens on
IPv4 loopback, and supplies no public delegation. Its native startup and actual
UDP/TCP response checks passed in the native fixture. That run also passed nested
guest create/stop/start/delete and outer disk deletion, but failed a later direct
fixture phase because two host identities reused one ZFS pool. Separate fixture
pools preserve the production ownership check; the full run still needs to pass.

[Parent proof observations](../../../lilly/lib/lilly/inception/propagation.ex)
query only operator-configured IPv4 authoritative endpoints, checking exact TXT
sets with bounded concurrency and deadlines. The
[child receiver and local broker](../../../nix/domains/artifacts/guest/inception/observations.py)
fence evidence to its original boot, generation, single-use offer and publication
lifetime. The root-owned Unix socket returns remaining duration to
[inner Audi](../../../audi/lib/audi/acme/observed.ex), which verifies the peer UID
and anchors that duration to its own request start. This avoids comparing Python
and BEAM monotonic clock epochs. Missing evidence never falls back to direct DNS.
Lilly's 311, Marshall's 683 and Audi's 158 tests/properties passed their precommit
gates; Marshall retains two exclusions and its existing Dialyzer skip. Python
broker/runtime checks passed. Inner Audi TLS is wired to this evidence, but real
issuance through two independent replicas, control TLS and the complete public
native acceptance remain unverified or unfinished.

The [control proof hook](../../../nix/domains/artifacts/guest/inception/control_proofs.py)
now limits updates to the assigned control DNS-01 owner, a current random job
nonce and one non-renewable ten-minute deadline. Its five-second publication
heartbeat cannot extend that job; generation/boot changes and delayed cleanup
fail closed. Five [runtime checks](../../../nix/verification/tests/evaluation/inception-control-proofs.py)
passed, including actual parent evidence reads and expiry. The hook is not yet
wired to the certificate worker or proxy and does not establish issuance.

The [HTTP front](../../../audi/lib/audi/http/front.ex) redirects canonical
single-layer Inception names inside its configured zone without requiring the
parent to possess an inner certificate. Redirects grant no authority; the opaque
TLS path still acquires current stream authority. Real socket tests cover control,
workload and alternate-port names, with unrelated and recursive names rejected.
The ACME propagation client uses only
IPv4 TCP. ACME signed URLs reject IPv6 literals, and HTTP challenge lookup rejects
all-IPv6 endpoint configurations before creating a client. Nix proxy backend and
recursive resolver options also reject IPv6 literals.


[Listener configuration](../../../nix/domains/system/audi.nix) now permits explicit
IPv4 TLS binds and distinct Audi/Porsche addresses on the same SSH port.
[Firewall rendering](../../../nix/domains/system/listener-firewall.nix) scopes explicit
listeners by destination, with regression cases in the
[Nix evaluation](../../../nix/verification/tests/evaluation/audi.nix).
[Readiness construction](../../../audi/lib/audi/application.ex) uses the configured
address, covered by [configuration tests](../../../audi/test/config_test.exs).
Audi's 137 tests and forced Dialyzer passed. Nix Audi and module evaluations and
Overalls assertions passed; these are not live listener evidence.
[Paired allocation](../../../protocol/lib/overalls_protocol/address_pool.ex),
[TAP route ownership](../../../lilly/lib/lilly/network.ex),
[source guards](../../../lilly/lib/lilly/network/policy.ex) and
[guest setup](../../../nix/domains/artifacts/guest/configuration.nix) derive both addresses
from the same reservation. Protocol (119 tests/properties) and Lilly (296)
precommit gates, including Dialyzer, passed. Native paired-address verification
remains outstanding.
[Environment resources](../../../marshall/lib/marshall/ingress/environment.ex)
now persist immutable labels during VM admission, with audit history and internal
mutation authorization. Eleven targeted admission/endpoint tests passed against
an isolated PostgreSQL database. The
[namespace parser](../../../protocol/lib/overalls_protocol/inception_name.ex) and
[boot-bound publication codec](../../../protocol/lib/overalls_protocol/inception_exchange.ex)
reject arbitrary destinations, DNS delegation, stale polls and oversized input.
The expanded protocol precommit gate passes 126 tests/properties and Dialyzer.
The [Lilly poller](../../../lilly/lib/lilly/vm/inception_exchange.ex) now frames
requests on separate vsock port 1028 (1026 belongs to the guest backup flush
service), imposes a single deadline and correlates
replies. Its socket tests and full Lilly gate, including Dialyzer, passed. The [guest receiver](../../../nix/domains/artifacts/guest/inception/ingress.py) validates
CID 2, the kernel boot binding, canonical origins and monotone generation, and
refuses stale child snapshots. Its [Nix runtime check](../../../nix/verification/tests/evaluation/inception-runtime.nix)
passes all 21 tests. The [driver entry](../../../lilly/lib/lilly/vm/driver.ex)
checks the same owned confined boot before and after the exchange. Lilly's 298
tests/properties and Dialyzer pass. Marshall's full gate passes 665 tests/properties
and Dialyzer with its existing documented upstream exclusion. [Parent offers](../../../marshall/lib/marshall/ingress/environment_publications.ex)
now authenticate the current host session and lock the VM before issuing a
single-use five-second offer. Acceptance retains its original expiry and rejects
stale execution, session, generation and replay. The dedicated
[publication resource](../../../marshall/lib/marshall/ingress/environment_publication.ex)
and migration persist observations separately from audited environment policy.
[Recurring Lilly polling](../../../lilly/lib/lilly/inception/runtime.ex) runs at
most sixteen independent placement tasks and stops with the control runtime.
The real HTTPS client/API path and eight targeted Inception tests pass. Marshall's post-DNS gate passed 666 tests/properties and Dialyzer.
The [parent DNS projection](../../../marshall/lib/marshall/ingress/publications.ex)
now consumes current nested publications and rewrites addresses from parent
services. Bootstrap proofs do not require completed startup; A records do.
[Inception tests](../../../marshall/test/marshall/compute/inception_test.exs)
verify projection and stale-binding suppression, while
[Audi DNS tests](../../../audi/test/dns_server_test.exs) cover nested names over
UDP/TCP, proof expiry, bounded TTLs and IPv4-only answers. Stream consumption,
public TLS/SSH routing, complete inner image and native acceptance remain
unimplemented. The [connector codec](../../../protocol/lib/overalls_protocol/ingress_connect.ex)
now admits a distinct version 2 for fixed nested services and environment
generation. [Local targets](../../../lilly/lib/lilly/network/ingress.ex) derive
paired addresses and fixed ports only for Inception. Actor/executor checks reject
ordinary profiles. [Connector tests](../../../lilly/test/ingress_execution_test.exs)
exercise real Unix streams and stop-intent closure with a loopback executor;
physical guest routing and parent environment revocation remain unverified.
The [nested authority check](../../../marshall/lib/marshall/ingress/environment_authority.ex)
requires current environment/publication bindings and service readiness or SSH
host key, with expiry capped at publication lifetime. The [stream resource](../../../marshall/lib/marshall/ingress/environment_stream.ex)
and [coordinator](../../../marshall/lib/marshall/ingress/environment_streams.ex)
now preserve gateway, host-session, execution, environment and host-key bindings
across renewal, with capacity limits and bounded retention. Their generated
migration creates the new stream/audit tables and constraints. The closed
[wire codec](../../../protocol/lib/overalls_protocol/nested_stream.ex), API and
Audi client pass real HTTPS open/renew/close tests; expired/closed or revoked
bindings fail. [Audi's nested guard](../../../audi/lib/audi/inception/authority.ex)
independently closes socket owners when renewal is suspended. The [TLS frontend](../../../audi/lib/audi/inception/front.ex) now selects nested
names before termination and uses this grant/guard/connector path. Ordinary names
upgrade the original socket with their selected current certificate and continue
through Bandit's existing HTTP/1 handler. A bounded ClientHello parser preserves
fragmented records. [Frontend tests](../../../audi/test/inception_front_test.exs)
verify the inner certificate over a real opaque TLS relay and close both ends on
parent denial; ordinary TLS tests cover SNI/Host behavior. The [IPv4 metadata codec](../../../protocol/lib/overalls_protocol/proxy_header.ex)
uses the fixed TCP/IPv4 subset of [PROXY v2](https://www.haproxy.org/download/3.0/doc/proxy-protocol.txt).
Audi supplies the actual client endpoint through its authenticated Unix connector;
Lilly derives the destination and prepends the header before nested HTTPS. The
[inner peer check](../../../audi/lib/audi/inception/peer.ex) accepts headers only
from its configured parent address and requires the socket's exact destination.
Public listeners do not parse metadata. Same-address local readiness probes retain
their actual identity.

[SSH selector admission](../../../audi/lib/audi/ssh/request.ex) now accepts the
fixed nested Porsche/Audi commands after OTP signature proof. The
[control backend](../../../audi/lib/audi/ssh/control_backend.ex) obtains and renews
parent namespace leases; the independent channel guard binds both execution and
the published inner host key. [Transport tests](../../../audi/test/ssh_transport_test.exs)
exercise two real SSH listeners with distinct user keys, strict host checking,
incorrect inner-key refusal, and inner revocation closing the descendant stream.
[Marshall integration](../../../marshall/test/marshall/compute/inception_test.exs)
exercises the real backend over verified HTTPS and refuses renewal after key
publication disappears. These tests use local connector fixtures, not guest VMs.
[Nested key discovery](../../../marshall/lib/marshall/ingress/environment_discovery.ex)
now checks current publication/execution under gateway-before-host/VM locks and
returns only current listener identities. The HTTPS endpoint emits non-cacheable
known-host lines. The following profile evidence is historical: the
[2026-09-25 retirement](../reviews/2026-09-25-ssh-config-download-retirement.md) removed the download and renderer,
retaining test-only profiles in the native fixture. The authenticated SSH download selected two
fixed-service profiles
for Inception, with independent current HTTPS key checks at both layers, IPv4,
and no forwarding or multiplexing. The
[native OpenSSH fixture](../../../nix/verification/tests/machines/audi-openssh/default.nix)
passed generated-profile execution, wrong outer/inner key, HTTPS trust, response
status and size-limit cases. It uses stock sshd and a fixture key publisher, not
Firecracker or production Marshall authority. Ordinary inner workload profiles
now add a third SSH layer using the same fixed Audi selectors. Closed
[parent discovery metadata](../../../protocol/lib/overalls_protocol/inception_parent.ex)
comes from the parent operator endpoint through the authenticated offer and
boot-bound receiver; it cannot change within a boot. The inner SSH download
requires its assigned namespace and uses fresh parent HTTPS key discovery for
both Audi hops, while retaining independent guest host-key files. Generated
three-layer OpenSSH execution now passes through the actual generated profile,
including current-key refusal at both Audi layers and independent guest trust.
The fixture uses stock sshd and a controlled HTTPS publisher; full native
two-environment acceptance remains outstanding.
No end-to-end Inception or production deployment is claimed.

The [namespace receiver](../../../nix/domains/artifacts/guest/inception/ingress.py) now
materializes the assigned control hostname and app zone as private runtime inputs.
[Marshall's module](../../../nix/domains/system/marshall.nix) accepts a separately loaded
hostname credential, validates canonical DNS syntax, and refuses invalid input
without static fallback. The inner unit waits for namespace inputs independently
of certificate issuance. Python/runtime and module configuration checks passed;
this is not evidence of a completed inner public bootstrap. The ACME HTTP-01
responder now rejects IPv6 settings using the shared IPv4 type.

The [inner Porsche unit](../../../nix/domains/artifacts/guest/inception/porsche.nix)
loads a local gateway credential and persistent Ed25519 identity into an
unprivileged IPv4-only application service. Its
[configuration producer](../../../nix/domains/artifacts/guest/inception/roles.py) binds the
current control address and assigned browser origin while keeping control calls
on verified local HTTPS. The
[bootstrap](../../../nix/domains/artifacts/guest/inception/porsche.exs) uses the dedicated
[ensure operation](../../../marshall/lib/marshall/operations/ssh_gateway.ex):
restart cannot rotate or revive authority. Audi's corresponding
[service ensure action](../../../marshall/lib/marshall/ingress/services.ex)
also requires unchanged role, host, credential and normalized addresses; mismatch
leaves identity and audit history untouched. Regression tests cover both gateway
and DNS roles. Porsche's precommit and the Nix runtime check passed; the inner
image evaluates. Native startup, publication and full public readiness still
require integration and acceptance testing.

The [inner publication worker](../../../nix/domains/artifacts/guest/inception/publication.py)
now projects a bounded current DNS snapshot from verified local IPv4 HTTPS into
private, monotonic-expiry vsock input. It drops child addresses, rejects recursion
and overflow, and checks the independent current Porsche/Audi credentials before
publishing their locally owned canonical host keys. Control-certificate proofs
have a separate boot/generation/expiry-bound input and may precede readiness.
[DNS identity bootstrap](../../../nix/domains/artifacts/guest/inception/dns.exs) uses its own
private token and the non-rotating ensure action. Namespace installation and
publication replacement share a lock and recheck configuration. The child reply
carries remaining TTL; parent authority caps it from original offer creation so
forwarding cannot refresh nearly expired state. Namespace allocation reserves
space for the longest DNS-01 challenge name, including a complete workload label.
The worker and bootstrap are included in the inner image. Inner DNS startup and
UDP/TCP answers passed in the native fixture. Audi TLS is wired to parent proof
observations but awaits native issuance. The
[control certificate worker](../../../nix/domains/artifacts/guest/inception/control_worker.py)
and [service wiring](../../../nix/domains/artifacts/guest/inception/control.nix) now connect
independent account state, the bounded parent-proof hook, validated certificate
custody and a separate unprivileged proxy. Isolated
[live proxy tests](../../../nix/verification/tests/evaluation/inception-control-tls.py) verify
original-source enforcement before PROXY parsing, forwarding-header replacement,
certificate reload and survival of an existing upgraded connection. Nix service
evaluation passed. Actual public issuance and Firecracker acceptance remain
outstanding; these local checks do not establish complete public bootstrap.

Control proof acceptance uses the same strictly-unexpired rule as inner Audi.
The five-second producer heartbeat leaves room for authenticated parent exchange
and bounded authoritative observation under native pool contention. The original
job expiry, boot/generation/proof checks and parent offer expiry remain binding;
the heartbeat cannot renew authority. The runtime gate exercises real-file
evidence near expiry. Native issuance remains unverified.

The [inner Audi unit](../../../nix/domains/artifacts/guest/inception/audi.nix) now has a
separate private credential and persistent Ed25519 identity. Its
[bootstrap](../../../nix/domains/artifacts/guest/inception/audi.exs) ensures the inner host
binding with the paired private Audi address. The
[inner enrollment](../../../nix/domains/artifacts/guest/inception/enroll.exs) enables Lilly's
restricted connector for the actual deployed Audi UID; group access alone grants
no connector authority. This wires SSH startup, not completed public TLS. Child
DNS addresses remain local to the inner deployment and are discarded by the
parent projection. The [TLS probe](../../../audi/lib/audi/tls/probe.ex) now accepts
the configured local IPv4 listener, binds its own connection to that address,
and rejects remote, wildcard and IPv6 destinations. Unprivileged Audi units
permit local Netlink interface discovery without CAP_NET_ADMIN or IPv6 sockets.

The [independent private PKI bootstrap](../../../nix/domains/artifacts/guest/inception/private_pki.py)
now generates and validates durable, instance-bound root/intermediate custody
using Audi's existing primitives. Its
[inner issuer wiring](../../../nix/domains/artifacts/guest/inception/private.nix) delivers
only the intermediate through systemd credentials, without parent keys or an
encrypted parent bundle. Actual-crypto custody tests and Nix configuration checks
pass; the inner image evaluates. The
[inner Ziggy enrollment](../../../nix/domains/artifacts/guest/inception/ziggy.exs) persists
its own token before calling the
[non-rotating coordinator](../../../marshall/lib/marshall/inference/credentials.ex).
Six database tests verify unchanged expiry on retry and refusal of revoked,
expired, mismatched or unauthorized authority. Bootstrap runs only after native
host enrollment enables the inner host. The
[native enrollment probe](../../../nix/verification/tests/machines/inception/inner_ziggy.exs)
has not yet run. The [inner Ziggy service](../../../nix/domains/artifacts/guest/inception/ziggy.nix)
now uses the [shared hardened unit](../../../nix/domains/system/ziggy-service.nix), its
own SOPS provider document and systemd credential snapshots. Fixed local runtime
configuration and closed provider selection pass four tests, the Nix runtime
gate and the physical Ziggy configuration check; the updated inner image
evaluates. No parent provider keys or placeholder defaults are supplied.
The [private Audi wiring](../../../nix/domains/artifacts/guest/inception/private.nix)
reuses the [physical renewal/frontend services](../../../nix/domains/system/audi-private-services.nix).
It authenticates with the inner Audi identity and issuer and enters only the
enrolled Lilly namespace through a root-owned runtime link. Five tests verify
fixed inner authority, stable namespace binding and refusal of foreign links or
disabled private networking. The runtime/PKI/configuration gates pass and the
image evaluates. Inner Lilly now enables its private connector/network and
requires private readiness before new guest execution. Native issuer/frontend
startup, reproducible nested guest trust and provider acceptance remain open.

The [nested guest image rebuild](../../../nix/domains/artifacts/guest/inception/image-builder.nix)
is now wired end to end. Its recipe rejects private-key material before any
store copy, and a prewarmed [offline cache](../../../nix/domains/artifacts/default.nix)
retains the full build closure in the inner system. The
[image rebuild unit](../../../nix/domains/artifacts/guest/inception/default.nix) rebuilds
the guest image from the instance's public private-service root before
enrollment, and
[enrollment](../../../nix/domains/artifacts/guest/inception/enroll.exs) registers and
selects only that rebuilt image. Inner Marshall receives the rebuilt content
identity through a validated runtime credential
([runtime default image](../../../nix/domains/system/marshall-default-image.py))
instead of a build-time default; empty input disables the default and invalid
input prevents startup. The
[evaluation check](../../../nix/verification/tests/evaluation/inception-image-builder.nix)
verifies cache retention and private-key rejection. First-boot rebuild inside
the environment remains to be exercised by the native acceptance run.

The physical fleet now applies this record's explicit-address rule on both
hosts: Dungarees binds its Audi gateway and DNS listeners to its additional
`DUNGAREES_SERVICE_IPV4` address exactly as Overalls uses `OVERALLS_SERVICE_IPV4`, and both
hosts configure the two independent authoritative DNS endpoints over the
delegated `apps.ghuntley.dev` subzone with per-VM TLS issuance against a
staging issuer
([Overalls](../../../fleet/roles/control-plane/services.nix),
[Dungarees](../../../fleet/hosts/dungarees/configuration.nix); placement and
perimeter amendments in
[ADR-0090](0090-second-audi-dns-replica-on-worker.md) and
[ADR-0091](0091-fleet-perimeter-public-listeners.md)). Both host
configurations evaluate with their assertions; live delegation, real
credentials and public issuance remain outstanding, so this is configuration
evidence, not live acceptance.

## Open questions

The public application DNS zone and independent authoritative deployment inputs
are required for live acceptance. They do not block implementation or fixtures.

## Related decisions

[ADR-0054](0054-inception-development-profile.md),
[ADR-0052](0052-fenced-local-guest-ingress.md),
[ADR-0047](0047-audi-ingress-and-authoritative-dns.md),
[ADR-0048](0048-single-host-service-deployment.md),
[ADR-0012](0012-provisioner-control-transport.md).
