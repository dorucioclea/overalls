defmodule MarshallWebSurfaceContractTest do
  use Covenant.Case, component: "marshall.web_surface"

  @tag obligation: "marshall.web_surface.I1"
  test "declared modules compile and remain loadable" do
    modules = [
      Marshall.Localization,
      Marshall.LocalizedMarkdown,
      Marshall.DocumentationMessages,
      MarshallWeb,
      MarshallWeb.AccountLive,
      MarshallWeb.Admin.AccessLive,
      MarshallWeb.Admin.AuditLive,
      MarshallWeb.Admin.GitLive,
      MarshallWeb.Admin.JobsLive,
      MarshallWeb.Admin.LillyNodesLive,
      MarshallWeb.Admin.OperationsLive,
      MarshallWeb.Admin.UsersLive,
      MarshallWeb.Admin.WorkloadsLive,
      MarshallWeb.AdminElevation,
      MarshallWeb.AgentCLIApprovalLive,
      MarshallWeb.AgentCLIController,
      MarshallWeb.AgentThreadsLive,
      MarshallWeb.AudiLoginController,
      MarshallWeb.AuthController,
      MarshallWeb.AuthOverrides,
      MarshallWeb.AuthText,
      MarshallWeb.AuthenticationPrivacy,
      MarshallWeb.AutomaticMagicSignInLive,
      MarshallWeb.BrowserMessages,
      MarshallWeb.BrowserSession,
      MarshallWeb.CloneComponents,
      MarshallWeb.ControlAPI,
      MarshallWeb.CoreComponents,
      MarshallWeb.DatabaseWait,
      MarshallWeb.DocsController,
      MarshallWeb.DocsHTML,
      MarshallWeb.EditorController,
      MarshallWeb.Endpoint,
      MarshallWeb.ErrorHTML,
      MarshallWeb.ErrorJSON,
      MarshallWeb.FleetEndpoint,
      MarshallWeb.Gettext,
      MarshallWeb.GitLive,
      MarshallWeb.GitRawController,
      MarshallWeb.Health,
      MarshallWeb.InferenceExportController,
      MarshallWeb.InferenceLive,
      MarshallWeb.IngressAPI,
      MarshallWeb.IngressKnownHosts,
      MarshallWeb.IntegrationsLive,
      MarshallWeb.LaunchLive,
      MarshallWeb.Layouts,
      MarshallWeb.LiveAdminAuth,
      MarshallWeb.LiveSocket,
      MarshallWeb.LiveUserAuth,
      MarshallWeb.LocalePlug,
      MarshallWeb.MachineDefaults,
      MarshallWeb.MachineWorkspace,
      MarshallWeb.MachinesLive,
      MarshallWeb.MarvinDownloadController,
      MarshallWeb.NoIndex,
      MarshallWeb.ObservedRouter,
      MarshallWeb.OverallsController,
      MarshallWeb.OverallsInstaller,
      MarshallWeb.OverviewLive,
      MarshallWeb.PageController,
      MarshallWeb.PageHTML,
      MarshallWeb.PendingLaunch,
      MarshallWeb.ProvisionerAPI,
      MarshallWeb.PublicIngress,
      MarshallWeb.RepositoryLaunchController,
      MarshallWeb.ResizeLive,
      MarshallWeb.Router,
      MarshallWeb.SSHAPI,
      MarshallWeb.SSHApprovalLive,
      MarshallWeb.SSHApprovalLogin,
      MarshallWeb.SecurityHeaders,
      MarshallWeb.TeamsLive,
      MarshallWeb.Telemetry,
      MarshallWeb.TerminalLive,
      MarshallWeb.TerminalLogFilter,
      MarshallWeb.TerminalNames,
      MarshallWeb.TerminalOpening,
      MarshallWeb.TerminalPeerAPI,
      MarshallWeb.TerminalSocket,
      MarshallWeb.ThreadCommands,
      MarshallWeb.ThreadsLive,
      MarshallWeb.TimeComponents,
      MarshallWeb.WorkspaceComponents
    ]

    assert Enum.all?(modules, &Code.ensure_loaded?/1)
  end

  @tag obligation: "marshall.web_surface.I4"
  test "readiness backstop decisions are bounded" do
    now = 1_000
    assert Marshall.Operations.Health.decide(nil, :ready, now) == {true, now}
    assert Marshall.Operations.Health.decide(now, :not_ready, now + 1) == {false, nil}
    assert Marshall.Operations.Health.decide(nil, :inconclusive, now) == {false, nil}
    assert Marshall.Operations.Health.decide(now, :inconclusive, now + 29_999) == {true, now}
    assert Marshall.Operations.Health.decide(now, :inconclusive, now + 30_000) == {false, now}
  end

  @tag obligation: "marshall.web_surface.I3"
  test "readiness refusal is fixed and uncached" do
    previous = Application.get_env(:marshall, :health_ready)
    Application.put_env(:marshall, :health_ready, false)

    on_exit(fn ->
      if previous == nil,
        do: Application.delete_env(:marshall, :health_ready),
        else: Application.put_env(:marshall, :health_ready, previous)
    end)

    # Health delegates to the operations probe; an unavailable probe must not expose diagnostics.
    conn = Plug.Test.conn(:get, "/health/ready") |> MarshallWeb.Health.call([])
    assert conn.status in [200, 503]
    assert Plug.Conn.get_resp_header(conn, "cache-control") == ["no-store"]
    assert conn.resp_body in ["ok\n", "unavailable\n"]

    head = Plug.Test.conn(:head, "/health/ready") |> MarshallWeb.Health.call([])
    assert head.resp_body == ""
    assert Plug.Conn.get_resp_header(head, "cache-control") == ["no-store"]
  end

  @tag obligation: "marshall.web_surface.I2"
  test "live health probe is fixed and uncached" do
    conn = Plug.Test.conn(:get, "/health/live") |> MarshallWeb.Health.call([])
    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "cache-control") == ["no-store"]
    assert conn.resp_body == "ok\n"

    head = Plug.Test.conn(:head, "/health/live") |> MarshallWeb.Health.call([])
    assert head.status == 200
    assert head.resp_body == ""
  end

  @tag obligation: "marshall.web_surface.I7"
  test "security headers are fixed, single and strict for script" do
    conn = Plug.Test.conn(:get, "/health/live") |> MarshallWeb.SecurityHeaders.call([])
    headers = MarshallWeb.SecurityHeaders.headers()

    for {name, value} <- headers do
      assert Plug.Conn.get_resp_header(conn, name) == [value]
    end

    [policy] = Plug.Conn.get_resp_header(conn, "content-security-policy")
    assert "script-src 'self' 'wasm-unsafe-eval'" in String.split(policy, "; ")
    refute MarshallWeb.SecurityHeaders.development_tooling?()
    assert policy == MarshallWeb.SecurityHeaders.policy(false)

    assert Enum.map(headers, &elem(&1, 0)) == [
             "content-security-policy",
             "permissions-policy",
             "cross-origin-opener-policy",
             "cross-origin-resource-policy",
             "referrer-policy",
             "x-content-type-options",
             "x-frame-options",
             "x-permitted-cross-domain-policies"
           ]
  end

  @tag obligation: "marshall.web_surface.I8"
  test "secure session options are host-prefixed, secure and encrypted" do
    secure = MarshallWeb.BrowserSession.options(:secure)
    assert secure[:key] == "__Host-marshall"
    assert secure[:secure] == true
    assert secure[:http_only] == true
    assert secure[:path] == "/"
    assert secure[:same_site] == "Lax"
    assert is_binary(secure[:encryption_salt]) and byte_size(secure[:encryption_salt]) >= 16
    refute Keyword.has_key?(secure, :domain)

    plain = MarshallWeb.BrowserSession.options(:plain)
    assert plain[:key] == "_marshall_key"
    refute Keyword.has_key?(plain, :secure)
    assert plain[:encryption_salt] == secure[:encryption_salt]
  end
end
