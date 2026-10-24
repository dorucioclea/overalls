# Browser editors, terminals, SSH, and management

## Connecting to a suspended machine

The machine controls expose Pause and Resume. Resume retains guest memory and
may wait for compatible capacity. A stopped machine still needs Start. Opening
a browser terminal rechecks current Cedar access and the image's terminal
capability before joining wake demand. Pending wake grants neither guest
controls nor terminal tickets. Boot-log viewing, passive viewer checks and
server refresh timers do not wake a machine. A fresh authorized connection or
explicit terminal open may admit demand.

Relocation retires old-placement terminal authority. Reconnection is required;
PTY reattachment across a move is not promised. Authorized SSH, published web
applications and editor requests can wait through resume and automatic relocation
while renewing their authentication and publication/account authority. Snapshot
transport reset does not preserve established sockets.

## Language and text direction

[ADR-0201](repo:docs/architecture/decisions/0201-localized-human-surfaces.md) accepts a saved account language override with session/browser negotiation and English fallback. The 28 supported locales include Japanese, Hindi, Filipino, Estonian, Finnish, Swedish, Brazilian/European Portuguese, Egyptian Arabic, Swahili and Hausa. Arabic, Egyptian Arabic and Urdu use right-to-left document direction; other supported locales are left-to-right. Human browser, email, public documentation and interactive Porsche prose are localization targets. Machine JSON, protocol identifiers, diagnostic events and terminal bytes remain unchanged. Recorded browser/native acceptance remains separately scoped.

SSH key rename descriptions, confirmation and refusal flashes, and administrative verification/refusal messages use the active locale catalog. Translation does not change ownership checks, recent-passkey requirements or accepted mutation outcomes. English date-only month/day output follows bundled CLDR ordering (`Oct 18`); the UTC provenance remains unchanged.

Catalogs are maintained per language and feature using native Gettext domains.
The ordinary catalog gate rejects missing, fuzzy and unreviewed English-copy
forms; diagnostic `--report-only` execution does not establish completeness.
Human state labels, command descriptions, sign-out confirmation, terminal
screen-reader announcements and clone failure guidance use their owning feature
catalogs. Machine state attributes, command tokens, JSON and terminal bytes
retain their language-neutral values. The authentication library still owns
sign-out submission and CSRF protection; translated confirmation alone never
revokes the current login.
The public `/docs/*` guides are translated. This handbook's chapter titles,
contents and command reference remain English in every language, with an
explicit English left-to-right content boundary; reader controls follow the
selected language. Documentation extraction excludes `priv/hldd`, so handbook
edits cannot create translation work or change catalog coverage.

Public guide translations preserve literal code, command and link tokens and
parsed heading, emphasis and list structure. Each prose unit is bounded to
64 KiB during structural validation. Invalid translated structure falls back
to source English. Input examples must satisfy their actual field grammar;
machine identifiers and valid technical examples may remain unchanged only
with exact catalog reviews. Repeated direction lookup uses a bounded table
derived from bundled CLDR for validated supported locales.

JetBrains Mono remains the primary Latin and layout-grid font. Locally bundled
Noto faces cover CJK, Arabic/Urdu, Devanagari, Bengali, Telugu, Tamil, Hausa's
extended Latin characters and interface symbols, preserving native shaping and
language-specific glyph selection. CSS selects
script faces from this origin; no font service is contacted. Pinned sources,
licences and asset hashes are maintained with the fonts. Catalog and glyph
coverage checks do not establish browser legibility, joining, clipping or
overflow; current packaged rendering evidence remains separately scoped under
[ADR-0207](repo:docs/architecture/decisions/0207-bundled-multilingual-font-fallback.md).

## Inline privileged browser actions

The accepted ADR-0160 flow keeps a requested administrator mutation on its current
page while an inline passkey ceremony completes. Ordinary signed-in reads stay
available without elevation. The prompt identifies the pending action; it
retains only its exact server-bound actor/login/resource/action/arguments and
never replays an arbitrary browser event after verification. A successful step-up
creates a fixed fifteen-minute receipt and retries once after fresh admission.

