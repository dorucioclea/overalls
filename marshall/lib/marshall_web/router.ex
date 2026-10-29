defmodule MarshallWeb.Router do
  use MarshallWeb, :router

  import Oban.Web.Router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {MarshallWeb.Layouts, :root})
    plug(:protect_from_forgery)
    # @cc [owner:ghuntley,label:security] remembered-login-is-not-email-or-mfa
    # A persistent remember credential MAY establish a new stored browser login,
    # but MUST NOT copy passkey proof or establish fresh email authentication.
    # Required-login hooks and HTTP domain admission still check that new login.
    plug(:sign_in_with_remember_me)
    plug(:load_from_session)
    plug(MarshallWeb.LocalePlug, session: true)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:load_from_bearer)
    plug(:set_actor, :user)
  end

  pipeline :agent_cli_api do
    plug(:accepts, ["json"])
  end

  pipeline :ssh_approval_login do
    plug(MarshallWeb.SSHApprovalLogin)
  end

  # Public installer, documentation and extension routes: no session, no CSRF
  # token. Security headers come from MarshallWeb.SecurityHeaders at the endpoint.
  pipeline :public_documentation do
    plug(MarshallWeb.LocalePlug)
  end

  scope "/", MarshallWeb do
    pipe_through(:public_documentation)

    # @cc [owner:ghuntley,label:architecture;security] public-cli-bin-routes
    # Public CLI delivery MUST use only the /bin shell and PowerShell
    # installers, manifest, five allowlisted platform artifacts, and matching
    # checksum paths.
    get("/bin/ssh-trust.json", OverallsController, :ssh_trust)
    get("/bin/install.sh", OverallsController, :install)
    get("/bin/install.ps1", OverallsController, :install_powershell)
    get("/bin/manifest.json", OverallsController, :manifest)
    get("/bin/sha256/:target", OverallsController, :checksum)
    # @cc [owner:ghuntley,label:security] public-marvin-bin-routes
    # Extension delivery MUST use exact public archive routes and an independent
    # metadata namespace, without creating a login session or selecting paths.
    get("/bin/chrome.zip", MarvinDownloadController, :chrome)
    get("/bin/firefox.xpi", MarvinDownloadController, :firefox)
    get("/bin/marvin/manifest.json", MarvinDownloadController, :manifest)
    get("/bin/marvin/sha256/:artifact", MarvinDownloadController, :checksum)
    get("/bin/:target", OverallsController, :artifact)
    get("/docs", DocsController, :index)
    get("/docs.md", DocsController, :markdown)
    get("/docs/:page", DocsController, :show)
    get("/llms.txt", DocsController, :llms)
  end

  scope "/api/agents/v1", MarshallWeb do
    pipe_through(:agent_cli_api)
    get("/session", AgentCLIController, :session)
    get("/threads", AgentCLIController, :threads)
    post("/prompt", AgentCLIController, :prompt)
    get("/turn/:turn_id", AgentCLIController, :turn)
  end

  scope "/", MarshallWeb do
    pipe_through([:browser, :ssh_approval_login])

    ash_authentication_live_session :ssh_approval_routes do
      live("/ssh/approve/:token", SSHApprovalLive, :show)
    end
  end

  scope "/", MarshallWeb do
    pipe_through(:browser)

    get("/git/github/:owner/:repo/raw", GitRawController, :show)
    get("/audi/authorize/:ticket", AudiLoginController, :authorize)
    get("/editor/authorize/:ticket", EditorController, :authorize)
    get("/machines/:id/code", EditorController, :launch)
    get("/usage/export", InferenceExportController, :show)
    post("/attachments/:id/download", AttachmentController, :download)
    post("/attachments/threads/:thread_id", AttachmentController, :upload)
    get("/admin/usage/export", InferenceExportController, :show)
    post("/auth/github-com/start", GitHubConnectionController, :start)
    get("/auth/github-com/callback", GitHubConnectionController, :callback)

    # @cc [owner:ghuntley,label:security] authenticated-machine-routes
    # Machine and terminal pages MUST remain in the authentication LiveView
    # session and install LiveUserAuth's required-user hook in their modules.
    ash_authentication_live_session :authenticated_routes,
      on_mount_prepend: MarshallWeb.DatabaseWait do
      live "/overview", OverviewLive, :index
      live "/launch", LaunchLive, :index
      live "/admin/users", Admin.UsersLive, :index
      live "/admin/nodes", Admin.LillyNodesLive, :index
      live "/admin/nodes/:id", Admin.LillyNodesLive, :show
      live "/admin/jobs", Admin.JobsLive, :index
      live "/admin/jobs/:id", Admin.JobsLive, :show
      live "/admin/access", Admin.AccessLive, :index
      live "/admin/workloads", Admin.WorkloadsLive, :index
      live "/admin/operations", Admin.OperationsLive, :index
      live "/admin/scim", Admin.ScimLive, :index
      live "/usage", InferenceLive, :index
      live "/message-board", MessageBoardLive, :index
      live "/integrations", IntegrationsLive, :index
      live "/git", GitLive, :index
      live "/git/github/:owner/:repo", GitLive, :show
      live "/teams", TeamsLive, :index
      live "/threads", ThreadsLive, :index
      live "/threads/new", ThreadsLive, :new
      live "/threads/activity", ThreadsLive, :activity
      live "/threads/:id", ThreadsLive, :show
      live "/artifacts", ArtifactsLive, :index
      live "/artifacts/:id", ArtifactsLive, :show
      live "/artifacts/:id/versions", ArtifactsLive, :versions
      live "/artifacts/:id/versions/:number", ArtifactsLive, :version
      live "/artifacts/:id/sharing", ArtifactsLive, :sharing
      live "/admin/artifacts", Admin.ArtifactsLive, :index
      live "/admin/usage", InferenceLive, :admin
      live "/admin/audit", Admin.AuditLive, :index
      live "/admin/redaction", Admin.RedactionLive, :index
      live "/admin/git", Admin.GitLive, :index
      live "/settings", AccountLive, :index
      live "/machines", MachinesLive, :index
      live "/machines/new", MachinesLive, :new
      live "/machines/provisioning/:id", MachineProvisioningLive, :show
      live "/machines/:id", TerminalLive, :show
      live "/machines/:id/resources", MachinesLive, :resources
      live "/machines/:id/access", MachinesLive, :access
      live "/machines/:id/settings", MachinesLive, :settings
      live "/machines/:id/resize", ResizeLive, :show
      live "/machines/:id/terminals", TerminalLive, :show
      live "/machines/:id/threads", AgentThreadsLive, :index
      live "/machines/:id/threads/:thread_id", AgentThreadsLive, :show
      live "/agents/cli/approve/:vm_id/:code", AgentCLIApprovalLive, :show
      get "/machines/:vm_id/terminals/:session_id/socket", TerminalSocket, :show
      get "/android-display", AndroidDisplaySocket, :show
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {MarshallWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {MarshallWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {MarshallWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/", MarshallWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    get("/launch/entry", PageController, :entry)
    post("/launch/pending", RepositoryLaunchController, :stage)
    post("/launch/pending/clear", RepositoryLaunchController, :clear)
    # Declared before auth_routes: verified routes (~p) otherwise resolve these
    # literal paths to an earlier, unverifiable strategy route clause.
    get "/auth/oidc/start", ScimOidcController, :start
    get "/auth/oidc/callback", ScimOidcController, :callback
    auth_routes(AuthController, Marshall.Accounts.User, path: "/auth")

    sign_out_route(AuthController, "/sign-out",
      on_mount_prepend: [MarshallWeb.AuthenticationPrivacy],
      on_mount: [{MarshallWeb.SignOutOverrides, :locale}],
      overrides: [
        MarshallWeb.SignOutOverrides,
        MarshallWeb.AuthOverrides,
        AshAuthentication.Phoenix.Overrides.Default
      ]
    )

    # Remove these if you'd like to use your own authentication views
    sign_in_route(
      live_view: MarshallWeb.ScimSignInLive,
      register_path: "/register",
      gettext_fn: {MarshallWeb.AuthText, :translate},
      on_mount_prepend: [MarshallWeb.AuthenticationPrivacy],
      reset_path: "/reset",
      auth_routes_prefix: "/auth",
      on_mount: [{MarshallWeb.LiveUserAuth, :live_no_user}],
      overrides: [
        MarshallWeb.AuthOverrides,
        AshAuthentication.Phoenix.Overrides.Default
      ]
    )

    # Remove this if you do not want to use the reset password feature
    reset_route(
      auth_routes_prefix: "/auth",
      on_mount_prepend: [MarshallWeb.AuthenticationPrivacy],
      overrides: [
        MarshallWeb.AuthOverrides,
        AshAuthentication.Phoenix.Overrides.Default
      ]
    )

    # Remove this if you do not use the confirmation strategy
    confirm_route(Marshall.Accounts.User, :confirm_new_user,
      on_mount_prepend: [MarshallWeb.AuthenticationPrivacy],
      auth_routes_prefix: "/auth",
      overrides: [MarshallWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Marshall.Accounts.User, :magic_link,
      live_view: MarshallWeb.AutomaticMagicSignInLive,
      on_mount_prepend: [MarshallWeb.AuthenticationPrivacy],
      auth_routes_prefix: "/auth",
      overrides: [MarshallWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", MarshallWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development

  # @cc [owner:ghuntley,label:security] development-tools-not-public-production
  # Development dashboards, mailbox previews and AshAdmin routes MUST only be
  # compiled when dev_routes is enabled; production builds MUST keep it disabled.
  if Application.compile_env(:marshall, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: MarshallWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end

    scope "/" do
      pipe_through(:browser)

      oban_dashboard("/oban")
    end
  end

  if Application.compile_env(:marshall, :dev_routes) do
    import AshAdmin.Router

    scope "/dev/resources" do
      pipe_through(:browser)

      ash_admin("/")
    end
  end
end
