# GitHub.com integration

The accepted `github-com` provider connects one Marshall user to their GitHub
account and exposes it at `https://com-github.integration.internal`. See
[ADR-0202](../architecture/decisions/0202-github-com-owner-integration.md) for its
authority and lifecycle. Implementation and execution evidence remain partial in
the [review](../architecture/reviews/2026-10-18-github-com-integration.md).
Safe GitHub `Link` pagination headers are retained and rewritten to the private
endpoint, so managed API clients can follow pagination without learning an
upstream hostname.

## Connect and use

Open the signed-in Integrations page and connect GitHub.com. Marshall starts
OAuth through a CSRF-protected POST and accepts its one-use callback only for the
initiating account and current browser login. One active Marshall connection may
own a given numeric GitHub account. Reconnect from the same Marshall account when
consent expires or refresh recovery requires it.

Requested permissions are `repo`, `workflow`, `read:org`, `project`, `gist`,
`notifications`, `read:user`, `user:email`, `read:packages`, `write:packages` and
`offline_access`. Organization administration and repository deletion are not
requested. Organization approval, SAML SSO, repository grants and GitHub policy
can still restrict a connection.

Eligible non-Customer machines automatically use their owner's connection.
Detach persists until explicit reattachment, across reconnect/restart/relocation.
All permitted users and processes on a shared machine exercise the owner's
GitHub authority. The network identifies the VM; guest usernames and headers
cannot select another person's connection. Sharing delegates operations without
disclosing the token. Generic personal integrations retain explicit attachments.
With no connection, after disconnect or detach, or when reconnection is required,
new requests can still use reviewed routes anonymously. They carry no GitHub
token, and GitHub decides whether the operation requires authentication. Detach
withdraws existing authenticated leases; fallback cannot revive those attempts.

Managed `gh`, Git HTTPS and Git LFS use the private endpoint without GitHub
credentials in the guest. Git SSH and self-hosted origins are outside the
provider route. All seven OS families and retained-machine upgrades are intended;
source recipes and executed runtime results remain separate evidence. Exact
admitted native images cannot silently acquire a different qualified payload.

The proxy never retries a mutation or follows its redirect. Read redirects have
at most three reviewed hops under the same lease; signed storage receives no
OAuth bearer. LFS action credentials and signed URLs stay behind opaque,
method/execution/generation-bound selectors in Galileo memory, expiring within
sixty seconds or the earlier provider deadline. Binary bodies stream; JSON
rewriting is bounded to eight MiB and thirty-two levels.
Managed CLI integration errors currently use reviewed English fallback;
translated native client diagnostics are not claimed.

## Operator configuration

Register a GitHub OAuth App with an operator-selected production HTTPS callback
ending in `/auth/github-com/callback`. Set
`MARSHALL_GITHUB_CLIENT_ID`, `MARSHALL_GITHUB_CLIENT_SECRET_FILE` and
`MARSHALL_GITHUB_REDIRECT_URI` together. All absent disables the provider;
incomplete/invalid configuration refuses. The redirect must exactly match the
registered URI and use the fixed callback path without query, fragment or
userinfo. The validator does not enforce equality between its host and the
configured Marshall origin. The browser's final return is the fixed local
Integrations page.

GitHub's [2026-08-14 announcement](https://github.blog/changelog/2026-08-14-multiple-redirect-uris-and-token-refresh-for-oauth-apps/)
and [OAuth App authorization guide](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps),
reviewed on 2026-10-19, document expiring OAuth App tokens on GitHub.com. Marshall
always requests `offline_access`, which requests an eight-hour access token and
a refresh token valid for six months without use even if the app's global
expiring-token option is disabled. That option does not convert previously
issued long-lived tokens; obtain a fresh connection through Marshall. The
integration requires `token_type=bearer`, both tokens and their expiry fields.
Missing fields or another token type refuse the connection. GitHub Enterprise
Server is outside this provider.
`offline_access` is not tracked as a normal granted scope and need not appear
in the returned scope list. Verify actual consent and rotation with the
registered app before deployment; documentation and fixture replies do not
establish those results.

Marshall's `form-action` policy permits the fixed `https://github.com` origin
for the authorization POST redirect. It permits no arbitrary HTTPS form target;
scripts, connections and frames retain their same-origin restrictions.

