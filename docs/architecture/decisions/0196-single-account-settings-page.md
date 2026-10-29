# ADR-0196: One account settings page

- ID: ADR-0196
- Date: 2026-10-18
- Status: accepted
- Implementation: partial
- Components: MarshallWeb, protocol (SSH onboarding hint), NixOS browser tests
- Supersedes: none
- Superseded by: none

## Context

Marshall's signed-in sidebar listed three "Your account" pages, each its own
LiveView: `/settings/profile` (`ProfileLive`, email and the display time zone
of [ADR-0195](0195-user-time-zones.md)), `/settings/security`
(`SecurityLive`, passkey enrollment, verification, the elevation return path
of [ADR-0160](0160-privileged-administrator-step-up.md) and passkey
management) and `/settings/ssh-keys` (`SSHKeysLive`, the owner-scoped keys of
[ADR-0046](0046-porsche-ssh-management.md)). `/settings` itself was a
controller redirect to the profile. The user asked for Security and SSH keys
to be collapsed into one completely redesigned page.

Observed facts before the change:

- `SecurityLive` mounted through `{MarshallWeb.LiveUserAuth, :security}`;
  `SSHKeysLive` and `ProfileLive` through `:live_user_required`. Both modes
  run the same clause: verify the stored login against the assigned user at
  mount and attach fresh-login hooks for events, messages and params
  ([ADR-0022](0022-browser-terminal-and-live-login-checks.md)). The
  `:security` name is the pin the former Security page carried.
- `MarshallWeb.AuthenticationPrivacy` tagged only `/settings/security` and
  `/settings/ssh-keys` HTTP requests as authentication paths, because the
  pages carry passkey ceremonies and pasted SSH key material.
- `LiveAdminAuth` redirected a no-key administrator to
  `/settings/security?return_to=…`; the SSH approval page navigated to
  `/settings/ssh-keys`; the protocol's `OverallsProtocol.SSHOnboarding`
  banner, `priv/docs/quickstart.md`, the NixOS browser tests, the Antithesis
  access workload and the browser probes named the three URLs.
- The three pages shared no state: each read its own projection with the
  socket actor through `User`'s `:security` generic action, `Marshall.SSH`
  and `User.set_time_zone`.

The user accepted breaking the old links: no redirects are kept.

## Decision

Accepted on 2026-10-18 under the user's request to collapse and redesign the
settings pages ("consult fable and do it"); the user later dropped the
old-link requirement ("breaking changes acceptable for links").

1. **One page with anchored sections.** `MarshallWeb.AccountLive` serves
   `/settings` with, in this order, `#profile` (email, local clock, time zone
   picker), `#security` (verification status,
   ceremony buttons, the
   elevation return link, the passkey list with rename and remove) and
   `#ssh-keys` (registered keys, then the add form). A numbered index at the
   top links each section; `<hr>` double rules separate them. Profile leads
   because it is identity and the most benign; sign-in follows because the
   step-up flow lands there; SSH keys follow because they are the outbound
   credential. [ADR-0198](0198-git-attribution-and-guest-identity.md) appends
   a fourth `#git-settings` section for Git author defaults and optional agent
   commit attribution, preserving that original three-section order.
   There is no account-deletion section: self-service deletion
   does not exist (retirement is an administrator action, ADR-0158), and
   this decision adds no new capability.
2. **The strict gate covers the whole page.** `AccountLive` mounts through
   `{MarshallWeb.AuthenticationPrivacy, :default}` and
   `{MarshallWeb.LiveUserAuth, :security}` only, so the profile and SSH
   sections now sit behind the same required-login mount and fresh-login
   hooks the Security page had. The appended Git section uses that same gate.
   `AuthenticationPrivacy` tags every
   `/settings` request. `safe_return/2`, the `:security` action, `SSH`
   domain calls, `set_time_zone`, every `data-confirm` on a destructive
   button, the one-second verification countdown and the catalogued events
   are unchanged; the page renders no credential material beyond the
   fingerprints, labels and passkey names it rendered before.
