---
modules: [Marshall.Localization, Marshall.LocalizedMarkdown, Marshall.DocumentationMessages, Marshall.Observability, Marshall.SLO, MarshallWeb, MarshallWeb.AccountLive, MarshallWeb.Admin.AccessLive, MarshallWeb.Admin.AuditLive, MarshallWeb.Admin.GitLive, MarshallWeb.Admin.JobsLive, MarshallWeb.Admin.LillyNodesLive, MarshallWeb.Admin.OperationsLive, MarshallWeb.Admin.UsersLive, MarshallWeb.Admin.WorkloadsLive, MarshallWeb.AdminElevation, MarshallWeb.AgentCLIApprovalLive, MarshallWeb.AgentCLIController, MarshallWeb.AgentThreadsLive, MarshallWeb.AudiLoginController, MarshallWeb.AuthController, MarshallWeb.AuthOverrides, MarshallWeb.AuthText, MarshallWeb.AuthenticationPrivacy, MarshallWeb.AutomaticMagicSignInLive, MarshallWeb.BrowserMessages, MarshallWeb.BrowserSession, MarshallWeb.CloneComponents, MarshallWeb.ControlAPI, MarshallWeb.CoreComponents, MarshallWeb.DatabaseWait, MarshallWeb.DocsController, MarshallWeb.DocsHTML, MarshallWeb.EditorController, MarshallWeb.Endpoint, MarshallWeb.ErrorHTML, MarshallWeb.ErrorJSON, MarshallWeb.FleetEndpoint, MarshallWeb.Gettext, MarshallWeb.GitLive, MarshallWeb.GitRawController, MarshallWeb.Health, MarshallWeb.InferenceExportController, MarshallWeb.InferenceLive, MarshallWeb.IngressAPI, MarshallWeb.IngressKnownHosts, MarshallWeb.IntegrationsLive, MarshallWeb.LaunchLive, MarshallWeb.Layouts, MarshallWeb.LiveAdminAuth, MarshallWeb.LiveSocket, MarshallWeb.LiveUserAuth, MarshallWeb.LocalePlug, MarshallWeb.MachineDefaults, MarshallWeb.MachineWorkspace, MarshallWeb.MachinesLive, MarshallWeb.MarvinDownloadController, MarshallWeb.NoIndex, MarshallWeb.ObservedRouter, MarshallWeb.OverallsController, MarshallWeb.OverallsInstaller, MarshallWeb.OverviewLive, MarshallWeb.PageController, MarshallWeb.PageHTML, MarshallWeb.PendingLaunch, MarshallWeb.ProvisionerAPI, MarshallWeb.PublicIngress, MarshallWeb.RepositoryLaunchController, MarshallWeb.ResizeLive, MarshallWeb.Router, MarshallWeb.SSHAPI, MarshallWeb.SSHApprovalLive, MarshallWeb.SSHApprovalLogin, MarshallWeb.SecurityHeaders, MarshallWeb.SignOutOverrides, MarshallWeb.TeamsLive, MarshallWeb.Telemetry, MarshallWeb.TerminalLive, MarshallWeb.TerminalLogFilter, MarshallWeb.TerminalNames, MarshallWeb.TerminalOpening, MarshallWeb.TerminalPeerAPI, MarshallWeb.TerminalSocket, MarshallWeb.ThreadCommands, MarshallWeb.ThreadsLive, MarshallWeb.TimeComponents, MarshallWeb.WorkspaceComponents]
---

# Web Surface obligations

## Purpose

The component's declared Elixir modules remain present, compilable, and owned by this Contract. Behavioral, security, persistence, native, and deployment requirements remain linked through the repository's existing `CONTRACTS` and ADR evidence.

### marshall.web_surface.I1 — Declared modules remain loadable
- **scope:** the modules listed in this component's `modules` front matter
- **must:** Every declared module MUST compile and remain loadable in the project's test VM; removing or renaming one MUST make this contract test fail.
- **kind:** non-functional
- **status:** active