No-key administrators are sent to the sign-in section of the account page
(`/settings#security`) for fresh-email first enrollment, then return to the
original page and explicitly retry the action. Cancel,
ceremony failure, continuation expiry, another
tab's input, stale resource state or loss of login/role/key authority refuse the
mutation and keep the page usable for permitted reads. Passkey changes require
verification of an existing key; Customer guest access still requires its exact
owner. Terminal, editor, SSH and service authority do not inherit this browser
continuation. Marshall implements the enrolled-key modal, socket-local retry and
no-key Security return path. Final merged packaged browser checks passed ordinary
access, no-key return/explicit retry, continuation/cancellation/focus restoration
and colocated cross-replica revocation. Native machine-page recovery and timed
receipt expiry remain unexecuted. See
[access](#access), [security](#security) and [scenario coverage](#coverage).

If a mounted machine or terminal depended on an administrator override and that
verification ends, the operation is refused and the UI returns to Fleet workloads
with an expiry explanation. Selecting the machine there opens a fresh passkey
step-up. Resize keeps its draft URL, removes mutation controls and offers a
Fleet workloads recovery link. Current owner and sharing permissions continue
normally. Foreign Customer access remains refused without a verification hint.

## Personal browser editor

New editor windows default to no startup editor
(`workbench.startupEditor = none`), and installing an extension does not open its
walkthrough automatically (`workbench.welcomePage.walkthroughs.openOnInstall = false`).
Users can override both preferences in Settings. These ordinary defaults are
separate from the permanently disabled bundled AI policy. Existing saved editors
follow upstream session restoration. The new package and a separate fresh-profile
manual browser smoke passed; the latter awaited actual workbench restoration and
observed no Getting Started panel or startup Welcome/Get Started/Walkthrough tab.
It does not establish saved-editor removal, actual extension-install walkthrough
behavior or user override execution.

On a running machine with a matching immutable editor capability, **Open VS Code**
opens the personal browser workbench in a new tab on the shared `/workspace`
folder (the worker passes upstream `--default-folder`); a `?folder=` query
selects another folder. The initial redirect enters a
one-use login flow; signing in preserves only the fixed local approval path.
Marshall derives the canonical HTTPS origin from the complete machine and
GuestAccount UUIDs, rather than forwarded headers. Two writers on one machine
have separate origins, cookies and browser storage. Customer permits only the
machine's exact owner; ordinary write grants apply to Standard and OSS.
The guest account has immutable UID/name/home `u<uid>` and `/home/u<uid>`;
all same-User email changes preserve its origin, cookie and renewable lease.
Retirement and current login/write/execution refusals remain authoritative.
Pre-cutover leases closed during the breaking database migration; this continuity
rule applies to subsequent generated-identity admissions.

The editor-bearing capability is currently limited to the reviewed version-4
Linux image contract. Windows `windows-v1` and native FreeBSD/OmniOS
(`freebsd-v1` and `illumos-v1`) rows are refused before this flow because their
protocol capabilities set `editor: false`; their terminal, SSH, readiness or
agent receipts do not widen that boundary. The Linux package and authority
checks also do not constitute a current-revision browser journey: no current
NixOS or Ubuntu sign-in, edit/save/readback and recovery receipt is recorded in
this status review, and the captured Alma/Arch receipts retain their earlier
image and source scope.

Windows has a reviewed native Code OSS bundle and a separately unselected
candidate image; `windows-v1` retains `editor: false`.
[ADR-0208](repo:docs/architecture/decisions/0208-windows-editor-job-custodian.md)
separates the gateway-only SYSTEM broker from an independent SYSTEM custodian.
The custodian owns personal SAM/S4U worker launch, complete SID-bound receipts,
exact worker pipes and retained kill-on-close jobs. Both roles independently
validate current MMDS boot/release authority and the other role's kernel process
identity through one fixed local SYSTEM-only pipe. The custodian keeps at most
64 stable account slots, including empty and quarantined reservations.

The old design's stock native fixture opened the workbench, ran its extension,
saved a file and used a real PowerShell PTY, then failed broker recovery. A
bounded native diagnostic showed that closing its final job handle could leave
the child alive while the job name disappeared. Those old-design observations
do not accept the replacement. New custodian source and two-task installation
exist. Root exit alone cannot prove descendant drainage, so [ADR-0237](repo:docs/architecture/decisions/0237-windows-custodian-same-boot-recovery.md) recovers a
custodian crash in the same boot by logon-session quiescence: each custodian
lifetime takes a durable per-boot generation that scopes its jobs, worker pipes
and receipts, and an earlier generation's receipt is retired only after its job
name vanished and no process of the worker's exact account logon session
remains. The custodian terminates only re-verified stragglers of that session;
other sessions of the same account and personal files are untouched, and any
ambiguous observation keeps the account refused. Native custodian-crash
execution, two-account separation, current revocation and the complete
exact-image browser journey remain gaps. No candidate is promoted.
Exact earlier identities and evidence digests remain in the
[cross-platform review](repo:docs/architecture/reviews/2026-10-18-cross-platform-editor-status.md).
The [custodian review](repo:docs/architecture/reviews/2026-10-18-windows-editor-job-custodian.md)
records the changed custody boundary and pending native acceptance.

Every machine page (Terminal, Access, Settings, Agents, Resize and the Boot log view)
shares one header. A bordered heading box carries the machine name, then an
operating-system label that is the registered display name of the machine's
immutable image (`[NixOS]`, `[Ubuntu 26.04 LTS]`, `[Windows Server 2025]`), then
its state label (`[Running]`, `[Stopping]`, …); a machine whose image row is
missing shows no operating-system label rather than a placeholder. Every status
label is one bracketed word on the character grid whose text names the state;
severity is weight, style or inverse video, never colour: `[Pinned]` and the
operating system are secondary-colour metadata, `[Stopped]` is plain text,
`[Running]` is bold, transitions (`[Starting]`, `[Stopping]`, `[Deleting]`,
`[Pending]`, `[Unknown]`) are italic, and `[Failed]` is a bold inverse-video
block one row tall with a one-cell margin inside the block. The label carries
the observed state in `data-state` and the severity in `data-tone` (`danger`,
`success`, `pending`, `muted`, or none for neutral states) on the Overview,
the Machines list and the machine header alike; the tone is decided in the
same order as the text, so a failed machine with delete intent reads
`[Deleting]` as a transition rather than `[Failed]`. Beneath them
sit the resource facts (vCPU, memory, disk, profile) and the machine ID with a
one-line **Copy** control; the authorized power actions and **Open VS Code**
stay on the right and wrap under the summary on phone widths. The "Connect from
your computer" box follows, collapsed to its heading while it holds commands
(an unavailable explanation starts open, and the viewer's open or closed
choice survives live updates). Expanded, it shows one explanation and two steps, "Install and
connect" lists the Linux / macOS and Windows installer commands side by side,
each with a platform label and **Copy** button, and "Already installed" shows a
single `ssh HOST` command for every platform, replacing the former Linux/macOS
`ssh HOST` and Windows `overalls ssh HOST` pair (see "Windows workstations").
Copying any
command or the machine ID writes only the displayed text to the user's own
clipboard and reports "Machine ID copied." or "Command copied." in the status
line; a refused clipboard write tells the user to select the text manually. The
same image name appears as an **Operating system** row in Settings → Resources,
beneath the machine name in the Machines list (the table gains no column, so it
still fits the main column) and before the state label in the Overview preview. The view projection exposes only the image's display name:
manifests, placements and reservations stay private, and the label is shown
only to principals who can already read the machine.

The machine page offers **Open VS Code** only when desired and observed state are
both running, its immutable image has the current editor capability, and the
current write/profile and Customer owner policy allows it. Valid older or
noncurrent images show that a new machine using the current image is required;
missing or corrupt image/configuration reports temporary unavailability. Host
deployment, restarting, resizing or cloning that old machine does not upgrade its
retained image. Keep the original machine while copying and verifying selected
files in a new one; see [operations](#operations).

The Overview machine preview, Machines list and ready Threads workspace reuse one
eligibility-gated projection for the same **Open VS Code** action alongside
their terminal actions. The Machines
table groups both controls in one **Connect** column. An eligible running machine
opens the personal workbench in a new browser tab. Stopped,
unsupported-image and temporarily unavailable machines show a disabled action
with the reason; unsupported images direct users to create a new machine using
the current image. Users without editor authority do not receive the control. These
list views are read-only projections, and opening the link still performs fresh
Editor admission under the current login, write grant, account and execution.
The displayed eligibility is a bounded authorized view, not a grant. Opening
still performs fresh Editor admission, and disabling an image for future launches
does not revoke an already running machine's matching editor capability.
Editor admission selects the approved tuple from the validated image target:
Linux/x86_64 kernel images use `linux-x64`; the separate Windows/x86_64
firmware `windows-editor-v1` candidate uses `win32-x64`. Approval of a tuple for
the other target grants no capability. DNS publication requires manifest4 for
Linux or candidate manifest7 for Windows and the exact target's commit, release
and protocol. Current route publication and each gateway asset receipt must
agree with the VM's current execution and host session. Every advertised gateway
also needs current receipts for the entire configured release set; expiry of
either release withdraws its editor and neutral webview discovery. These records
remain discovery only and do not authorize editor access.
SSH `ls`/`show` keep their existing machine response fields; the workspace status
is not added to their public command protocol.

```mermaid
sequenceDiagram
  participant B as Browser
  participant M as Marshall Editor
  participant A as Audi gateway
  participant L as Lilly
  participant G as Guest broker and personal worker
  B->>M: Open VS Code under current stored login and write
  M-->>B: Fixed personal origin
  B->>A: Begin personal host login
  A->>M: Begin and approve one-use account exchange
  M-->>A: Host/account-bound credential
  B->>A: HTTP or WebSocket with exact Origin where required
  A->>M: Admit renewable exact account/execution/release lease
  A->>L: Fenced fixed editor connector
  L->>G: Gateway-source TCP 4444 and typed account preface
  G->>G: Reconcile roster and start current UID worker
  A->>M: Renew while current authority remains valid
```

Admission binds the current stored login, write grant, account incarnation,
live host session, gateway identity, placement, execution epoch/generation,
release and origin. Renewal rechecks all of them except the provisioner's control
session: a Lilly restart opens a new session while the execution and the
detached bridge stay current, so a renewal while Lilly reconnects is answered
`unavailable` (Audi retries within the unchanged lease) and succeeds once the new
session reports
([ADR-0192](repo:docs/architecture/decisions/0192-staged-detached-ingress.md)).
A stale report on a live session still refuses. Unsafe HTTP and WebSocket requests require the exact origin;
same-site sibling origins cannot use the credential. Missing/mismatched capability,
retired accounts, stale logins, changed execution and expired leases refuse without
fallback. Generic guest-web visibility or port settings cannot grant editor access.
An upgraded editor or guest-web WebSocket ends with its lease, either peer's close
or 60 s without a browser frame; the gateway listener's 5 s HTTP read timeout does
not apply to it, so a client with a 5 s keepalive is not cut off
([regression test](repo:audi/test/http_proxy_test.exs)).

HTTP forwarding failures emit `audi.http_proxy_failed` with a fixed forwarding
phase, timeout/closed/protocol/other category, response state and bounded event
count. Errors, URLs, headers and request or response bytes never enter that
event. Failure before response headers returns 502; an interrupted response
still terminates the stream without a successful final chunk. These categories
locate a failed hop; they do not prove the guest's cause or retry a request.

Lilly's leg runs in a detached ingress bridge
([ADR-0192](repo:docs/architecture/decisions/0192-staged-detached-ingress.md)).
Lilly derives the typed account preface and the exact ready frame it requires
from the guest broker; lilly-hostd writes the one and compares the other
before it starts `lilly-ingress-bridge` in its own scope, then splices Audi's
connection straight to the guest. A live editor WebSocket therefore survives a
lilly-hostd or Lilly restart. Lilly still ends the bridge when the execution
loses authority, and Audi's sign-out revocation still closes the WebSocket,
which ends the bridge. Its first machine run failed: the bridges survived, but
Marshall refused the next renewal because the lease was pinned to Lilly's
replaced control session, so Audi revoked the stream. Renewal no longer pins
that session. The later Alma and Arch suites both passed this exact restart
survival stage. Alma completed all twelve stages. Arch's first capture later
failed folder navigation after broker restart; its same-image diagnostic replay
passed all twelve stages, without establishing the original 502's cause. One
candidate cause was a startup race: the broker unit used the default
`Type=simple`, so `systemctl restart` returned before the TCP 4444 listener was
bound and a fresh gateway connection could be refused. The NixOS and foreign-Linux
broker units are now `Type=notify` with `NotifyAccess=main`, and the broker sends
`READY=1` only after binding its listener and restricting it to the device. A unit
test covers path and abstract notify sockets. No new Arch browser run has yet shown
that this repairs the original 502. See the separate
[family execution review](repo:docs/architecture/reviews/2026-10-18-foreign-linux-browser-editor.md).

The exact admitted GET/HEAD of the packaged extension-worker iframe at the grant's
source commit permits same-origin framing for the upstream browser extension host.
Other editor responses deny framing. Foreign commits, unversioned paths and
suffix paths cannot inherit that exception.

The browser-fleet fixture retries focus custody before submitting a palette
command and stops its fixture-owned personal worker after the policy probe. Those
actions prevent stale Chromium focus and worker processes from contaminating a
later fixture, but they add no product authority, transport or editor evidence.

An expired/revoked personal cookie or its stored login requires authentication
again and redirects a safe browser visit into the fixed approval/sign-in flow.
A fresh real sign-in can replace that host cookie; it never revives the old cookie
or lease. Current write/account/Customer denial returns forbidden. Missing route or
execution or unanswered stored-login lookup remains unavailable, preserving the
difference between lost browser identity and infrastructure authority.

Built-in formatting, language diagnostics, search, Git, Markdown preview and PTYs
run through the native guest extension host. Open VSX gallery VSIXs are checked
against the packaged Ed25519 keys before extraction, including dependency and
WEB-targeted installs. User settings cannot disable that gate. An explicitly
imported local VSIX remains a user trust decision. Webviews use separate hash
origins and immutable Audi-served bootstrap files, without a CDN fallback.

The bundled editor permanently disables built-in AI, Copilot and Chat through
product policy and service guards. User, workspace and synchronized settings
cannot enable them. Generic completion APIs and separately installed extension
webviews remain available; users control those extensions independently.

Every folder in the guest is trusted automatically, including folders outside the
personal home. The worker uses upstream `--disable-workspace-trust`; Restricted
Mode and its prompts are disabled. This does not grant Marshall write authority
or approve an `.envrc`. Only open projects whose extension execution you accept.

ElixirLS, EditorConfig, rust-analyzer and vscode-direnv ship as signed, hash-pinned
immutable builtins. Each personal account may disable them globally or per
workspace. A newer personal version overrides the baseline; equal or older
versions retain the system copy. The baseline cannot be uninstalled, while
ordinary personal extensions remain installable and removable.
Only these four third-party IDs enter the typed immutable personal-update roster;
the upstream forced-auto-update roster stays empty. Ordinary user update settings,
pinning, delay and consent apply, while core builtin update guards remain.
Fresh imports below the System version refuse. To revert an effective personal
User builtin override, use the existing CLI `--uninstall-extension ID --force`;
the workbench's builtin Uninstall control remains unavailable and System removal
still refuses even with --force.
Disable state follows upstream browser-profile storage on the account's separate
editor origin; it does not imply cross-device synchronization. Installed
extensions and server data remain in account-owned guest directories, while
shared builtin payloads remain immutable.
The standalone control fixture retains a separate private Chromium profile for
each exact origin and uses VS Code's **Developer: Reload Window** action to await
normal storage flushing. Browser-profile evidence does not establish backend or
cross-device disable-state persistence. The later full family scripts pass their
personal control assertions; the final-package complete standalone subsequently
passed its version/language, personal-control and recovery stages.
The final release 7d2415 package and matching image builds passed. A strict scratch
fixture also passed 36 actual Workbench update-preference decisions and bounded
forced-install filtering, using finite mocked collaborators. Constructor scheduling,
real metadata/core selection, gallery installation and full UI remain separate.
The first final standalone run reached the correct lower-version refusal but
failed its stderr-capture oracle. The corrected immutable full rerun passed in
342 seconds total build/execution. Historical lower/equal on-disk scanner state
remains separate from fresh lower refusal and actual newer installation/reversion.

Language runtimes, compilers and servers come from the project's devenv environment.
The ordinary defaults select `rust-analyzer` from project PATH and a small Elixir
adapter directory delegating to project `elixir`, `elixir-ls` and
`elixir-debug-adapter`. Users can override these defaults. Missing Elixir adapter
commands return fixed stderr and exit127; missing `rust-analyzer` retains the
direct spawn's ENOENT error. Neither falls back to bundled server installers.
Fresh extension presence
alone does not establish working language support. Approve direnv explicitly,
wait for its environment to apply, then restart the language server or reload the
window; concurrent initial extension activation does not guarantee this ordering.
Compiled policy and 19 maintenance checks have recorded developer execution,
including actual source-bundled signature/engine validation and generated
archive/pagination histories. The same 19 tests and Ruff/ty also passed through the
Nix check using the final package's installed validator. Native trust,
independent extension controls and
real language responses for this specialized package remain separate acceptance.
Its final standalone attempt passed first-terminal proof, then failed
the Native Policy stage. Replay observed the policy marker and expected
EditorConfig result with no visible AI UI; the exact failed browser assertion
remains unknown. The corrected per-action run later passed the cold browser
journey and Alice's outside-HOME policy checks, then failed because Bob's HOME
NativePolicy command was absent from the palette for 30 seconds. This is a
separate observed failure, not an explanation of the earlier assertion. Full
personal controls, real language responses and a complete passing rerun remain
required.

The full merged Marshall component gate passed, including forced typing. Both
fresh Firecracker guest-family checks at `058f13d8` then failed. Their precise
execution records show that both initial cold editor/terminal/custody journeys
passed before the real-guest policy phase failed. They remain separate from the
earlier complete passing NixOS journeys below. At that revision the specialization's
complete native acceptance remained open.

The corrected startup-release snapshot now passes both complete Firecracker
family scripts, with actual Marshall/Audi/Lilly login and browser tools, native
policy/personal controls, broker/worker recovery, saved-data restart and exact
current physical readiness. NixOS took 805 seconds and Ubuntu 829 seconds total
build plus native execution. The final foreign-Origin/sign-out stages also
passed. These results apply to their frozen pre-template snapshot and do not
establish periodic sweeps or production browser execution.

The fresh standalone startup-package attempt passed both accounts' trust/default
and explicit direnv stages, then refused a fresh lower EditorConfig installation
before version/language/recovery completion. Lower/equal precedence requires
bounded historical personal profile state. The narrow newer personal permission
correction passed the final release 7d2415 package and 344 compiled membership
decisions, followed by complete native install/reversion and core/System refusal
acceptance. Actual Workbench full UI/gallery behavior remains separate from the
36 passing scratch method cases. A scoped writable-settings
Bob probe passed HOME/outside/direnv/disable/override controls on an older package.
Both initial actual Rust and Elixir diagnostic attempts failed. A later scratch
Elixir stage passed with a fixture-only immutable Hex/MIX_HOME closure while Rust
still failed Cargo arguments. A subsequent strict both-language scratch run
passed in 36.61 seconds on old startup package 3zz, including actual rustc E0308.
The final-package complete standalone then passed both actual language stages,
their personal marker custody and Elixir installer-cache absence. Its fixture
authorizer/relay establish no final Firecracker family or production runtime.
Project-server activation and
static extension presence must not be presented as working language support.
Their exact failures and remaining meaningful fixture checks are recorded in the
[review](repo:docs/architecture/reviews/2026-10-10-browser-editor.md).

Revocation hints prompt renewal; a thirty-second lease bounds communication if a
hint is lost. A closed relay cannot revive on later grant restoration. Guest
processes follow native worker lifetime, not the browser lease. Broker restart
preserves systemd-owned workers and sockets; upstream extension-host activity,
its five-minute idle timer and 1500-second reconnection grace govern shutdown.
Personal homes prevent automatic inheritance while existing sudo writers still
hold root capability. See [recovery](#recovery) and [security boundaries](#security).

The [scoped review](repo:docs/architecture/reviews/2026-10-10-browser-editor.md)
records passing local authority/protocol checks and the 60-second standalone
native fixture with synthetic gateway/roster authority. The complete NixOS
Marshall→Audi→Lilly→Firecracker journey also passed actual login, personal editing,
preview/terminal tools, worker recovery, saved-data stop/start, unsafe Origin
refusal and sign-out/WebSocket closure with fresh sign-in recovery. The corrected
merged NixOS snapshot passed again with current physical readiness; its exact
revision is recorded separately from the earlier run. Corrected Ubuntu
provisioned and reached the correct origin but reproduced initial workbench
visibility failure. Later source inspection identified closure-path/root-custody
defects and corrected assembly. The later startup-release full Ubuntu pass above
supplies its browser/control/recovery scope without retroactively explaining every
earlier failure. A bad-gateway document observation alone does not prove
broker/worker health or validate the correction.
Two-writer native separation, broader fault histories and production remain gaps in
[scenario coverage](#coverage).

On base `63a1443c` plus the durable feature before main integration, the
durable-identity application gate and focused editor checks passed
email continuity through approval, exchange, credential reuse and renewal. The
NixOS native run completed canonical personal editor/terminal, policy,
broker restart and worker recovery, then failed an edit assertion after physical
stop/start. Ubuntu failed guest startup before personal editor login. Earlier
editor package/family snapshots do not establish this feature or explain these
failures. The later incoming `d4499c4c` merged Marshall gate passed 1,429 checks,
including application editor authority, with zero-error forced Dialyzer. That
gate and both merged lifecycle passes do not establish native editor acceptance
or later browser-launcher/shared-observability integration. Complete
current editor recovery and native email continuity remain open in the
[durable identity review](repo:docs/architecture/reviews/2026-10-10-durable-guest-identities.md).

Porsche integration and team lists return an object with `items` and
`next_cursor`; `team show` returns `members`. Pass a non-null cursor through
`--after` to continue after the preceding page. Empty pages retain object shape.
`integration add NAME --peer --peer-vm MACHINE` treats `--peer` as a boolean flag.
Generated API/parser checks and the production failure history are recorded in
the [integration review](repo:docs/architecture/reviews/2026-10-02-galileo-production.md).

Integration submissions replace all write-only password inputs on success and
refusal. Empty server-side form values alone do not clear a browser-local value
when LiveView has no changed value to patch. Each attempt advances the input
identity; production Chromium verification checks the actual input value as well
as redacted HTML.

The machine workspace opens personal terminals. Marshall owns authorization and
creation receipts; guest terminald owns PTYs and bounded streams. A browser is an
attachment, not the terminal process. Reconnection must not replay input whose
receipt is uncertain.

The session list labels each terminal with a generated `adjective-noun` name
derived from a hash of the session id (`MarshallWeb.TerminalNames`), so every
browser shows the same label without storing anything. **New** opens a
terminal immediately under that name; renaming it replaces the label in that
browser only, and the guest's own title and user appear in the detail line
beneath the label.

```mermaid
sequenceDiagram
  participant B as Browser
  participant M as Marshall
  participant L as Lilly
  participant T as Guest terminald
  B->>M: Open authorized personal terminal
  M->>M: Persist opening and current account allocation
  M->>L: Boot-bound terminal request
  L->>T: Reconcile account and open PTY
  T-->>M: Durable terminal identity
  M-->>B: Authorized attachment
  B->>M: Input under current creator write authority
  M->>T: Fenced bounded stream through Lilly
```

Terminal opening progresses from pending to ready, or through cancellation to
failure. Session termination separately records pending, confirmed, or retired
kill authority. A disconnected socket is not proof that the PTY exited. Geometry
changes require a writable acknowledged attachment. Only the session creator with
current VM write access can attach writable; explicitly shared operators remain
read-only. Tickets bind one actor, session and issued mode for thirty seconds and
are consumed once. Input and resize recheck stored login and current session,
Cedar and execution authority before dispatch. Idle and output-only attachments
recheck every second; revocation does not promise instantaneous output cutoff.
A committed revocation also emits a control hint (ADR-0141) through
PostgreSQL to every Marshall node. Examples are a grant or team change, a
token, passkey, MFA or administrator change, a terminal session share or kill,
or a machine transition. Each attached viewer subscribed to its user or
machine rechecks at once. The one-second poll remains the backstop for a lost
hint, and a notifier reconnect makes every viewer recheck.
A failed recheck closes the attachment at once while the database answers. If
the recheck fails because this Marshall cannot reach the database (a `SELECT 1`
probe also fails), it is inconclusive (ADR-0140): the last confirmed authority
holds for at most 30 seconds, then the attachment closes as
`authority_unconfirmed`. Revocation latency is therefore up to 30 seconds only
while that node has lost its database.
The terminal page applies the same rule: while the database does not answer,
it never reports the machine as missing, and a server error page retries
itself every three seconds until the database returns. A reconnecting page
waits up to 40 seconds for the database before mounting (the browser's join
timeout is 60 seconds), so it keeps its open terminals instead of reloading.
A login recheck that fails only because the database does not answer neither
signs the user out nor leaves the page; the triggering action is dropped or
retried a second later. Login and terminal-session lookups distinguish a
definite answer (missing, revoked, expired or foreign) from a lookup that
failed: only the former refuses, so a pool timeout on an otherwise reachable
database is still inconclusive.
The browser bounds only the WebSocket handshake of a terminal attachment;
after the socket opens, the server's own five-second attach limit decides,
so a slow page that has not yet handled the attached frame keeps its socket
instead of restarting scrollback replay. Attached terminal sockets also
outlive LiveView disconnects: a reconnecting page only pauses ticket requests,
because the server authorizes and rechecks each attachment on its own.
Restored authority permits an explicit fresh attachment and cannot revive a closed
socket. Pending kill or a changed execution invalidates the old registry session.
The [attachment-history review](repo:docs/architecture/reviews/2026-09-26-terminal-attachment-verification.md)
records generated real WebSock processes against SQL-backed authority and synthetic
relay dispatch; the native guest results below retain their original scope.
Generated [terminald byte histories](repo:nix/domains/artifacts/terminald/src/property_tests.rs)
check exact raw scrollback retention through append, resize and cursor replay,
including default 1 MiB and maximum 8 MiB rings. Growing capacity cannot recover
previously discarded bytes. Stream histories preserve frame order across split
and coalesced input; partial headers remain incomplete and complete invalid or
oversized headers refuse before payload arrival. The sandboxed native gate passed
Clippy and 43 tests, including five properties. These pure checks do not prove
vsock authentication, PTY backpressure or the shared 64 MiB session budget; see the
[recorded scope](repo:docs/architecture/reviews/2026-10-03-terminald-byte-histories.md).

Guest output remains bytes; terminal escape sequences do not authorize browser
actions.
The host stream ignores repeated output sequence numbers. If an output frame
skips the next expected sequence, it closes that viewer channel and signals the
viewer to reattach with a scrollback cursor; it does not leave the channel
silently stalled. Generated local frame histories check this boundary, while
native interruption and browser reattachment remain separate evidence.
Generated [mailbox pressure histories](repo:marshall/test/marshall/terminal/host_stream_test.exs)
fill one stalled viewer to the 64-message output bound and shed only that
channel. One to three other channels continue advancing after the close. This
local host-stream test does not cover peer forwarding, browser WebSockets or
production load.

Generated [Lilly channel histories](repo:lilly/test/terminal/channel_history_test.exs)
exercise real local sockets and Stream callbacks: replay/live bytes retain exact
order, byte and frame credit block excess output, duplicate input has no socket
effect, exact cumulative ACKs release credit, malformed receipts fence channels,
and EOF drains only after consumption. Transport loss stops channels synchronously;
a new attachment rejects old process output/ACKs even with the same channel ID.
Guest managers are retained, but these tests do not establish native PTY lifetime
or authenticate a reconnect. Each new attachment resets its local sequence space;
uncertain input must not be replayed into that new incarnation.

Incoming and outgoing peer sockets share a process-owned local admission budget.
Generated [owner-death histories](repo:marshall/test/marshall/terminal/peer_budget_test.exs)
saturate limits of two to eight slots, kill owners without explicit release and
verify exact reclamation and replacement admission. This checks local monitor
accounting; it does not exercise distributed sockets or partitions.

Peers monitor the exact budget incarnation that admitted them. Its death aborts
incoming transport and retires outgoing peers before successor admissions;
graceful WebSocket closing is insufficient because it can still dispatch
application callbacks. The loopback TLS restart history requires exact old-owner
termination and successor slots while preserving the synthetic host stream.
It does not establish native guest survival or independent-node recovery.

Lilly's host stream and the Marshall peer hop now use the shared active-once
WebSocket connection (ADR-0142); neither polls its socket. The terminal codec,
hello and credits are unchanged. Lilly opens the stream outside its process, so
a hung dial never delays channel output or the five-second progress deadline.
The peer hop pings every five seconds. Either side ends after fifteen seconds of
silence, so a lost Marshall node releases its viewer's channel instead of
holding output credit and the shared terminal pump. A [liveness
test](repo:marshall/test/marshall/terminal/peer_liveness_test.exs) covers both
deadlines; native evidence comes from `terminal-fleet`.
An attached viewer rechecks its authority at once on a user or VM hint and
every five seconds as the backstop; input and resize still recheck on every
frame. The browser's own terminal socket gets the same liveness: an attached viewer
sends a heartbeat control frame every five seconds, and the page reconnects
after fifteen seconds without any frame. A page whose Marshall died behind a
half-open proxy connection therefore fetches a ticket from a surviving node
within about fifteen seconds instead of waiting for the proxy to give up.
The boot-log view pulls further chunks only while it is visible and resumes
from its cursor when shown again, so a page remounted on another node does not
replay a whole boot log into a hidden screen-reader emulator and stall.
It holds one correlated request or emulator write at a time. EOF and temporary
refusals retry after two seconds while the selected page remains visible and
connected; hiding the document, switching panes or disconnecting pauses reads
and discards stale replies. Reconnecting resumes at the retained cursor. Each
decoded chunk is at most 16 KiB and must advance that cursor by its byte length;
a rewind resets the emulator and refetches from zero. Disposing the page removes
its timers and visibility listener.

Creating a terminal selects its pane once. Switching to another pane is retained
across session-list refreshes. A delayed ticket reply can attach only the currently
selected pane while LiveView is connected; switching away cannot create a hidden
attachment. Malformed replies preserve the pending request for retry. The
native browser journey also checks the settled selected pane owns the only open
or connecting attachment; closing sockets do not count. A workspace keeps at most four
live emulators: the selected pane and the most recently selected others. A
pane builds its emulator only when first selected; a less recent pane without a
socket or pending writes disposes its emulator and, when selected again,
replays the retained window from cursor zero. Fifty shells on one page therefore
cost four emulators, not fifty screen-reader trees. Panes use xterm's DOM
renderer: no pane holds a WebGL context, so a page cannot exhaust the browser's
context limit and no renderer canvas can paint above the share or new-terminal
dialogs. A pane without an open attachment reports `connecting`,
never a stale `live`, and the selected detached pane keeps requesting a ticket
until it attaches: a request deferred by draining writes or a still-closing
socket retries instead of stranding the pane. Complete NixOS and Ubuntu
journeys on base `3f679eff`, captured tree `e710ef1e`, passed these checks through
graphics, replay and whole-Marshall recovery. The terminal and boot log fill the responsive
workspace panel. The boot log is the guest's read-only serial console: both NixOS
and Ubuntu guests disable the getty generator (`systemd.getty_auto=0`) and mask
the serial and console getty units, so no login prompt is offered there. The
console carries the fixed line `lilly-guest boot complete`, then the bounded boot
report (ADR-0154), which ends with the fixed line `lilly-boot-report: end`; an
autoscrolled pane therefore shows the report's end, not the boot-complete line.
Lilly reads the log as its service user: the root boot-log writer hands the
private file to that uid. Reading that host file has its own authority path:
current Cedar VM read, a fresh authenticated protocol-2 host stream and the
exact current runnable placement/execution. It does not require the image's
guest terminal capability or a ready/running guest outcome. A pending or failed
boot can expose retained diagnostics while guest session operations remain
disabled. Each response holds at most 16 KiB plus a cursor; it returns no guest
socket path or boot challenge and never dials the guest. A newer command or
changed boot/log incarnation refuses the read. Sparse serial output remains
observation, not proof of the failed guest stage.
The machine navigation has no Boot log tab. A machine whose image has no
guest agents, whose only console is host diagnostics, links `Boot log` from
its connection explanation; the link opens
`/machines/:id/terminals?view=boot-log` directly, and that URL stays
available for every machine reader. This diagnostic view selects
the read-only serial pane and skips guest-session listing and automatic shell
creation, so pending and failed boots do not depend on a guest terminal.
A local browser fixture passed desktop/mobile and both themes, grid, contrast,
origin-only resources, repeated EOF polling, disconnect/reconnect and
hide/destroy lifecycle. It exercises the actual browser view against a local
WebSocket fixture; a complete NixOS journey through a pending/failed native
guest and real Lilly log authority remains unrecorded. The
[diagnostic review](repo:docs/architecture/reviews/2026-10-17-host-boot-log-authorization.md)
keeps those scopes separate.
Interactive access
remains the vsock terminal and Audi-fenced SSH. Personal opening requires compatible guest account helpers and
terminald; activating a host release does not upgrade an existing guest disk.
Windows guests with the `windows-v1` agent set run the same terminald source
under ConPTY with an identical wire protocol, so this terminal path is
unchanged for them; their identity mapping and fidelity difference are
described under [Guests](#guests).

Before the machine is running, the workspace waits without querying guest
sessions. Failed boots remain visible; stopped machines require Start. Temporary
terminal-service failures show preparation during initial opening or reconnection
for an existing workspace. Definitive opening failures remain visible until a
retry or a new execution. An unsuccessful listing never proves a shell exited.
Automatic opening runs in a supervised task, so the workspace never blocks on
guest shell creation. A guest-account refusal is usually roster lag after boot
or a grant change. It shows "Preparing your guest account…" and retries up to
five times per execution before it becomes a definitive failure.

Control requests expire after five seconds. Their reply addresses expire when
the request completes, so late replies cannot crash the workspace or satisfy
another request. Caller identity still governs peer ownership. Retries reuse the
durable opening identity and cannot automatically resurrect a closed shell.
The [startup recovery review](repo:docs/architecture/reviews/2026-09-25-terminal-startup-recovery.md)
records generated reply-order and opening-history tests, connected workspace
regressions, and loopback TLS peer checks; native deployment acceptance is separate.

The pinned xterm renderer carries a reviewed local accessibility layout correction.
Row text and dimensions update together, natural widths are measured without
intervening writes, then each row is scaled to its logical columns. Screen reader
text, selection mapping, resize and announcement scheduling remain enabled. The
actual vendor-method regressions pass for mixed-width/blank text, partial refresh
and resizing. Both complete native guest journeys passed fifty shells, 10,000
images (310,000 bytes), accessible completion within 120 seconds, reconnect,
retained shell and mixed-width accessible selection before graphics and after
replay. Whole-Marshall recovery retained the shell effect and met the existing
database and restored-live bounds. Sharing, foreign refusal, operator view-only
input refusal and grant/login revocation passed. Earlier recovery failures retain
their captured scope in the review. These tests exercise the accessible DOM and
xterm selection; separate assistive-technology integration remains unverified.
See the [scoped execution record](repo:docs/architecture/reviews/2026-09-25-terminal-workspace-verification.md).

## Pinned machines in the lists

The Machines page and the Overview order each user's pinned machines first
([ADR-0193](repo:docs/architecture/decisions/0193-per-user-machine-pins.md)).
The pinned section is a separate bounded read (at most twenty rows, newest pin
first) that applies the same per-row Cedar read decision and projection as the
keyset page; the page then excludes those ids, so a machine appears once and
paging neither repeats nor skips. The pinned section is shown on the first page
only. The Overview fills its six preview slots with pinned machines first; each
preview lists vCPU, memory, disk size and whether the machine is personal or shared.

Every row, preview and machine header carries a text `Pin`/`Unpin` control
(`#pin-<machine>`, `aria-pressed`) and a `[Pinned]` label that leads the status
labels (`[Pinned] [Running]`); the control sends the
server-selected machine id and the displayed state, and the Access coordinator
decides. On the Settings tab the owner's own pin disables Delete with "Unpin to
delete"; a forged delete event is still refused by the domain with a fixed flash.
A shared manager's Delete stays enabled and receives the same refusal, and Fleet
workloads names the owner's pin in its flash. Refusals show fixed messages
(`pin_limit`, `vm_deleted`, otherwise a generic retry); the browser never learns
other users' pins. The SSH `ls`/`show` wire views omit the pin flag so the
Porsche JSON contract is unchanged. LiveView evidence is in
[machine_pins_live_test.exs](repo:marshall/test/marshall_web/machine_pins_live_test.exs);
the browser probe checks the toggle's presentation on both themes.
Wrapped machine-list actions use half-line vertical spacing and one-character
horizontal spacing. The pin integration exposed accumulated vertical drift from
using character units on both axes; the correction preserves the existing grid
tolerance, controls and authority. Its browser results and remaining responsive
coverage gap are recorded in the matrix review.
Thread layouts also suppress element-empty workspace boxes, retain grid-owned
activity field widths and use an inset terminal frame without shifting its
iframe viewport. Command-palette patches restore accessibility/query/focus
state even when the dialog remains open. The original local synthetic browser
probe passed both themes/mobile,32 thread and36 collaborator combinations,
sharing/revocation/refusals and153 screenshots after these corrections; actual
guest execution and packaged-browser coverage remain separate.

## Time zones and local time

[ADR-0195](repo:docs/architecture/decisions/0195-user-time-zones.md) gives each
account a display time zone. Storage, ledger comparisons, the usage CSV export
and SSH JSON stay unchanged; `ls`/`show` omit the additional machine-owner
fields, and `share show`/`team show` omit saved zones from owner, grant and
member records. Conversion happens only when a page renders. The viewer's zone resolves as the saved zone, else a valid browser zone
sent in the LiveView connect params (`timezone`, from the Intl API), else UTC.
The dead render trusts only the saved zone. `MarshallWeb.LiveUserAuth` assigns
`time_zone`, `time_zone_source` (`saved`, `browser`, `utc`) and `now`, and a
one-minute tick refreshes `now` only after fresh-login validation on required
and security views. Optional and public views retain their existing behavior.

The signed-in sidebar groups Overview through Teams under "Your workspace";
Account, AI usage and Browser extension under "Your account"; and Field notes,
HLDD and Source code under a separate "Reference" section. In the Control room
the sidebar shows only the administration tree; neither "Your account" nor
"Reference" is rendered there. Each SSH key on the
account page carries an inline Description field with Rename.

The profile section of the account page (`/settings#profile`, reached from the
single Account entry at the top of "Your account" and from the account menu's
clock; [ADR-0196](repo:docs/architecture/decisions/0196-single-account-settings-page.md)
merged the former Profile, Security and SSH keys pages into this one LiveView
with a numbered section index) shows the email read-only, a `<select>` of about 160 curated zones
labelled `(GMT+09:30) Adelaide` from the offset in force now (so daylight saving
is reflected), Save and Clear, a status line naming the source, and the viewer's
live local clock. A detected browser zone outside the curated list is added to
the picker so it can be saved. The account menu in the sidebar shows the same
clock under the email. Saving an unknown identifier is refused with a fixed
message and the saved zone is unchanged.

Timestamps on the overview, machines, threads, git, usage, SSH-key and
Control room pages render through `<.timestamp>` or equivalent semantic markup: the text is the viewer's local
time with its zone abbreviation (`2026-10-18 19:42 ACDT`) and the element keeps
the UTC instant in `datetime` and in the hover title. This includes the two-line
thread activity time and ingress route/certificate expirations. The thread activity
filters (today, week, month) compare calendar days in the viewer's zone. The JS
relative-activity labels stay relative.

Wherever a person appears, `<.person>` renders the email and, only when that
person has saved a zone, `3:42 PM ACDT local time · 2h 30m ahead of you`
relative to the viewer: team members and pending transfers, the machine Access
tab owner and grants, the owner of a shared machine in the machines list, thread
owner and grants in the sharing panel, and the Control room users (local time
only), access and workloads pages. A person without a saved zone shows the
email alone; the browser zone is never shown to others. Lines inside LiveView
streams (machine and thread grants) refresh when the list is re-read, not on the
minute tick. Terminal viewers show Linux guest names, not accounts, and are
unchanged. Evidence is in
[account_live_test.exs](repo:marshall/test/marshall_web/account_live_test.exs),
[time_components_test.exs](repo:marshall/test/marshall_web/time_components_test.exs)
and the Hegel properties in
[time_zones_property_test.exs](repo:marshall/test/marshall/accounts/time_zones_property_test.exs);
the browser probe saves Adelaide on the profile page and checks an overview
timestamp ends in ACST/ACDT in both themes. No packaged-browser journey exists.

## Developer SSH

Use the machine's installation instructions to install the `overalls` CLI and
configure local SSH. The installer and direct CLI setup fetch deployment-bound
SSH CA policy through verified HTTPS, then install scoped `@cert-authority`
entries. One dedicated CA authenticates Porsche, Audi and new NixOS/Ubuntu guests
with native OpenSSH certificates. Conflicting managed CA trust and explicit
revocation require reconciliation; host-key checking remains strict.

Audi's certificate principal contains the SHA256 digest of its current published
key. The proxy derives that alias from the exact route's HTTPS lookup and carries
known-host revocations into its isolated SSH process. System public trust may use
configuration symlinks; managed user trust and private key reads reject symlinks.
All these reads are bounded and require regular files. Guest certificates contain
only the authoritative VM hostname. Host certificates never grant user access.

The focused Linux [installer journey](repo:nix/verification/tests/machines/installer-trust/driver.py)
checks HTTPS artifact delivery, CA trust and account configuration with the actual
Marshall, Porsche and Lyra packages. Trust refusal preserves prior client and SSH
state. Generated pre-existing local SSH configuration properties check
byte-exact preservation of unmanaged content, exactly-one-marker refusal and
temp-file-free interruption boundaries. Full NixOS and Ubuntu guest connections
are covered by the fleet journey. Native macOS installation remains a separate
acceptance requirement.
state. The same journey records an account-key revocation refused after trust
installation — trust setup precedes account proof, so a first-contact account
refusal leaves CA trust installed while the executable, managed SSH block, proved
identity and CLI configuration stay absent or byte-identical — and owner-scoped
re-registration restoring the completing install. It also records four-way digest
agreement across the installed bytes, checksum endpoint, manifest and a fresh
download, an appended-byte artifact upgrade replacing the executable only after
configuration success, served-digest-mismatch refusal before replacement
(distinguished only by the stderr line, with a shared exit status), and
PATH-shimmed unsupported-platform, Darwin artifact selection and shasum-fallback
probes; native macOS runtime acceptance remains external. The fleet user SSH
journey records a revoke→probe→re-register cycle closing guest SSH and Porsche
account proof on both guest distributions. Full NixOS and Ubuntu guest
connections are covered by the fleet journey. Native macOS installation and
arbitrary pre-existing SSH configuration remain separate acceptance requirements.

Audi handles the guest SSH connection. It resolves the current placement, checks
Cedar and the registered key, and connects under a fresh execution binding. The
Unix login is the account's guest name, not a shared root account. Old disks can
lack the required reconciler or listener; inspect image provenance before treating
that failure as a key-registration problem.

Account discovery returns Marshall's immutable allocated `u<uid>` guest name;
do not reconstruct it from email. Same-User email changes preserve the login,
home and managed SSH profile. Rerun installer setup after the development
cutover or a fresh registration to discover its current identity.
First authenticated `whoami` may allocate the identity and records the
authenticated user in its audit version; repeated discovery preserves it. Browser
personal terminals use the same username and home without requiring an SSH key.

Direct Audi connections provide setup guidance, not a host shell. Key recognition
reports only whether the offered proved key is registered; it grants no guest
authority. Diagnostic channels cannot become relay channels. Proxy failures write
guidance to stderr and return nonzero, leaving stdout for guest protocol bytes.
Set `services.audi.publicOrigin` to the public Marshall HTTPS origin for setup
instructions. The private control endpoint is not a user-facing address.

Approve a new key through Porsche's interactive browser flow while keeping that
SSH connection open. Closing it invalidates the approval link. A one-shot command
must be retried interactively; browser identity alone does not prove key custody.
Approval and manual key addition hold current account admission through the outer
commit. If account retirement wins, the registration is refused without consuming
approval or adding a key. A fresh identity explicitly registers a released key
after old-account cleanup; old sessions retain their original registration ID.

### Windows workstations

A Windows 10, 11 or Server user installs the CLI from the machine page's
Windows row under "Install and connect"
([ADR-0172](repo:docs/architecture/decisions/0172-windows-workstation-client.md)).
The command runs [`/bin/install.ps1`](repo:marshall/priv/overalls-install.ps1),
templated with the same deployment trust as `install.sh` and refused (503)
without it, under Windows PowerShell 5.1 or PowerShell 7. It validates the
origin, zone and host against the issued values. It then requires an OpenSSH
client with hostname protection (9.6 or newer), because the in-box Win32-OpenSSH
9.5 lacks it: when the administrator-owned `%ProgramFiles%\OpenSSH` lacks a
9.6+ client it installs `Microsoft.OpenSSH.Preview` with winget without asking
(the MSI requests administrator approval itself), and stops with the manual
step only when no verified client exists afterwards. Because Windows searches
the machine PATH, where the in-box `%SystemRoot%\System32\OpenSSH` lives,
before the user PATH, the installer then asks once for administrator approval
and, in that elevated process, places `%ProgramFiles%\OpenSSH` immediately
before the in-box entry in the machine PATH (resolved inside the elevated
process, never a user-writable or caller-supplied directory) and broadcasts the
environment change. Plain `ssh HOST` in new terminals then runs the verified
client, so the machine page shows one reconnect command for every platform.
Declined or failed elevation leaves the machine PATH unchanged and prints
`overalls ssh HOST`, which always uses the recorded client.
It downloads `/bin/windows-amd64`, verifies the SHA-256 digest from
`/bin/sha256/windows-amd64`, runs `config-ssh --staged-installer` with the
downloaded binary before installing it as
`%LOCALAPPDATA%\Overalls\bin\overalls.exe`, adds that directory to the user PATH
and connects with `overalls ssh <host>`, which uses the recorded client.

The SSH profile is the Unix block in `%USERPROFILE%\.ssh\config` with one
difference: Win32-OpenSSH starts ProxyCommand without a shell, so the
executable is one double-quoted absolute path. Configuration lives in
`%APPDATA%\Overalls` and state and logs in `%LOCALAPPDATA%\Overalls\state`.
Updates use the same digest manifest; because Windows cannot replace a running
executable, activation renames it aside to `overalls.old`, moves the verified
binary into place with a write-through rename and continues in it. From
Windows, the user reaches Linux and Windows guests alike through Audi as their
`u<uid>` roster account.

### Open a repository from the terminal

`overalls open URL [-- COMMAND]`, for a supported GitHub, GitLab, Codeberg or Bitbucket link,
validates the URL locally with the shared closed grammar, then runs Porsche
`new --source URL --profile oss --request-id overalls-open-HEX --timeout 600 --json`
with the configured origin host and strict CA-pinned host keys. When the result is
`succeeded` with outcome `running`, it connects to the reported `ssh_host` through
the managed Audi ProxyCommand. A fixed remote script waits for
`/run/overalls-workspace/status` to become `done`, then changes into
`/workspace/REPO` and starts a login shell or the given command. An invalid URL
makes no SSH call; a failed or timed-out clone exits nonzero without opening a
shell in a partial tree. See [repository launch workspaces](#guests).

### Install and use the browser launcher

The public `/docs/browser-extension` guide is linked as **Browser extension** in
both the public header and signed-in reference navigation. Overview's **Open
repositories from your browser** card links to the same guide. The public
documentation catalog exposes its HTML and Markdown pages and includes it in
`/llms.txt`; the guide explains installation, explicit server configuration and
the supported GitHub, GitLab, Codeberg and Bitbucket pages.

Download the unsigned developer archive from `/bin/chrome.zip` or `/bin/firefox.xpi`.
For Chrome, extract the ZIP and select **Load unpacked** in Developer mode at
`chrome://extensions`. For Firefox, load the XPI temporarily through
`about:debugging` → **This Firefox** → **Load Temporary Add-on**. Permanent Firefox
installation requires signing or managed policy; no store publication is provided.
The guide remains public when the operator disables downloads with
`services.marshall.marvinPackage = null`; archive routes then return
`404 Unavailable`. The guide states this deployment-controlled availability.

Right-click the toolbar and choose **Configure Overalls server…**. Set the HTTPS
server origin explicitly; HTTP is accepted only for loopback development. The
setting uses the browser's synced extension storage. There is no default server.
The settings page links to this guide on the configured server after a valid
origin is saved; before configuration it uses the reviewed source guide without
guessing a server.
Clicking a supported public HTTPS provider page opens that server's capture page
with only provider origin/path in the source fragment; query/fragment fields are
discarded before transmission and URL user information refuses. An unconfigured
click opens options. The toolbar checks
provider host support, while Marshall checks the complete repository route. Known
unsupported pages disable it. When the browser withholds the URL, the action stays
available so the explicit click can grant activeTab; the observed URL is then
validated before any transmission. The extension sends no page content,
credentials or telemetry. An unsupported explicit click displays a grey `!` badge
and fixed **Unsupported page** title for three seconds, then clears the badge and
refreshes the current tab state; the feedback contains no page URL.
The toolbar icon is the monochrome overalls mark generated at build time. It is
rendered as an opaque dark mark on supported pages and as a grey outlined mark
on unsupported pages. The settings page follows the Monospace Web presentation
with system monospace fonts, the four colour tokens in light and dark schemes
and no external resources.

After the user saves an origin, the extension requests optional browser access
to that exact normalized origin and registers its packaged detector there. The
detector marks the current Overalls document with a local installed attribute.
Marshall observes that attribute only to hide setup prompts on the home page; it
does not establish login, machine, thread, terminal, editor or launch authority.
Missing configuration, denied or withdrawn site access, registration failure and
detector unavailability keep setup visible. Registration is reconciled on startup
and origin changes, while a failed change retains the last working configuration.

The capture page stages bounded input without creating a machine. Complete
ordinary sign-in before automatic OSS admission. A same-browser magic-link tab
resumes the signed-cookie pending launch. Invalid/expired input and unavailable
source-capable images refuse; successful creation clears only the matching intent.
See [access](#access), [guest workspaces](#guests) and
[ADR-0156](repo:docs/architecture/decisions/0156-browser-launcher-distribution.md).

## Porsche

Porsche is the SSH machine-management interface. Lyra supplies the local client
and SSH integration. Management commands call Marshall's authorized domains;
Porsche does not acquire independent scheduling or ownership authority.
Its source-owned candidate SSH dispatch SLI counts eligible terminal command
results and fixed duration buckets; invalid and forbidden requests stay out
of the denominator. An accepted asynchronous command measures dispatch only,
not physical VM completion.
An execution host reconnect clears its capacity freshness until a new native
report arrives. A refused restart preserves the explicit `host_unavailable`
error and its request ID; callers can retry after readiness returns. Porsche
never resubmits a mutation implicitly. Capacity and other closed conflict reasons
share the transport's command-exit classification.

Required operator settings and private credential/host-key custody are validated
before Porsche starts its supervisor or serving children. Generated local OTP
histories pass 171 refusals across 57 cases, including control/public origin,
listener bounds, paths, config/credential/key custody and CA defects. Refusals
preserve recursive fixture bytes, types, permissions, ownership and link counts,
and diagnostics exclude original/mutated credentials, host-key/CA bytes and
fixture paths. The unset control starts exactly seven live named base children
without listener or status startup. These are test-build checks. Baseline
synthetic host-key bytes establish loader custody acceptance only; configured
SSH/host-certificate startup, packaged refusal, file-replacement races, native
isolation and hosted config faults remain open for this property.

`pin MACHINE` and `unpin MACHINE` are non-physical mutations: they resolve the
machine like `rm`, call the Access pin coordinator as the SSH actor, answer
`{id, name, pinned}` synchronously and replay by request id. `rm` on a machine
its owner has pinned answers the closed `machine_pinned` reason; Porsche refines
`machine_pinned` and `pin_limit` into named conflict exits and prints a fixed
hint ("unpin it first: unpin MACHINE"). `ls` gains no pinned column. The
[SSH command tests](repo:marshall/test/marshall/ssh/commands_test.exs) cover
pin, unpin, the refused `rm` and the admitted `rm` after unpin; no native Porsche
journey has run them.

Use the command reference in [verification and reference](#reference). Supply
secret values only through supported stdin/private-file interfaces. A management
SSH listener cannot be used as an administrative host shell. Fleet OpenSSH and
the restricted transfer endpoint have separate ports and trust purposes.

Evidence: [personal workspace](repo:docs/architecture/decisions/0117-personal-terminal-machine-workspace.md),
[terminal opening](repo:marshall/lib/marshall/terminal/opening.ex),
[terminal sessions](repo:marshall/lib/marshall/terminal/session.ex),
[installer trust](repo:docs/architecture/decisions/0124-unified-ssh-host-ca.md),
[SSH guidance](repo:docs/architecture/decisions/0120-ssh-onboarding-guidance.md),
[Porsche operations](repo:docs/operations/porsche-operations.md).

### Mila client commands

Mila (ADR-0220) drives Marshall only through Porsche's command catalog
(ADR-0222). Thread commands (`thread ls|show|turns|prompt|answer|plan
approve|plan revise|mode|read`), terminal commands (`terminal ls|new|kill`),
web commands (`web show|set`) and the streaming `watch` share the existing
shared parser, Marshall session authority and pinned `ssh_requests` receipts.
Marshall answers identifiers, states, unread counts and canonical
`overalls://` routes; thread objectives, machine specifications and skill
selections never reach the wire.

Prompt, answer and plan-revision text arrives only on standard input after a
final `-`, bounded per command at 64 KiB; the integration secret keeps its own
4098-byte kind. Porsche buffers to that bound, validates through
`SSHCommand.put_stdin_payload/2` and logs only a closed
`porsche.stdin_payload_rejected` reason. Marshall stores receipts with the
payload replaced by a SHA-256 digest and with the caller's SSH key id, so a
Porsche-originated prompt, answer, plan approval or web change is attributable
without retaining its text. Read markers are per reader and agent transcript
and never move backwards; `thread ls` derives unread counts from them.

`web set` passes the caller's expected `policy_revision` (or the one it just
read) to Ingress, which rechecks manage authority under the VM lock and
refuses `revision_conflict`. Terminal commands run outside the receipt
transaction because the terminal domain commits its opening intent before
guest dispatch; `terminal new` derives its opening identity from the account
and request id, so a retry rejoins the same shell.

```mermaid
sequenceDiagram
  participant Mila
  participant Porsche
  participant Marshall
  Mila->>Porsche: exec "watch --thread T --session"
  Porsche->>Marshall: porsche.watch_subscribe(session, machines, threads)
  Marshall-->>Porsche: canonical ids readable now (or refusal)
  Porsche-->>Mila: {"event":"watching",...}
  Marshall--)Porsche: hint thread T (after commit)
  Porsche-->>Mila: {"event":"thread","id":T} (debounced)
  Mila->>Porsche: exec "thread show T --json"
  loop every 15 s
    Porsche->>Marshall: watch_subscribe again
    Porsche-->>Mila: {"event":"heartbeat"} or close with exit 3
  end
```

A hint is never authority: Porsche routes `{kind, id}` hints only to channels
registered for identifiers Marshall authorized, and the client re-reads
through ordinary commands. Porsche's gateway binding subscribes to every
thread and terminal-session hint, so the trusted gateway learns change
identifiers across accounts but never their content. Revocation ends a watch
within one heartbeat.

Evidence: [command grammar](repo:protocol/lib/overalls_protocol/ssh_command.ex),
[protocol properties](repo:protocol/test/ssh_client_commands_test.exs),
[dispatch](repo:marshall/lib/marshall/ssh/commands.ex),
[watch authority](repo:marshall/lib/marshall/ssh/watch.ex),
[read markers](repo:marshall/lib/marshall/threads/read_markers.ex),
[Marshall command tests](repo:marshall/test/marshall/ssh/client_commands_test.exs),
[Porsche watch routing](repo:porsche/lib/porsche/watchers.ex),
[Porsche tests](repo:porsche/test/client_commands_test.exs),
[real SSH transport test](repo:marshall/test/marshall_web/ssh_transport_test.exs).
Committed-hint delivery, live terminal openings and a NixOS machine journey
remain unexercised.

### Local host-certificate startup evidence

Native guest SSH refusal checks distinguish recognized users denied by VM or
membership policy from missing identity. Foreign users, Customer members and
withdrawn members require fresh Audi `forbidden` control evidence, recognized-key
guidance and unchanged ingress/guest-login receipts. A generic SSH transport
failure does not establish an authorization refusal.

Porsche's default Proof callback validates a current, correctly signed,
single-principal host certificate matching its private leaf key before the
listener calls the SSH daemon. A new local property records 54 fresh OTP
first-child refusals across 18 real key/certificate mutations. It checks the
exact listener failure, expected supervisor/listener attempts, no daemon/status/
observability starts or surviving service state, preserved private fixture
custody and material/path-safe output. Signed invalid type/options/principal
cases retain valid cryptographic signatures.

A separate configured control starts the real default-callback loopback daemon,
checks nine direct children, readiness, private status socket and an actual SSH
banner, then stops the application and removes its owned socket. This establishes
local startup only. Certificate negotiation/client CA trust, account proof and
authorized Marshall management, production release/systemd startup, native
isolation, concurrent file replacement and hosted faults remain separate.
The server's embedded-CA signature check does not choose which CA a client may
trust. Evidence: [boot properties](repo:porsche/test/host_certificate_boot_property_test.exs)
and [execution review](repo:docs/architecture/reviews/2026-09-29-antithesis-property-audit.md).

### Local strict certificate negotiation

The real default Proof callback now has local OpenSSH property evidence beyond
the startup banner. Three shuffled four-case histories use a disposable real
Ed25519 CA, host certificate and user key. Strict certificate-only verification
accepts the trusted CA with the matching hostname; signed user proof submits
one session with the canonical user key and returns a scripted pending approval.
A foreign CA, hostname outside the signed principal, or absent trust exits 255
before any backend request. Client fallback to a plain host key is disabled.

This checks real local certificate negotiation and user signature proof, not
Marshall account ownership, browser approval, HTTPS transport or authorized
management. The pending response remains scripted. Packaged/native journeys,
production trust rotation and hosted faults remain separate. Evidence:
[negotiation property](repo:porsche/test/host_certificate_negotiation_property_test.exs)
and [execution review](repo:docs/architecture/reviews/2026-09-29-antithesis-property-audit.md).

### Local host-session takeover histories

Three generated two-takeover histories keep real local Bandit host WebSockets
and channels live while PostgreSQL replaces the host connection session and
epoch. Both explicit renewal before successor registration and successor
registration before renewal end the old WebSock process. A socket upgraded
before takeover cannot publish its delayed matching old hello afterward;
the successor retains its directory nonce and sends usable output. Old directory
nonces cannot renew or identify a local stream after replacement.

This verifies the renewal decision and local process lifetime. Renewal is
delivered explicitly; the test does not establish a five-second scheduler bound
or instantaneous per-frame database fencing. Host connection epoch is distinct
from VM execution generation. HTTPS transport and guest replies are synthetic;
native Lilly, remote peer authentication, partitions and hosted faults retain
their separate evidence and gaps. Evidence:
[takeover property](repo:marshall/test/marshall/terminal/host_takeover_history_test.exs)
and [execution review](repo:docs/architecture/reviews/2026-09-29-antithesis-property-audit.md).

## Mila

The [native rewrite decision](repo:docs/architecture/decisions/0249-mila-rust-core-native-clients.md)
is partially implemented. The Flutter behavior described below remains the parity
reference. Native SwiftUI, Compose, GTK and WinUI clients do not yet implement
all authenticated sessions or application screens. Their Rust
[machine-command FFI](repo:mila/rust/mila-ffi/src/lib.rs) accepts only `show`,
`start`, `stop`, `pause`, `resume`, `unpause`, `pin`, `unpin` and `rm` as exact
action tokens. It formats JSON commands into caller-owned bounded buffers;
mutations require a canonical client request ID. Extra action tokens are refused
before formatting. Formatting performs no network submission and does not establish
authorization or at-most-once execution. The
[Hegel FFI properties](repo:mila/rust/mila-ffi/tests/commands.rs) exercise token
injection refusal, request identity and buffer canaries; authenticated transport
and native end-to-end mutation acceptance remain separate gaps.

The Apple adapter projects each snapshot row together with its Rust-computed action
mask after validating the deployment host and port. SwiftUI renders that projection
without implementing a second machine policy. Refresh replaces the visible list
only with a validated projection; a failed refresh clears it. The linked adapter
currently refuses refresh and submission until an authenticated session bridge is
installed. ABI compatibility and command formatting never count as connection or
submission success. Apple linked tests cover malformed and foreign snapshots,
policy projection, and refused action submission; execution requires the Apple CI
host. Native localization, secure custody and live session acceptance remain gaps.
The Rust [application session](repo:mila/rust/mila-session/src/lib.rs) now runs
`ls --json` and canonical UUID `--after` continuations on one certificate-pinned
SSH connection. It validates the version-1 succeeded read envelope and typed
identity/permission fields before publishing machine rows. Unknown descriptive
fields are ignored; unknown observed states disable lifecycle actions. Refused,
malformed or interrupted reads preserve the previous listing and return an error.
Callers must present that error rather than treating retained rows as a fresh read.
Pagination refuses repeated cursors, more than 500 distinct rows or 500 cursors.
Only a complete listing can produce an offline snapshot, bound to the connection's
management host and explicit port. The snapshot owner field is a presence marker
(`self`), not an account identifier. This crate does not fetch trust, approve a key
or persist snapshots. Its [C ABI session handle](repo:mila/rust/mila-ffi/src/session.rs)
dispatches authenticated machine, thread, web and SSH-key operations; the Android
JNI adapter uses the same handle. Its [TCP SSH tests](repo:mila/rust/mila-session/tests/session.rs) use a real local
SSH server with scripted command replies; [Hegel decoder properties](repo:mila/rust/mila-session/tests/properties.rs)
cover identity and authority refusal. Native application wiring and a real Porsche
machine journey remain unverified.

Mila is the Overalls client for iOS, Android, macOS and Windows; its Linux
build exists for testing. A platform profile
([`PlatformProfile`](repo:mila/app/lib/transport/platform.dart)) fixes per
platform whether keys are hardware-held, which push provider is used, whether
web tabs and the app lock exist, and where links arrive; no code path infers
Linux from "not a phone". It manages machines through one SSH connection to the deployment's
Porsche gateway and adds no Marshall API: every command is an ordinary Porsche
`--json` command, authorized by Marshall's domains like any other SSH caller.

| Concern | Behaviour |
| --- | --- |
| Device identity | One P-256 key per deployment: Secure Enclave (iOS and signed macOS builds), Android Keystore with StrongBox where present, a non-exportable CNG key on Windows (TPM 2.0 through the Platform Crypto Provider, otherwise the Software Key Storage Provider without refusal), and an owner-only file on Linux and unsigned macOS dev builds (`MILA_SOFTWARE_KEYS`, refused by a release build). A key file other users can read is refused. |
| Owner-only files | POSIX hosts create directories `0700` and files `0600`. Windows applies a protected DACL granting only the current user and SYSTEM, and refuses a file whose DACL admits anyone else ([`owner_only_windows.dart`](repo:mila/packages/mila_transport/lib/src/owner_only_windows.dart)). |
| Host trust | `https://HOST/bin/ssh-trust.json` is fetched over HTTPS without redirects and pinned. A later document with another CA, host or zone is refused; a failed fetch uses only an unretired pin. |
| Host acceptance | Only `ssh-ed25519-cert-v01@openssh.com`. The certificate must come from the pinned CA, name the management host and be inside its validity window. The check runs in key exchange, before user authentication. |
| Sign-in | Porsche's browser key approval. Adding a deployment starts sign-in at once, and Mila opens each new `approval_url` in the user's default browser (the button reopens it) and keeps the connection, re-checking `whoami` every 2 seconds. A link expires after 600 seconds. The Flutter shell never replaces it while shown; native Android replaces it with the newest approval envelope the control plane rotates for the same pending session, and native Linux, Apple and Windows refuse an approval link whose host is not the selected deployment. A signed-in deployment opens its machine list and shows the `whoami` email. A dropped connection after sign-in is shown as disconnected with Reconnect (a new connection and `whoami`) and Sign out (closes the session locally; the key and its approval are unchanged). Mila does not reconnect by itself. |
| Deployments | Settings lists each deployment with its signed-in or offline state and email. Remove asks first, turns notifications off while a session is open (waiting at most 10 seconds), then deletes the poke key, notification record and saved machine list and forgets the deployment. The account, its machines and the device key's approval on Marshall are untouched. |
| SSH keys | `ssh-key list` per deployment; Revoke confirms, then sends `ssh-key remove` once with a request id. The key Mila signs in with (matched by fingerprint of `whoami`'s `public_key`) is marked and cannot be revoked from Mila. Marshall decides which keys the account may remove. The Android native shell derives that fingerprint from its non-exported public key, decodes the bounded listing through its authenticated Rust/JNI session handle and sends revocation only for another key's opaque id. |
| Mutations | Submitted once with a client `porsche-<32 hex>` request id and `--no-wait`, then polled with `request show`; never resubmitted. |
| Machines | The list pages with `ls --after`, shows a failure reason on failed rows, and offers a new machine with an optional setup objective, image (`images`), team (`team list`), CPU, memory (MiB) and disk (GiB). The objective creates a durable Work-mode agent thread and runs automatically after the machine is ready; an empty objective records a no-op setup request. The browser opens that thread while provisioning and exposes the bound machine when admission completes. A machine on no loaded page is read with `show`. The Info tab shows the machine's identifiers, requested state, failure reason, access, architecture, profile and creation time, and offers the lifecycle actions, resize and clone. A clone or resize request that is still accepted can be cancelled (`request cancel`) and one that failed retried (`request retry`), each naming the original request under a new request id. Resize refuses an empty change or a shrinking disk before sending. Managers also see sharing: `share show`, `share add EMAIL ROLE`, and `share remove` after confirmation. Marshall decides who may do each. |
| Type | JetBrains Mono, with the ADR-0207 Noto faces bundled as fallbacks for Arabic, Indic, CJK and symbols. Flutter cannot read WOFF2, so Nix fetches the original TrueType and OpenType files that Marshall's manifest pins, checks their digests and ships each with its OFL notice. |
| Links | `overalls://HOST/PATH` only navigates. Unknown deployments land on the deployment list with the host filled in and a message asking to add it; refused links say so; signed-out deployments reach only their sign-in screen. |
| Recovery | Every list and detail read that fails shows its reason with Try again; machine pages and Recent threads also refresh by pull or a Refresh action. |
| Language | One ARB catalog per Porsche locale, checked against `porsche/priv/gettext`. Egyptian Arabic, Hausa and Nigerian Pidgin have no Flutter framework catalog, so dialog and tooltip strings borrow Arabic or English while Mila's own strings stay in the locale; Egyptian Arabic keeps right-to-left direction. Terminal output and identifiers stay left to right. |

```mermaid
sequenceDiagram
    participant M as Mila
    participant W as Deployment HTTPS
    participant P as Porsche
    participant B as Browser
    M->>W: GET /bin/ssh-trust.json
    W-->>M: CA, management host, zone
    M->>P: key exchange, certificate host key only
    P-->>M: host certificate and exchange signature
    M->>M: verify CA, principal, validity, signature
    M->>P: publickey with the device key
    M->>P: whoami --json
    P-->>M: approval_required and approval URL
    M->>B: open approval URL
    B->>P: user approves the key
    M->>P: whoami --json on a new channel
    P-->>M: succeeded
```

Failure behaviour: an untrusted host ends the connection before any command and
before the device key signs anything; an unreachable origin with no pin (for
example a host serving no `/bin/ssh-trust.json`) is reported as unreachable
rather than untrusted or as an expired approval link. Mila stores no terminal bytes,
tokens or reply bodies; it logs nothing about keys or commands.

The Linux native seam now keeps endpoint validation, HTTPS trust reconciliation,
canonical pin persistence and session planning in Rust. Its host-provided signer
and HTTPS implementation remain integration boundaries, so GTK does not claim a
live production sign-in journey until those adapters and approval polling are
wired.

Once a session is authenticated, Linux web controls call Rust-owned `web show`
and `web set` operations. Endpoint projections accept only bounded canonical
routes and HTTPS URLs; mutations carry the displayed policy revision and a
client request id. GTK opens only a public HTTPS endpoint whose port matches its
endpoint record (`linux-web-browser-fence`) and refuses private endpoints; a live
ingress journey remains open. Authenticated `LiveSession` wrappers also list and
revoke SSH keys with once-only request ids.

Evidence: [transport](repo:mila/packages/mila_transport/lib/src/ssh_porsche.dart)
and its [OpenSSH journeys](repo:mila/packages/mila_transport/test/ssh_porsche_test.dart),
[host certificates](repo:mila/packages/mila_core/lib/src/host_trust.dart),
[sign-in machine](repo:mila/packages/mila_core/lib/src/sign_in.dart),
[device keys](repo:mila/packages/mila_transport/lib/src/device_key.dart),
[dartssh2 patch](repo:nix/platform/patches/dartssh2-host-certificates.patch),
[Linux session coordinator and trust tests](repo:mila/native/linux/src/session.rs),
[real-Porsche machine test](repo:nix/verification/tests/machines/mila-porsche/default.nix)
(passed against the real Porsche release), the [desktop journey](repo:nix/verification/tests/machines/mila-desktop/default.nix)
(browser approval, machine list and forwarded links through the Linux bundle) and the [M1 review](repo:docs/architecture/reviews/2026-10-18-mila-m1.md).

### Mila notifications, app lock and offline list

Notifications are opt-in per device and per deployment. Mila asks the
platform for an APNs token (iOS, macOS), an FCM token (Android) or a WNS
channel URI (Windows), and registers as platform `ios`, `android`, `macos` or
`windows`; macOS shares the APNs topic `dev.overalls.mila` with iOS. It exchanges the token for a push key at
the fixed relay origin `https://notifications.overalls.dev`, then registers
the device through Porsche with
`device register --platform P --push-key - --enc-pubkey K`. The push key
travels only on the command's stdin. The token goes only to the relay. Mila
stores neither: its saved record holds a token digest, the device id, the key
id and the key expiry.

| Concern | Behaviour |
| --- | --- |
| Registration | A pure state machine. Each step has an operation number, and a reply to an older step is ignored. Turning notifications off while a registration is in flight removes the device once it lands. A new platform token re-registers. The key is rotated within 14 days of expiry. `push_disabled` stops retries. Transient failures back off from 5 s to 30 min. Android declares `POST_NOTIFICATIONS`, gates registration on OS permission and validates FCM metadata in Rust without retaining the token; provider delivery and Porsche device CRUD remain unverified in the native shell. |
| Poke contents | Pokes are end-to-end encrypted to a per-deployment X25519 key: `0x01 ‖ ephemeral key ‖ nonce ‖ ChaCha20-Poly1305 ciphertext`, with the key derived by HKDF-SHA256 and the deployment host bound in the AAD. The relay sees only ciphertext. The plaintext is exactly `{v, kind: "needs_input", route}`, and the route must be a canonical app route on that host. |
| Notification text | Fixed and localized ("An agent needs your input"). The decrypted route is used only as the tap link. A poke that fails to open shows the fixed text with no link on iOS (an APNs alert cannot be suppressed); Android shows nothing. |
| Poke keys | iOS and macOS Keychain group shared with the notification extension (the data-protection keychain on macOS), readable after first unlock on this device only. On Android, wrapped by a Keystore AES key. Only the public key leaves native code. Removing the device deletes the key. |
| Device list | Each device can be turned on or off, or removed (`device prefs`, `device rm`), and the list refreshes on request. A device missing from `device ls` shows as revoked. Registration sends `--label` with the computer's host name where the platform reports one (none on Android); the label is a display name, not an identifier. |
| Linux device controls | The Linux shell has no push provider and never registers a device. An authenticated session can still list devices and issue bounded `device rm` and `device prefs` commands; unauthenticated handles refuse these operations. The GTK registration and live Porsche transport remain open. |
| App lock | Optional, with biometrics or the device passcode (`local_auth`). It locks immediately or after 1 or 5 minutes in the background. A saved lock covers Mila from the first frame. Locked content is not painted and not in the accessibility tree. In the native Android and Apple shells an in-flight unlock prompt survives the app moving to the background, so its result can still unlock; a result from an older attempt is still ignored. Linux has no lock, and the setting says so. |
| Desktop push | macOS uses the same notification-extension path as iOS, from code shared in `mila/app/darwin/Shared`. An unsigned macOS dev build has no push entitlement and offers no notifications. Windows push needs Susan's WNS provider (ADR-0236), whose deployed configuration is not yet enabled; the Windows native channel and poke opener are not yet implemented. |
| Offline list | The last complete machine listing per deployment is saved as an owner-only `0600` file holding machine rows only, at most 500. While offline, the saved list is shown with its save time and its actions are disabled. |
| Linux desktop | One window. A second `mila overalls://…` hands its link to the running window, which only navigates. Rust classifies each bounded route as an unknown deployment, sign-in-required target or authenticated target; unknown and signed-out links do not reach a target screen. |

```mermaid
sequenceDiagram
    participant M as Mila
    participant S as Relay (notifications.overalls.dev)
    participant P as Porsche
    participant D as Deployment (Marshall)
    participant N as Notification extension
    M->>S: POST /api/push/v1/keys (provider token, deployment)
    S-->>M: push key, key id, expiry
    M->>P: device register --push-key - (key on stdin) --enc-pubkey
    P->>D: register device bound to the SSH key
    D-->>M: receipt with device id (via request show)
    D->>S: poke = ciphertext to the device X25519 key
    S->>N: APNs, FCM or WNS raw message
    N->>N: open with the deployment key, check host and route
    N-->>M: fixed localized alert, tap opens overalls://HOST/ROUTE
```

Failure behaviour:

- A relay refusal or a `push_disabled` deployment leaves notifications off
  and says why. A blocked system permission is reported without contacting
  anyone.
- A tampered, truncated, wrong-host or wrong-schema poke is refused before
  anything from it is shown.
- A snapshot file other users can read is deleted rather than read.
- Mila logs no tokens, push keys, poke bytes or routes.

Evidence:

- [registration machine](repo:mila/packages/mila_core/lib/src/push_registration.dart)
  and its [stateful property](repo:mila/packages/mila_core/test/push_registration_test.dart);
- [poke opening](repo:mila/packages/mila_core/lib/src/push_poke.dart) against
  the [shared vectors](repo:protocol/test/fixtures/push_pokes.json) in
  [its tests](repo:mila/packages/mila_core/test/push_poke_test.dart);
- [relay client](repo:mila/packages/mila_transport/lib/src/susan.dart) and
  [registrar](repo:mila/packages/mila_transport/lib/src/push_registrar.dart)
  with [their tests](repo:mila/packages/mila_transport/test/push_test.dart);
- [lock policy](repo:mila/packages/mila_core/lib/src/app_lock.dart),
  [snapshot cache](repo:mila/packages/mila_core/lib/src/snapshot_cache.dart)
  and the [app journeys](repo:mila/app/test/device_features_test.dart);
- native [iOS and macOS extension](repo:mila/app/darwin/Shared/NotificationService.swift)
  with [shared poke tests](repo:mila/app/darwin/SharedTests/PushPokeTests.swift)
  and [Android service](repo:mila/app/android/app/src/main/kotlin/dev/overalls/mila/MilaMessagingService.kt);
- Linux's bounded [device command and projection adapter](repo:mila/native/linux/src/adapter.rs),
  authenticated [session controls](repo:mila/native/linux/src/session.rs), and
  shared [device command wrappers](repo:mila/rust/mila-session/src/lib.rs)
  with [FFI exports](repo:mila/rust/mila-ffi/src/session.rs) are covered by the
  Linux unit test gate; provider registration and live Porsche transport remain unverified;
- the [desktop machine test](repo:nix/verification/tests/machines/mila-desktop/default.nix)
  and the [M5 device review](repo:docs/architecture/reviews/2026-10-18-mila-device.md).

### Mila build targets

Every platform has a dev and a release target, driven by one typed planner,
[`mila-build`](repo:mila/tool/lib/src/plan.dart)
(`mila-build <linux|android|ios|macos|windows> <dev|release>`).

| Platform | Dev | Release |
| --- | --- | --- |
| Linux | `nix build .#tool-mila-linux-dev`, debug bundle | `.#tool-mila-linux-release`, reproducible tarball with SHA-256 sums |
| Android | debug-key APK | app bundle signed with the upload key from `MILA_ANDROID_UPLOAD_*` |
| iOS | simulator debug build, or development-signed with `MILA_APPLE_TEAM` | IPA from `MILA_IOS_EXPORT_OPTIONS` |
| macOS | unsigned debug app with software keys, or development-signed with Secure Enclave keys and the APNs sandbox | Developer ID signed, notarized and stapled DMG, assessed by `spctl` |
| Windows | debug layout with a development MSIX manifest, registered with `Add-AppxPackage -Register` | MSIX packed with MakeAppx, signed and verified with SignTool |

The native Android `mila-release.yml` job separately publishes
`app-release-unsigned.apk` with a SHA-256 manifest as the native release
candidate; signing it remains a distribution step outside that job.

A release plan refuses demo mode, software keys, another host's target and any
missing signing input rather than substituting one, and every signed release
verifies its signature as a final step. Secrets reach tools through the
environment and are redacted from printed plans. Apple builds clear the Nix
compiler variables and use the system Xcode.

### Mila terminals, threads and web

The Rust migration includes a payload-free attachment reducer in
[`terminal.rs`](repo:mila/rust/mila-runtime/src/terminal.rs), ported from the
Dart reducer. Only the current opening generation accepts a header. Headers
establish the replay cursor and granted mode; a changed known cursor requests a
screen reset. Transport failures exhaust eight consecutive attempts, while
closed, invalid, refused and authority outcomes stop automatic retries. User
retry starts a new budget. User read-only restriction takes effect immediately;
input and resize also require an attached read-write server grant. Output before
the header or from a stale generation is ignored.

Generated action-sequence properties in
[`terminal.rs`](repo:mila/rust/mila-runtime/tests/terminal.rs) exercise stale
channels, permissions, replay jumps and retry exhaustion. This is bounded Rust
logic evidence; native terminal adapters, SSH stderr/header delivery, actual
resize/input refusal, server revocation and screen rendering remain separate
integration gaps. The reducer stores lengths and positions rather than bytes.

The Linux native adapter adds [`HostPtyTransport`](repo:mila/native/linux/src/terminal.rs),
which accepts a host-owned backend, binds its channel to the authenticated
session generation, and refuses stale-generation operations before reaching the
backend. Its tests cover decoded output projection, input/resize/kill lifecycle,
and second-channel refusal. GTK attach, connect, reconnect, input, resize and
kill controls now refuse before the reducer unless the session is signed in.
Porsche SSH/PTY backend wiring and GTK stream attachment remain open.

Linux sign-in also provides a [`FileDeviceSigner`](repo:mila/native/linux/src/session.rs)
for owner-only development and release key files. It rejects symlinks and
group/world permission bits before loading raw P-256 material, and its test
verifies signatures without exposing private bytes. Hardware-backed signer
integration and the live HTTPS approval transport remain open.

The Linux deployment surface validates and stores one canonical host selection
under XDG configuration, restores it on launch, and exposes Reload and an
idempotent Forget deployment action. Reload reflects the persisted selection in
the GTK field; Forget clears that field and removes only the selection. Trust,
key and remote device records remain under their separate authorities. A
multi-deployment list and complete sign-in UI are still open.

The GTK sign-in action refuses to start until the deployment field passes the
same canonical host validator used by persistence, then saves that selection
before entering the generation-scoped flow. Native transport, approval polling
and a multi-deployment list remain separate gaps.

After sign-in, Linux exposes list, remove and enable/disable controls for
notification devices. Each action uses the authenticated session handle and
bounded device projection; an unsigned-in window refuses before any backend
call. Linux still has no provider registration or push delivery path.

Machine mutation buttons in the Linux window now keep `show` as a local
bounded projection and route start, stop, pause and resume through the
authenticated session handle. Rust validates the machine UUID, closed action
vocabulary and one-time request ID before opening Porsche; unsigned-in windows
are refused. Create, resize and live deployment transport remain open.

Sharing add/remove controls likewise require the authenticated session. Rust
validates the machine UUID, email, role vocabulary and request ID before the
Porsche mutation; remove requests cannot carry a role. The GTK shell has no
live deployment receipt yet.

Linux thread list, show and turns controls now call the authenticated session
and keep bounded response bytes inside Rust. Prompt and answer controls also
require that session, pass the thread and (for an answer) question/turn ID,
and send at most 64 KiB of stdin text. Rust requires a canonical Porsche
request ID for each prompt, answer, plan approval or plan revision mutation,
so an unsigned-in window or a missing/invalid request ID is refused before the
backend. Plan approval and revision buttons use the same bounded input field
(revision text is limited to 64 KiB); the live deployment journey remains open
in the GTK shell.

The native Rust session contract test exercises these boundaries directly:
invalid approval request IDs, missing authentication, and oversized answer
payloads are refused before FFI dispatch
(`mila/native/linux/src/session.rs`). A signed native deployment journey remains
open.


Each machine in Mila has Info, Terminals, Threads and Web tabs. A Recent grid
lists threads across machines. Every action is an ordinary Porsche command
(ADR-0222). Each mutation carries a request id and is submitted once, then
polled through `request show`. Prompts, answers and plan revisions are sent on
the exec channel's stdin, never on the command line, and are limited to 64 KiB.
Links to these pages only navigate.

| Concern | Behaviour |
| --- | --- |
| Terminal attach | `terminal attach M S [--cursor N] [--read-only]` on a PTY sized to the view, with window-change on resize. One JSON header line on stderr (at most 512 bytes) states `from`, `replay_bytes` and `mode`. Output before it is dropped. |
| Cursor resume | A dropped channel reattaches from the bytes already shown. When the header's `from` differs from the cursor, Mila resets the screen and counts a documented jump; otherwise the cursor only moves forward. |
| Read-only | Chosen or granted, read-only never sends keys, pastes or resizes. Choosing control again reattaches writable. |
| Retry | Exit 5 (transport) retries with backoff, at most 8 attempts. Exits 1 (refused), 2 (invalid) and 3 (authority) end the view with a localized reason. |
| Threads | Lists, transcript pages (`thread turns --after`), questions, plan approve and revise, plan or work mode. The read marker only moves forward (`thread read`), and open thread lists drop the unread count at once. Porsche cannot start a thread, so an empty Recent list links to Marshall's `/threads/new` page in the browser. |
| Watch | `watch` JSON lines trigger re-reads; Mila never takes state from them. More than 40 s of silence reopens the stream. Transport loss reconnects after 1 to 60 s; authority loss stops it. |
| Web | `web show`, and `web set` at the shown `policy_revision`, so a concurrent change is a conflict. Only HTTPS URLs on DNS hosts are opened. Public endpoints open in a webview on iOS and Android; private endpoints always open in the system browser, except on native Linux, which opens only public matching-port endpoints. |

```mermaid
sequenceDiagram
    participant M as Mila
    participant P as Porsche
    participant G as Guest PTY
    M->>P: terminal attach M S --cursor N (pty)
    P-->>M: stderr {attached:true, from, replay_bytes, mode}
    P-->>M: replayed bytes, then live output
    M->>P: keys (rw only), window-change
    P-->>M: exit 5 (transport)
    M->>P: terminal attach M S --cursor N' (after backoff)
```

Failure behaviour: terminal bytes exist only in the in-memory emulator. They
are never written to disk, the offline cache, preferences or logs. A paste is
bracketed and cannot carry control sequences.

Evidence:
- [command catalogue](repo:mila/packages/mila_core/lib/src/ssh_command.dart);
- [attach state machine](repo:mila/packages/mila_core/lib/src/terminal_attach.dart);
- [watch supervisor](repo:mila/packages/mila_core/lib/src/watch.dart);
- [channels](repo:mila/packages/mila_transport/lib/src/channels.dart) and the
  [OpenSSH journeys](repo:mila/packages/mila_transport/test/ssh_porsche_test.dart);
- [app flows](repo:mila/app/test/client_flow_test.dart);
- the [UI review](repo:docs/architecture/reviews/2026-10-18-mila-ui.md).

All of these tests are present; none has a recorded passing run yet.

## Terminal attach over SSH

`ssh -t control.example.test terminal attach MACHINE SESSION [--cursor N] [--read-only]`
joins a registry terminal session (the same session the browser shows) from
any SSH client. It needs a pty and is never an ordinary command; without
`-t` it exits 2 with `attach_requires_pty`. Porsche writes one JSON header
line on stderr (`{"attached":true,"mode":"rw|ro","from":N,...}` or
`{"attached":false,"error":...}`) and then relays raw terminal bytes.

| Exit | Meaning |
| --- | --- |
| 0 | The session closed or the client detached (end of input). |
| 1 | Refused: unknown session, another machine's session, forbidden, conflict. |
| 2 | Invalid: bad arguments or no pty. |
| 3 | Authority: the SSH key, approval, session or gateway credential was revoked. |
| 5 | Transport: Marshall unreachable, inconclusive authority, silence over 15 s. |

```mermaid
sequenceDiagram
    participant C as SSH client
    participant P as Porsche
    participant M as Marshall
    participant V as Terminal viewer
    C->>P: pty-req, exec "terminal attach M S"
    P->>M: commands "terminal attach" (control link)
    M-->>P: single-use ticket bound to this SSH session
    P->>M: GET /api/terminal-gateway/v1/stream (gateway bearer, SSH session, ticket)
    M->>M: session_live? before upgrade
    M->>V: upgrade with {:ssh, gateway, session} authority
    V-->>P: attached, mode, replay from cursor
    P-->>C: stderr header, then output (ack after local send)
    C->>P: input (only when rw, within 16 frames / 256 KiB credit)
    V->>M: recheck every 5 s and on ssh_session/user hints
    V-->>P: close 4001 on revocation
    P-->>C: exit 3
```

Evidence: [command grammar](repo:protocol/lib/overalls_protocol/ssh_command.ex),
[closed tables](repo:protocol/lib/overalls_protocol/terminal_attach.ex) and
[fixture](repo:protocol/test/fixtures/terminal_attach.json);
[gateway stream](repo:marshall/lib/marshall_web/terminal_gateway_api.ex),
[viewer](repo:marshall/lib/marshall/terminal/viewer.ex),
[Porsche attachment](repo:porsche/lib/porsche/terminal/attachment.ex) and
[credit](repo:porsche/lib/porsche/terminal/credit.ex);
[end-to-end test](repo:marshall/test/marshall_web/ssh_terminal_attach_test.exs),
[Porsche relay tests](repo:porsche/test/terminal_attachment_test.exs),
[credit model property](repo:porsche/test/terminal_credit_property_test.exs) and the
[fleet journey](repo:nix/verification/tests/machines/fleet/scenarios/porsche-terminal.py)
(not yet recorded passing). See [ADR-0223](repo:docs/architecture/decisions/0223-porsche-terminal-attach.md)
and the [S2 review](repo:docs/architecture/reviews/2026-10-19-mila-terminal-attach.md).

## Explicit terminal kill under withheld credit

Withheld viewer credit pauses ordinary live PTY delivery. An authorized explicit
kill cancels that delivery obligation: terminald aborts registered viewer queues,
shuts down their sockets and kills the owned process group before retirement can
reap its leader. A bounded PTY readiness wait observes cancellation even when an
independent owner holds a quiet slave. Session/ring and viewer permits return
without peer disconnection. Natural shell EOF still drains queued bytes.

Generated local Linux PTY/socket histories and fixed configured-watermark and
quiet-slave cases exercise this boundary. They do not prove authenticated vsock,
Firecracker/browser composition, aggregate 64 MiB admission or escaped descendant
cleanup. See the [review](repo:docs/architecture/reviews/2026-10-03-terminald-credit-retirement.md).

## Shared terminal scrollback admission

Generated [shared-ring histories](repo:nix/domains/artifacts/terminald/src/budget_property_tests.rs)
create actual Linux PTYs at the configured 64 MiB aggregate reservation boundary.
Fixed 1 MiB/8 MiB and generated 2/4/8 MiB initial capacities isolate memory
admission from the session-count limit. Contending final reservations refuse
without changing survivors; explicit retirement returns exact capacity for
replacement sessions. Complete retirement returns the counter to zero.
The [recorded native scope](repo:docs/architecture/reviews/2026-10-03-terminald-shared-ring-budget.md)
passed all 47 tests and Clippy. This is local admission/retirement evidence:
dynamic growth, interleaved create/retirement, child-exit/idle release,
authenticated vsock, aggregate growth/admission with mixed viewer pressure and VM/browser composition remain
separate. Reservation capacity is not measured resident memory or throughput.

## Neighboring terminal under viewer pressure

A terminal waiting for viewer credit cannot retain the shared drain mutex and
block a distinct session. Generated [neighbor histories](repo:nix/domains/artifacts/terminald/src/neighbor_property_tests.rs)
require observed live queue pressure, successive fresh executed output from
another PTY and further progress after explicit retirement of the stalled owner.
Octal command encoding prevents echoed input from satisfying the output oracle.
Both clients remain open through exact survivor identity and permit checks.
Configured witnesses cover zero credit and default watermark minus one, exact
and plus one, with generated pump-read boundaries. The refined native47-test/Clippy gate passed4.66seconds;
its [execution review](repo:docs/architecture/reviews/2026-10-03-terminald-neighbor-pressure.md)
records the exact local scope and preserves the narrower initial result. These local observations do not prove
continuous pressure between checkpoints, complete byte fidelity, throughput or
authenticated vsock/VM/browser composition.

## Retired terminal scrollback

Natural EOF drops the retired ring backing before returning its reservation, even while a stalled viewer retains the session. Independent queued output remains intact and drains when the peer resumes. Generated local Linux PTY/socket histories require zero backing allocation, exact finite NUL drain counts and final viewer permit release. The [native repair review](repo:docs/architecture/reviews/2026-10-05-terminald-retired-ring.md) records the pre-fix1MiB retention failure and passing47-test/Clippy and static factory checks. Initial1/8MiB rings remain fixed; this does not establish dynamic growth, aggregate mixed-pressure admission, RSS, authenticated vsock or VM/browser composition.

## Full ring overwrite allocation

Overwriting a full scrollback ring evicts the oldest byte before appending, reusing sufficient backing without capacity growth. The [native Ring review](repo:docs/architecture/reviews/2026-10-05-terminald-ring-overwrite.md) records the backing-bound failure and passing47-test/Clippy repair with an independent exact newest-byte/base/tail model. Fresh positive ring limits remain fixed in that property. Resize/growth, actual PTY aggregate backing, viewer-stream ordering and VM/hosted composition remain separate.

## Actual scrollback growth

The pump reserves each retention-limit increase before changing the ring. Real
Linux PTY histories grow initial 1 MiB rings to 2/4/8 MiB maxima and fill the
64 MiB aggregate reservation. Two complete output phases establish growth and
full final retention despite intermediate read-boundary truncation. Independent
backing snapshots, survivor IDs and exact output counts verify memory refusal,
retirement and replacement growth with peers still connected. The
[growth review](repo:docs/architecture/reviews/2026-10-05-terminald-growth-backing.md)
records 51 passing native tests and a control exposing 128 MiB backing against
64 MiB reserved. This standalone history serializes output across sessions;
the following scenario adds mixed stalled/healthy growth and admission. RSS,
authenticated guest authority and VM/browser/hosted composition remain open.

## Mixed growth and admission under viewer pressure

Session admission and scrollback growth share the aggregate ring reservation.
A stalled viewer must permit fresh output and memory refusal in another session.
Local Linux PTY histories race growth against creates, accepting either legal
schedule while checking exact survivor IDs, quota and actual backing. Every draw
includes the default64MiB budget,8MiB maximum and1MiB viewer watermark. Retiring
one grown session permits exact healthy growth and replacement admission while
the blocked peer remains connected. The
[mixed growth review](repo:docs/architecture/reviews/2026-10-05-terminald-mixed-growth.md)
records52passing native tests, full Marshall/forced-Dialyzer verification and
the smaller growth-limit counterexample.
Pressure is verified at explicit checkpoints; authenticated vsock, VM/browser,
RSS, sustained many-viewer throughput and hosted faults remain open.
## Threads workspace

Authenticated users can open `/threads`, create work at `/threads/new`, and
return to `/threads/:id` from any device. The new-thread page centers an objective
composer with a mode selector and a short mode explanation. Machine settings sit
inside a closed disclosure, summarize the selected machine size and use the
configured defaults unless changed. The thread index lists titles, status, mode,
updated date and an objective preview. Search matches titles and objectives
without case sensitivity, and a status selector shows all, active or archived
threads. These filters apply to the current authorized keyset page of 50
threads; First page and Next page controls walk older authorized results, and
active includes every state except archived. A detail page keeps recent
threads in a secondary rail on wide screens; narrow screens return to the list
through the Threads tab.

The conversation is the main working area. User and agent messages have distinct
role labels; tool and turn events use compact, readable status lines. Queued
tools show their names, and tool results show the recorded outcome when available.
The saved objective remains visible before transcript events arrive. When the
workspace is ready and the actor can write, the reply composer appears above the
transcript. Events show newest first, with the oldest at the bottom. A ready thread
offers Open terminal to writers,
which navigates to the bound machine's terminal page; the terminal is not embedded
in the conversation. Open VS Code appears alongside it when a fresh authorized
machine projection reports the editor available, and opens the existing machine
editor route in a new tab. That route rechecks current editor authority.
Managers receive Archive and Delete in the Actions disclosure and Reopen on
archived threads. Managers can archive or delete pending, provisioning, ready
and failed threads; a viewer receives a read-only notice. Semantic markup, text
status labels and streamed thread, activity and transcript collections use the existing monospace themes
and character grid. List, detail and transcript failures show explicit
unavailable states instead of appearing empty; missing or unavailable thread
detail refuses prompt and lifecycle events. The composer submits to the bound
machine-scoped agent thread; it never creates an independent control-plane
execution path. Pending provisioning shows preparation progress; failed
provisioning offers Retry to current managers. Polling refreshes asynchronous
provisioning state. A thread becomes ready
only after Compute reports its VM running and the initial objective is accepted.
The activity view shows dated rows with a status description and a status filter;
it summarizes the latest thread state rather than a complete event history. Each
committed event on the current bound agent thread advances the enclosing thread's
durable activity clock after the event transaction commits, so agent work moves
the row even when no user-thread attribute changed. Archived and deleting threads
are not touched, and a stale or mismatched agent binding cannot advance a row.
Project filtering remains separate work. The manager-only Share
disclosure lists the protected owner and a page of at most 50 grants, with controls
to grant, replace or revoke a registered account's viewer/operator/manager role.
It loads those details only while open, preserves its request key across failures
and clears grant controls if the read fails or management authority is lost.
Thread access also applies to its current machine; independent machine grants
and team access keep their separate lifetime. See [access control](#access).

Archived threads retain their objective and current transcript while their machine
is gone; these reads recheck current creator/team/grant visibility and the bound
agent identities, and prompt or
terminal mutations remain unavailable. Current thread managers can reopen
an archived thread. Reopen provisions a fresh machine and agent binding while
PaperTrail retains the retired identities. The workspace currently reads only
the current transcript binding by default. Authorized readers can select a
retained generation from the detail URL and read its transcript through the
generation's immutable machine/root/agent binding. Retired generations remain
read-only and do not expose prompt, terminal or editor controls. Native
archive/reopen continuity and cross-node recovery remain unverified.

One reported failed production thread recovered through its authorized retry and
remained ready after required-key deployment, with the same running VM and one
completed initial objective turn. The final inspection was read-only and submitted
no further prompt. This observation establishes that recovery and continuity;
native archive/reopen, fault recovery and cross-device acceptance remain separate
from the focused tests and synthetic browser observations recorded in the
[thread review](repo:docs/architecture/reviews/2026-10-15-user-threads.md).

## Thread commands and planning controls

The accepted [context and planning decision](repo:docs/architecture/decisions/0178-durable-agent-context-and-planning.md)
adds a Commands control to the top composer, composer-scoped Ctrl/Cmd+K and slash
completion. Implementation and browser acceptance are tracked separately in
the [context review](repo:docs/architecture/reviews/2026-10-16-agent-context-and-planning.md).

| Command | Requested operation |
| --- | --- |
| `/plan [task]` | Select Plan and optionally submit the task atomically. |
| `/work [task]` | Select Work and optionally submit the task atomically. |
| `/compact` | Compact active model context while retaining the transcript. |
| `/skills` | Browse, select and, for managers, manage installed skills. |
| `/context` | Inspect working directory, loaded sources, usage and Reload. |
| `/terminal` | Open the current bound machine's terminal when authorized. |
| `/code` | Open its eligible personal browser editor. |
| `/share` | Open manager-only thread sharing. |
| `/help` | Show command help. |

Arrow keys move the selection, Enter activates it, Tab completes it and Escape
dismisses the palette and restores focus. Touch interaction and IME composition
remain supported. Unknown commands preserve the draft and display a refusal;
a leading space submits slash-looking text literally. New-thread mode selection
does not create the machine. Plan/Work and reasoning are separate controls, and
changing collaboration mode preserves reasoning.

Structured planning questions remain visible after reconnect. Current writers
can answer the active request; viewers cannot. A completed plan is rendered as
a sanitized card with Implement plan and Revise, while partial output cannot
be implemented. The server rechecks authority and the exact proposal identity
before admitting a Work turn on the same machine. The composer stays above the
newest-first transcript throughout these interactions.

## Git settings

The authenticated `/settings#git-settings` section edits Git username, Git email
and optional agent commit trailers for the current account. It is the fourth
section of the single Account page, behind the same fresh-login gate as profile,
passkey and SSH key controls. The old settings URLs remain removed. Git email is
separate from sign-in email. Invalid or foreign-account changes refuse. Identity
changes apply to newly created machines.

Public documentation applies validated browser language negotiation without a login or session cookie. Its standalone HTML declares the negotiated `lang` and explicit `dir`, including RTL for Arabic and Urdu. Controller regression coverage checks English, Arabic, Urdu and Japanese; this does not establish visual bidi correctness or translation completeness.

Plain-text HTTP refusal messages use the negotiated locale for repository launch,
installer/download and trust failures, editor/sign-in failures, inference/raw Git
access and missing documentation. Status codes, final newlines and generic
redaction remain unchanged. Successful installer scripts, archives, manifests,
checksums, trust JSON, CSV fields and raw Git bytes retain their machine format.
Public documentation and download routes negotiate without creating sessions.
Plain-text responses carry no HTML direction attribute; HTML RTL and native
browser acceptance remain separate verification boundaries.

Porsche catalog verification compares all 25 terminal catalogs with the extracted message inventory and checks placeholders. The recorded full Porsche gate at `1f79f63e6` passed 108 tests and Dialyzer with zero errors. This establishes bounded BEAM/catalog behavior; native SSH onboarding, visual bidi behavior and native-language quality still require separate acceptance.

Porsche's human result renderer translates receipt labels, known receipt statuses
and reviewed refusal guidance, including pinning limits and protected owner
access. Command syntax such as `unpin MACHINE`, request/operation identifiers,
unknown keys, nested result data and all JSON output retain their literal machine
representation. A translated refusal does not change retry eligibility or grant
authority; inspect current machine/request state before repeating a mutation.

## Android display authority

Android-capable machines may mint a short-lived, machine- and actor-bound display
claim through Marshall. The guest relay remains responsible for current emulator
generation and controller-lease checks; a viewer claim cannot send input. Claims
are refused for images without the `android_display` capability and do not expose
ADB or RFB through a public browser route.

The machine workspace exposes Android display controls only when the image's
`android_display` capability is present. Viewer and controller ticket requests
remain authenticated LiveView events; the browser relay must still enforce
current generation and controller lease before opening RFB.

The Android relay state machine permits read-only viewers and one controller,
advances frame sequence numbers monotonically, and revokes controller authority
when its process exits or the emulator generation changes.

The Android display hook uses a same-origin WebSocket URL supplied by the page,
keeps viewer input disabled, and sends controller key/pointer frames only after
a controller ticket is granted. It does not use a foreign iframe or external
resource.

The `/android-display` WebSocket upgrade verifies the browser login, signed
machine ticket, actor binding, mode and generation before obtaining the shared
relay from the machine-and-generation registry. Sockets for that generation
share controller custody; failed upgrades return a generic refusal without
machine disclosure.

Display tickets and WebSocket upgrades bind the signed emulator generation; a
browser-supplied generation mismatch is refused before relay creation.

The host-stream adapter drops stale Android frames before relay publication and
routes input only from controller-authorized sockets back toward Lilly.
# Android display transport

Android-capable Linux guests expose a software-rendered emulator display through
the authenticated terminal host stream. Marshall issues a short-lived machine
and generation-bound ticket; the shared relay permits multiple read-only viewers
and one controller. RFB bytes remain opaque and bounded, and generation or host
stream loss closes the bridge. Native Firecracker and browser journey evidence
remains partial until the composed acceptance test is recorded.
The bridge is shared per machine generation, so additional browser viewers reuse
the authenticated guest channel rather than opening independent guest sockets.

## Machine creation presets

`/settings#machine-defaults` contains three independent presets under the existing
fresh-login account gate. Each stores profile, operating-system image, vCPU,
memory in MiB and disk in GiB. `/launch` starts with OSS; `/machines/new` and
`/threads/new` start with Work, the existing `standard` machine profile. The
thread's Work collaboration mode is separate and remains its initial mode.

Saving validates an enabled ordinary image, whole-unit sizes within execution
limits and image minima. Launch offers only images with current source2 and
workspace capability. An unavailable catalog is shown explicitly; it grants no
capacity or authority. Saved image selections that later become ineligible fall
back to a usable configured/catalog image. Invalid saved sizes fall back to
rounded image minima. If no suitable image exists, creation remains unavailable.

Machine URL drafts override the preset and retain their request key through
validation, refresh and reload. Thread form edits survive periodic refresh.
One-off Customer and Inception machine choices remain available through their
existing form and admission policy. Saving a preset changes neither an existing
machine nor another preset. New launch visits use current preferences; an admitted
visit reuses its original persisted request before ordinary Compute admission,
even after preference changes or loss of live image availability.

Submitting `/machines/new` first checks the requested memory and disk against the
selected enabled image's catalog minima with the rule Compute admission enforces
([`Image.requirements_met?/2`](repo:marshall/lib/marshall/compute/image.ex)). A
smaller size, or an image that is no longer enabled, shows the localized refusal on
the retained form and creates no setup thread or machine. Passing this check grants
nothing: the setup thread's `ProvisionWorker` still performs transactional admission
and marks a thread failed when an undersized request arrives by another path.

The [preset decision](repo:docs/architecture/decisions/0240-account-machine-creation-presets.md)
and [focused tests](repo:marshall/test/marshall_web/machine_defaults_test.exs)
distinguish application behavior from native execution and rollout acceptance.

### Windows Rust interop verification

The `windows-native` CI job builds the Rust DLL, stages it beside the WinUI
executable, then supplies that staged file to `mila/windows-dotnet-smoke`.
This .NET 10 console executable compiles the production `RustNative.cs` without
WinUI. It requires ABI version 1.0, canonical host-qualified routing, validated
snapshot counts and 64-bit timestamps, rejection of foreign deployments,
malformed and oversized snapshots, and bounded route output with guard bytes.
The production Windows adapter also projects machine action flags directly from
Rust, rejects foreign snapshots and missing machine indexes, and formats bounded
machine commands through Rust. Smoke cases cover the action bit layout, missing
mutation request IDs, injected action tokens and embedded NUL refusal. Formatting
does not authenticate or submit commands; native transport and UI integration
remain separate work.
A missing DLL, missing export or incompatible image fails the smoke test rather
than accepting the production wrapper's `Unavailable` fallback. This is adapter
verification; it does not establish Windows UI, lifecycle, key custody, packaged
release or deployment acceptance. Windows execution remains CI evidence until a
passing run is recorded.

The native Apple `MilaDeviceSigner` retains one permanent Secure Enclave P-256
key per validated deployment hostname, using the existing application tag and
macOS data-protection keychain. Only a missing key permits creation; denied or
invalid keychain lookups fail closed. It exposes a public SSH key and bounded
SHA-256 ECDSA signing with 64-byte `r || s` results for the Rust signer callback.
It has no software-key fallback. Swift tests cover hostname rejection and DER
conversion, but signed-device Secure Enclave execution and live-session wiring
remain unverified; unsigned CI cannot establish hardware key custody.

### Live native session FFI

The shared `mila-ffi` library now exposes a bounded live session ABI backed by
`mila-session` and certificate-pinned Porsche SSH. Native callers supply an
OpenSSH P-256 public key and a synchronous callback that signs only during
certificate-authenticated connect; the callback returns fixed-width `r||s` and
never exports a private key. Opaque handles are bounded and non-reusable;
refresh/pagination are explicit I/O operations, while listing and complete
snapshot copies are bounded sizing-aware reads. Close removes the handle before
transport teardown. Real loopback SSH tests cover connect, listing, snapshot,
refused refresh and stale-handle refusal. This establishes Rust FFI/session
behavior only; platform callback/key-custody integration and production
multi-device acceptance remain open.

Android's native shell uses the same connection for browser approval. Rust
returns the bounded `whoami --json` envelope even when Porsche reports a
pending key, and Kotlin accepts only an HTTPS URL with a valid SSH fingerprint.
The browser intent is navigation-only; the URL and fingerprint stay in memory
and are never written to deployment preferences. After the user approves the
key, Android polls `whoami` on that existing session every two seconds before
publishing the machine listing. Closing, reconnecting or a failed refresh closes
the pending handle and leaves only the validated deployment selection persisted.
The Android unit tests cover malformed and foreign approval URLs; a packaged
device browser journey remains unverified.

The Android machine list and detail route consume only the listing published
after that authenticated session reaches `SignedIn`. Detail mutations carry
closed `MilaMachineCommand` values through the same bound Rust session and
render their submitting/applied/refused state after the suspend call returns;
there is no UI-only command submission path. Compose release and live-device
execution of these controls remain unverified.

Android Threads follows the same authenticated-session boundary. `thread ls`
returns a bounded, UUID-validated listing before Compose offers a detail route;
prompt, answer and plan actions accept only bounded text and closed command tags,
then render the typed submitting/applied/refused result from the Rust session.
No thread bytes or credentials enter deployment preferences. Packaged Android
thread acceptance and server-side authorization remain unverified.

Android web controls call `web show` and `web set` through the bound Rust
session. The endpoint decoder bounds the response, requires the requested
machine UUID and accepts only HTTPS URLs without user-info or fragments before
loading the WebView. Updates use the returned policy revision and refresh the
endpoint after the mutation; packaged WebView and live authorization evidence
remain unverified.

Android's terminal controller keeps attach mode, dimensions, reconnect and
close as typed state and accepts input only while attached read-write. Its text
renderer strips control bytes, caps each line at 4 KiB and retains 200 lines;
the native seam validates attach, input and resize against the authenticated
session boundary. A live PTY stream, kill authority and packaged-device
execution remain unverified.