On NixOS, set `services.marshall.integrations.github.clientId`, `clientSecretFile` and
`redirectUri` together. Their defaults are `null`; partial configuration fails a
module assertion. The unit wrapper removes inherited GitHub settings and
selects only module-configured values. `clientSecretFile` enters a systemd
credential and the wrapper passes its private credential-file path to Marshall.
Secret bytes never enter the Nix value or command arguments.

Removing OAuth configuration immediately withdraws private admission and
authenticated lease renewal; fresh requests and public renewals remain
anonymous. Encrypted stored grants remain pending reconfiguration or deliberate
revocation. Disabling configuration does not revoke the remote provider grant.

The secret setting names a private runtime file supplied through the existing
secret pipeline. Keep bytes out of Nix values, artifacts, arguments and logs.
Marshall reads the secret at the exchange boundary; configuration carries only
the path. Galileo host credentials, Audi private routing and guest trust remain
required. The hostname matches the existing wildcard: no new SAN, issuer or root
is needed. No separate fleet service or public listener is added.

Marshall uses its PostgreSQL-backed `github` queue with concurrency two and
AshOban scheduling. Queue state alone cannot authorize an exchange. Jobs contain
IDs, not access tokens, refresh tokens, authorization codes or verifier bytes.

`services.marshall.githubToolsRelease` and `services.ziggy.githubToolsRelease`
select the same immutable managed `gh`, LFS and Git configuration release for
authorization and artifact delivery. A mismatched generation cannot satisfy a
current installation attempt. Its manifest enters Marshall through
`MARSHALL_GITHUB_TOOLS_MANIFEST_FILE`; the runtime path must be a canonical
`/nix/store/.../manifest.json`. Marshall validates the closed version, generation,
platform inventory, artifact lengths and SHA256 digests. The release contains
public tool bytes and routing configuration, not GitHub credentials.

Retained delivery has a separate `Marshall.Agents.ToolMaintenance` state machine:
`queued`, `claimed`, `started`, `completed`, `failed` and `uncertain`. The current
VM placement/epoch and executor lease fence each attempt, artifact read and
receipt. A running conversation is not required. An interrupted or replaced
executor cannot finish another attempt; the replacement reconciles an idempotent
installer against the current desired generation. Source presence does not
establish native update/rollback acceptance.

Retained executors lacking `github-tools-v1` use a separate durable
`Marshall.Agents.ToolBootstrap` receipt. Marshall selects a fixed platform/digest
program and current VM/executor fence; model output and user conversations
cannot choose its code, arguments or artifact. Bootstrap success requires the
matching completed tool-installation receipt. Configure matching
`services.marshall.githubBootstrapRelease` and
`services.ziggy.githubBootstrapRelease`; Marshall receives
`MARSHALL_EXECUTOR_BOOTSTRAP_MANIFEST_FILE`. The inventory contains public
source-built executor bytes. It does not by itself prove retained-machine
bootstrap succeeded.

Retained FreeBSD and illumos tool setup validates a completed immutable
workspace source before replacing the historical `/workspace/*` Git ownership
exception with a durable include for that exact checkout. It preserves unrelated
system Git settings and restores the original configuration on setup rollback.
Pending or corrupt sources refuse migration; an absent source leaves the existing
ownership policy unchanged. Tightening after a later checkout requires another
real setup pass; tool installation alone does not establish that migration.

Managed native Go clients read the reviewed system CA bundle explicitly:
FreeBSD `/etc/ssl/cert.pem`, illumos `/etc/ssl/cacert.pem`. Missing, malformed or
oversized bundles refuse requests instead of falling back to vendor roots or
environment-selected trust. The maximum bundle size is two MiB. Linux and
Windows retain their platform trust behavior.

## Refresh, withdrawal and recovery

GitHub documents `POST https://github.com/login/oauth/access_token` with
`grant_type=refresh_token` as the refresh exchange. A successful exchange
invalidates both the previous access token and the consumed refresh token and
returns a new pair with unchanged permission scopes. The documented example has
`expires_in=28800` and `refresh_token_expires_in=15897600`; Marshall uses the
validated response deadlines rather than a hard-coded lifetime. Invalid or
expired refresh authority returns `bad_refresh_token` and requires reconnection.