### marshall.web_surface.I2 — Health probes disclose no session data
- **scope:** `MarshallWeb.Health`
- **must:** Live health responses MUST be fixed, uncached text; HEAD responses MUST have an empty body.
- **kind:** security
- **status:** active

### marshall.web_surface.I3 — Readiness reports unavailable state without leaking diagnostics
- **scope:** `MarshallWeb.Health` `/health/ready`
- **must:** Readiness MUST return `503` with the fixed `unavailable` body when the operations health check is false, preserve `no-store`, and emit an empty body for HEAD.
- **kind:** security
- **status:** active

### marshall.web_surface.I4 — Readiness backstop is bounded
- **scope:** `Marshall.Operations.Health.decide/3`
- **must:** Ready observations are recorded, definite failures clear readiness, and inconclusive observations are accepted only within the configured backstop window.
- **kind:** functional
- **status:** active

### marshall.web_surface.I5 — Pending launches are bounded and expire
- **scope:** `MarshallWeb.PendingLaunch.new/3` and `validate/2`
- **must:** Pending launch records MUST require canonical sources and 128-bit visit nonces, expire within the configured lifetime, and reject malformed or expired records.
- **kind:** security
- **status:** active

### marshall.web_surface.I6 — Terminal names are deterministic and bounded
- **scope:** `MarshallWeb.TerminalNames.display_name/1`
- **must:** The same session identifier MUST always produce the same adjective-noun label, and labels MUST remain within the fixed vocabularies.
- **kind:** functional
- **status:** active

### marshall.web_surface.I7 — Every response carries the browser security headers
- **scope:** `MarshallWeb.SecurityHeaders`
- **must:** The plug MUST set exactly one `content-security-policy` whose `script-src` is `'self'` plus `'wasm-unsafe-eval'` alone (ADR-0230: WebAssembly compilation for the terminal image decoder, never JavaScript eval or inline/foreign script), plus `permissions-policy`, `cross-origin-opener-policy: same-origin`, `cross-origin-resource-policy: same-origin`, `referrer-policy`, `x-content-type-options: nosniff`, `x-frame-options: SAMEORIGIN` and `x-permitted-cross-domain-policies: none`; the test build MUST compile the production policy. Browser rendering under this policy is evidenced by the Playwright probe, not by this BEAM test.
- **kind:** security
- **status:** active

### marshall.web_surface.I8 — The production session cookie is host-prefixed and encrypted
- **scope:** `MarshallWeb.BrowserSession.options/1`
- **must:** `:secure` options MUST name the cookie `__Host-marshall` with `secure`, `http_only`, `path: "/"`, `same_site: "Lax"`, no `domain` and an `encryption_salt`; `:plain` options MUST keep `_marshall_key` for `http` development. Production deployment of these options is not established by this test.
- **kind:** security
- **status:** active

### marshall.web_surface.I9 — Converted timestamps keep UTC provenance
- **scope:** `MarshallWeb.TimeComponents.timestamp/1`, `person/1` and `local_time/1`
- **must:** A rendered timestamp MUST keep the UTC instant in its `datetime` attribute and `title` while its text names the viewer zone's abbreviation; a person's local-time line MUST render only when the caller passes that person's saved zone and MUST state the difference from the viewer with "ahead of you", "behind you" or "same time as you".
- **kind:** security
- **status:** active

### marshall.web_surface.I10 — Locale selection is bounded and directional
- **scope:** `Marshall.Localization` and `MarshallWeb.LocalePlug`
- **must:** Explicit supported account preferences MUST override browser inference; malformed or unsupported tags MUST fall back to English without constructing atoms. Arabic and Urdu MUST select RTL; Japanese MUST select LTR. Session-bearing browser responses MUST vary on Cookie and Accept-Language.
- **kind:** functional
- **status:** active