3. **URL scheme without redirects.** `/settings/profile`, `/settings/security`
   and `/settings/ssh-keys` are removed and answer 404. Deep links use
   fragments: the administrator step-up redirect becomes
   `/settings?return_to=<path>#security`, the SSH approval page and the
   protocol onboarding hint use `/settings#ssh-keys`, and the account menu's
   time zone link uses `/settings#profile`. Fragments never carry
   authority; `return_to` keeps its allowlist.
4. **One sidebar entry.** The "Your account" tree opens with Account
   (`#nav-account`, `/settings`),
   followed by AI usage (`#nav-usage`, `/usage`, moved out of "Your
   workspace"), then the existing browser extension, field notes, HLDD and
   source code links. (Correction: [ADR-0263](0263-retire-hldd.md) removed the
   HLDD link; Source code now follows field notes.) `#nav-profile` and the Security and SSH keys entries
   are gone.
5. **Stable contracts.** Every element id, hook, `data-*` and label that the
   LiveView tests, the browser probes, the NixOS browser tests and the
   Antithesis workload consume is retained (`#verification-status`,
   `#passkey-ceremony`, `#add-passkey`, `#verify-passkey`,
   `#lock-elevation`, `#security-continue`, `#passkey-list > div`,
   `#label-<id>`, `#remove-<id>`, `#ssh-key-form`, `#add-ssh-key`,
   `#ssh-keys-empty`, `article#ssh-key-<id>`, `#remove-ssh-key-<id>`,
   `#profile-account`, `#time-zone-form`, `#profile_time_zone`,
   `#time-zone-status`, `#save-time-zone`, `#clear-time-zone`,
   `#profile-local-clock`, the "Public key" and "Label (optional)" labels).
   The SSH and time zone LiveView event names are namespaced
   (`add_ssh_key`, `remove_ssh_key`, `save_time_zone`, `clear_time_zone`);
   the passkey events (`begin`, `finish`, `cancelled`, `credential`) keep
   their names because the ceremony hook and the Antithesis workload send
   them.

This amends ADR-0195 item 6 (the profile page and sidebar placement) and the
page named by ADR-0160's no-key setup return and ADR-0046's browser key
management; their authority rules are untouched.

[ADR-0240](0240-account-machine-creation-presets.md) appends a fifth `#machine-defaults` section with three independent creation presets. The page retains its strict security mount, section order and existing controls.

## Alternatives

- **Merge Security and SSH keys but keep Profile separate.** Leaves two
  sidebar entries for one person's own settings and keeps `/settings` as a
  redirect. Rejected: the profile page shipped the same day with one field,
  and a single page with an index reads better than two.
- **Keep the old URLs as redirects.** Offered first; the user withdrew the
  requirement. Rejected to avoid three permanent controller routes whose
  only job is to carry `return_to` into a fragment.
- **Tabs or `<details>` per section.** Hidden sections break the NixOS
  browser tests that fill the "Public key" field directly and would hide
  the verification status an administrator is sent to read. Rejected for
  one scrollable page with anchors.
- **Add a danger zone.** There is no self-service account deletion to put in
  it; inventing one is a separate authority decision.

## Consequences

- One LiveView process per visit runs the one-second passkey countdown and
  reads the key list; the per-second `:status` read is the same as before.
- Bookmarks and emails that named the old URLs now 404; the quickstart doc,
  the CLI banner and the approval page point at the new anchors.
- The NixOS browser tests, the passkey probe and the Antithesis access
  workload were rewritten to the new URL by inspection; they were not
  executed in this change.
- The profile and SSH sections gain the `:security` mount name and the
  privacy tag; no behavior they had is weakened.

## Invariants and verification

- `AccountLive.__live__().lifecycle.mount` ids are exactly
  `[{AuthenticationPrivacy, :default}, {LiveUserAuth, :security}]` and
  `/settings` routes to `AccountLive` (`account-page-strict-mount-pin`).
- Revoking the persisted login halts the next SSH event and the next clock
  tick with a sign-in redirect (`clock-tick-rechecks-login`,
  `revoked browser login cannot change keys`).
- The old paths answer 404; the sidebar carries no `/settings/*` link and
  one `#nav-account`; the admin step-up redirect and the Users page link are
  `/settings?return_to=%2Fadmin%2Fusers#security`.
- Passkey rename/remove refusals, administrator last-passkey refusal, launch
  return allowlisting, forged SSH removal and private-material clearing keep
  their former assertions on the merged page.
- The browser probe (`check_account`) checks the single navigation entry,
  section order, anchors landing at the top, the zone picker round trip and
  grid alignment in both themes; screenshots cover desktop and 390 px.

## Implementation evidence

- The 2026-10-18 integration review found conflicting later route/navigation
  declarations. The repair restores the single `#nav-account` entry and strict
  `AccountLive` mount, and moves the existing Git-preferences form into its
  fourth `#git-settings` section with its stable field IDs. This preserves the subsequent
  [ADR-0198](0198-git-attribution-and-guest-identity.md) feature within this page;
  it introduces no weaker settings route. Current validation is recorded in the
  [integration review](../reviews/2026-10-18-github-com-integration.md).
- Page: [`account_live.ex`](../../../marshall/lib/marshall_web/live/account_live.ex);
  routes: [`router.ex`](../../../marshall/lib/marshall_web/router.ex)
  (`live "/settings"`, old routes and the `/settings` controller redirect removed);
  privacy tag: [`authentication_privacy.ex`](../../../marshall/lib/marshall_web/authentication_privacy.ex);
  redirect and links: [`live_admin_auth.ex`](../../../marshall/lib/marshall_web/live_admin_auth.ex),
  [`users_live.ex`](../../../marshall/lib/marshall_web/live/admin/users_live.ex),
  [`ssh_approval_live.ex`](../../../marshall/lib/marshall_web/live/ssh_approval_live.ex),
  [`ssh_onboarding.ex`](../../../protocol/lib/overalls_protocol/ssh_onboarding.ex),
  [`quickstart.md`](../../../marshall/priv/docs/quickstart.md);
  sidebar: [`layouts.ex`](../../../marshall/lib/marshall_web/components/layouts.ex)
  (`signed-in-account-navigation`); styles: [`workspace.css`](../../../marshall/assets/css/workspace.css)
  (`.account-index`, `.account-section`, `.passkey`).
- Tests: [`account_live_test.exs`](../../../marshall/test/marshall_web/account_live_test.exs)
  (sections, navigation, mount pin, 404s, every former Security, SSH-key and
  profile-page assertion, plus the fourth Git section),
  [`settings_live_test.exs`](../../../marshall/test/marshall_web/settings_live_test.exs)
  (Git preferences and revoked-login refusal through the same page),
  [`local_time_live_test.exs`](../../../marshall/test/marshall_web/local_time_live_test.exs)
  (people's local time, unchanged), updated `ssh_approval_live_test.exs`,
  `logged_out_access_test.exs`, `remember_me_login_test.exs`,
  `magic_link_flow_test.exs` and `auth_controller_test.exs`; Covenant
  `marshall.web_surface` module list.
- Browser: [`monospace_browser_probe.py`](../../../marshall/scripts/monospace_browser_probe.py)
  (`check_account`, `account` route in both themes and at 390 px),
  [`passkey_browser_probe.py`](../../../marshall/scripts/passkey_browser_probe.py),
  the NixOS browser tests under `nix/verification/tests/machines/` and the
  Antithesis `access` workload, all rewritten to `/settings` by inspection.
- Review: [2026-10-18 account settings page](../reviews/2026-10-18-account-settings-page.md)
  records the checks run and their results.

Remaining: the NixOS browser tests and the Antithesis workload have not been
executed against the merged page; the browser probe inherits the pre-existing
thread-page failures recorded in the review.

## Open questions

None.

## Related decisions

[ADR-0195](0195-user-time-zones.md) (profile page amended),
[ADR-0160](0160-privileged-administrator-step-up.md) (no-key setup return
now lands on `/settings#security`),
[ADR-0046](0046-porsche-ssh-management.md) (browser key management now at
`/settings#ssh-keys`),
[ADR-0198](0198-git-attribution-and-guest-identity.md) (the appended Git section),
[ADR-0161](0161-monospace-web-presentation.md),
[ADR-0022](0022-browser-terminal-and-live-login-checks.md).