Refresh begins ten minutes before access-token expiry. New old-generation
admissions stop during a drain of at most five minutes; remaining leases are
withdrawn before refresh. Publish the complete replacement pair and expiry
metadata atomically under the current attempt/generation. Provider waits occur
outside database locks. Duplicate or superseded workers cannot publish a pair.
Deadlines anchor the provider request start. Known late or rejected pairs remain
encrypted only in the failed attempt until ID-only cleanup revokes that access
token and clears the exact ciphertext. Minute reconciliation rediscovers failed
cleanup. An unknown provider response cannot be recovered by this mechanism.

An unanswered exchange can already have rotated provider credentials. Such
uncertainty requires reconnection instead of repeated old-token consumption.
Definite revoked/invalid authority also requires reconnect. Disconnect withdraws
the connection and authenticated leases; anonymous public forwarding remains
available. Ordinary Marshall sign-out preserves the independent
GitHub connection. Account retirement must prevent late callbacks/jobs restoring
authority. The NixOS setting `services.marshall.githubRestoreEpochFile` defaults
to `/var/lib/overalls-marshall-recovery/github-restore-epoch`; the marker remains
after invalidation and systemd applies it before listeners start.

The supported `overalls-backup restore-database --archive /ABSOLUTE/database.dump --epoch CANONICAL_UUID`
path verifies the captured archive digest and companion
metadata, stops and runtime-masks configured local replicas, durably publishes
the epoch, then runs `pg_restore`. Failure leaves the marker and stopped boundary
in place. Operators must fence remote replicas and distribute the same fresh
UUID to every replica before unmasking/restarting. The local wrapper cannot prove
that fleet coordination. A raw `pg_restore` outside this path cannot be detected
from restored rows and does not establish safe token recovery. Native execution
of the complete supported restore remains a separate acceptance requirement.

Backups need the matching Cloak keyring. Restored ciphertext may contain a
consumed refresh token; decryption does not prove provider validity. Reconnect
when authority cannot be proven. Do not copy tokens into a guest or reset attempt
history to repair a generation. GitHub may accept a mutation before its reply is
lost; the proxy does not automatically replay it.

Restore must keep all serving replicas stopped until a fresh durable external
restore epoch has been applied. The cold release helper
`Marshall.GitHub.invalidate_restored_credentials_before_serving!/0` reads
`MARSHALL_GITHUB_RESTORE_EPOCH_FILE`, starts the reviewed non-serving operator
application and atomically acknowledges that epoch after invalidating restored
authority. Each new epoch advances connection generations, clears credential and
staged pair bytes, invalidates ceremonies and request pins, and requires browser
reconnection. Repeated application of the same epoch is idempotent. Calling the
cold helper in an already serving application refuses. Startup also refuses an
existing or unreadable `<epoch-file>.pending` sentinel; a missing final marker
is a no-op only when that sentinel is absent. Supported systemd/restore
wiring and its native execution need separate evidence; directly restoring a
database without this stopped-serving boundary does not preserve current token
authority.

Provider-side invalidation of the complete rotating refresh pair still needs live
evidence. Local disconnect immediately withdraws platform use and schedules
token-specific revocation. It must not be described as proof that every related
provider credential has been revoked.

## Verification boundary

Required evidence includes typed state histories, committed multi-replica races,
controlled TLS provider counts, browser OAuth refusals and actual `gh`/Git/LFS
through Marshall, Audi, Lilly and Galileo. Each OS and retained-machine update
needs recorded execution. The architecture review distinguishes
presence from results. Parsers, mocked token replies, installed CLIs and
structural gates do not establish live GitHub, organization consent,
seven-family runtime or production acceptance.

The 2026-10-19 controlled packaged edge run passed managed gh, Git, LFS,
binary downloads, lease withdrawal and credential-redaction scenarios. It uses
substituted Marshall/Lilly authority. Consult the
[execution review](../architecture/reviews/2026-10-18-github-com-integration.md)
for the revision and bounded result; browser OAuth, scheduled refresh and retained
native fleet acceptance need their own records.
