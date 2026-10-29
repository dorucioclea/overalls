defmodule MarshallWeb.Layouts do
  @moduledoc """
  Application shell for the Monospace Web presentation (ADR-0161): a sidebar
  of navigation trees beside the main column, a drawer on narrow screens, and
  a header table on public pages.
  """
  use MarshallWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates("layouts/*")

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")

  attr(:current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"
  )

  attr(:compute, :boolean, default: false)
  attr(:active, :string, default: "machines")
  attr(:admin_active, :string, default: "nodes")

  attr(:time_zone, :string,
    default: nil,
    doc: "the viewer's resolved IANA zone; nil hides the account clock"
  )

  attr(:now, :any, default: nil, doc: "the current UTC DateTime for the account clock")

  slot(:inner_block, required: true)

  def app(assigns) do
    ~H"""
    <div class="workspace-shell">
      <.console_header
        current_scope={@current_scope}
        active={@active}
        admin_active={@admin_active}
        time_zone={@time_zone}
        now={@now}
      />
      <div class="workspace-body">
        <main
          id="main-content"
          class={[
            "console-main",
            !@compute && "console-narrow",
            @active == "admin" && "console-admin"
          ]}
        >
          <nav
            :if={@active != "overview"}
            class="workspace-breadcrumb"
            aria-label={dgettext("shared", "Breadcrumb")}
          >
            <.link navigate={~p"/overview"}>{dgettext("shared", "Home")}</.link><span aria-hidden="true">/</span>
            <span>{section_title(@active, @admin_active)}</span>
          </nav>
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>

    <.admin_elevation_modal :if={@current_scope} />
    <.flash_group flash={@flash} />
    """
  end

  defp admin_elevation_modal(assigns) do
    ~H"""
    <div id="admin-elevation-hook" phx-hook="AdminElevation" phx-update="ignore">
      <dialog
        id="admin-elevation-modal"
        aria-labelledby="admin-elevation-title"
        aria-describedby="admin-elevation-description"
      >
        <div class="row between">
          <h2 id="admin-elevation-title">{dgettext("shared", "Confirm administrative change")}</h2>
          <button
            type="button"
            data-admin-elevation-cancel
            aria-label={dgettext("shared", "Cancel verification")}
            class="console-button ghost"
          >×</button>
        </div>
        <p id="admin-elevation-description" class="muted">
          {dgettext(
            "shared",
            "This change needs a fresh passkey verification. Your verification lasts 15 minutes."
          )}
        </p>
        <p id="admin-elevation-status" aria-live="polite" role="status"></p>
        <div class="dialog-actions">
          <button id="admin-elevation-verify" type="button" class="console-button primary">
            {dgettext("shared", "Verify with passkey")}
          </button>
          <button
            id="admin-elevation-cancel"
            type="button"
            data-admin-elevation-cancel
            class="console-button ghost"
          >{dgettext("shared", "Cancel")}</button>
        </div>
      </dialog>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={dgettext("shared", "We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {dgettext("shared", "Attempting to reconnect")} <.glyph name="refresh" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={dgettext("shared", "Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {dgettext("shared", "Attempting to reconnect")} <.glyph name="refresh" />
      </.flash>
    </div>
    """
  end

  attr(:current_scope, :map, default: nil)
  attr(:active, :string, default: nil)
  attr(:admin_active, :string, default: "nodes")
  attr(:time_zone, :string, default: nil)
  attr(:now, :any, default: nil)

  # @cc [owner:ghuntley,label:product] signed-in-account-navigation
  # The "Your account" tree MUST open with one Account entry (#nav-account,
  # /settings) that covers profile, sign-in passkeys, SSH keys and Git preferences,
  # followed by AI usage (#nav-usage, /usage); the account menu MUST show the viewer's local
  # clock under the email, linking to /settings#profile, whenever a zone and
  # instant are given. There MUST be no separate Profile, Security or SSH keys
  # navigation entries.

  # @cc [owner:ghuntley,label:product] signed-in-control-room-navigation
  # Every signed-in account MUST see the Control room mode switch regardless of
  # administrator membership. Public navigation MUST still require sign-in.

  # @cc [owner:ghuntley,label:product] signed-in-reference-navigation
  # Field notes and Source code MUST form their own "Reference" tree
  # (#nav-reference) after "Your account", in that order, not inside it.
  # In the Control room only the administration tree is shown: neither the
  # "Your account" nor the "Reference" tree renders there.

  # @cc [owner:ghuntley,label:product] signed-in-source-code-navigation
  # The shared signed-in menu MUST place Source code immediately below Field notes,
  # linking to https://github.com/ghuntley/overalls with ordinary navigation.

  # @cc [owner:ghuntley,label:product] browser-extension-guide-navigation
  # The public header and shared signed-in menu MUST expose a browser extension
  # link to /docs/browser-extension with ordinary navigation. The setup links
  # remain presentation hints and cannot grant access or change authorization.
  @spec console_header(map()) :: Phoenix.LiveView.Rendered.t()
  def console_header(assigns) do
    assigns = assign(assigns, :groups, navigation(assigns.active))

    ~H"""
    <a href="#main-content" class="skip-link">{dgettext("shared", "Skip to content")}</a>
    <header :if={!@current_scope} class="public-header">
      <table class="header">
        <tr>
          <td colspan="2" rowspan="2" class="width-auto">
            <p class="title"><.link href={~p"/"} class="console-brand">Overalls</.link></p>
          </td>
          <th>{dgettext("shared", "Docs")}</th>
          <td class="width-min">
            <.link href={~p"/docs"}>{dgettext("shared", "Field notes")}</.link>
          </td>
        </tr>
        <tr>
          <th>{dgettext("shared", "Source")}</th>
          <td class="width-min">
            <a href="https://github.com/ghuntley/overalls">GitHub <span aria-hidden="true">↗</span></a>
          </td>
        </tr>
        <tr data-overalls-extension-setup="true">
          <th>{dgettext("shared", "Browser")}</th>
          <td class="width-min">
            <.link id="public-marvin-extension" href={~p"/docs/browser-extension"}>
              {dgettext("shared", "Browser extension")} <span aria-hidden="true">↗</span>
            </.link>
          </td>
        </tr>
        <tr>
          <th class="width-min">{dgettext("shared", "Account")}</th>
          <td class="width-auto">
            <.link href={~p"/sign-in"} class="console-button primary">{dgettext("shared", "Sign in")}</.link>
          </td>
          <th class="width-min">{dgettext("shared", "Appearance")}</th>
          <td class="width-min"><.theme_toggle /></td>
        </tr>
      </table>
    </header>
    <div :if={@current_scope} id="workspace-navigation" phx-hook="WorkspaceNavigation">
      <header class="mobile-header">
        <.link navigate={~p"/overview"} class="console-brand">Overalls<span class="brand-dot">.</span></.link>
        <button
          id="navigation-open"
          class="console-button ghost"
          type="button"
          aria-controls="workspace-sidebar"
          aria-expanded="false"
        ><.glyph name="menu" /> {dgettext("shared", "Menu")}</button>
      </header>
      <button
        id="navigation-backdrop"
        class="navigation-backdrop"
        aria-label={dgettext("shared", "Close navigation")}
        hidden
      ></button>
      <aside
        id="workspace-sidebar"
        class="workspace-sidebar"
        aria-label={dgettext("shared", "Workspace navigation")}
      >
        <div class="sidebar-brand">
          <.link navigate={~p"/overview"} class="console-brand">Overalls<span class="brand-dot">.</span></.link>
          <button
            id="navigation-close"
            type="button"
            class="mobile-only console-button ghost"
            aria-label={dgettext("shared", "Close navigation")}
          >×</button>
        </div>
        <p class="brand-caption">{dgettext("shared", "Made to get dirty")}</p>
        <nav class="workspace-switch" aria-label={dgettext("shared", "Workspace mode")}>
          <.link navigate={~p"/overview"} aria-current={@active != "admin" && "true"}>{dgettext(
            "shared",
            "Workspace"
          )}</.link>
          <.link navigate={~p"/admin/nodes"} aria-current={@active == "admin" && "true"}>{dgettext(
            "shared",
            "Control room"
          )}</.link>
        </nav>
        <nav
          class="sidebar-links"
          aria-label={
            if @active == "admin",
              do: dgettext("shared", "Administration"),
              else: dgettext("shared", "Main")
          }
        >
          <section :for={{title, links} <- @groups}>
            <ul class="tree">
              <li>
                <h2>{title}</h2>
                <ul>
                  <li :for={{key, label, path} <- links}>
                    <.link
                      id={key == "threads" && "nav-threads"}
                      navigate={path}
                      aria-current={
                        if(@active == "admin", do: @admin_active == key, else: @active == key) &&
                          "page"
                      }
                    >{label}</.link>
                  </li>
                </ul>
              </li>
            </ul>
          </section>
          <section :if={@active != "admin"} id="nav-account-section">
            <ul class="tree">
              <li>
                <h2>{dgettext("shared", "Your account")}</h2>
                <ul>
                  <li>
                    <.link
                      id="nav-account"
                      navigate={~p"/settings"}
                      aria-current={@active == "account" && "page"}
                    >{dgettext("shared", "Account")}</.link>
                  </li>
                  <li>
                    <.link
                      id="nav-usage"
                      navigate={~p"/usage"}
                      aria-current={@active == "usage" && "page"}
                    >
                      {dgettext("shared", "AI usage")}
                    </.link>
                  </li>
                  <li data-overalls-extension-setup="true">
                    <.link id="nav-marvin-extension" href={~p"/docs/browser-extension"}>
                      {dgettext("shared", "Browser extension")}
                    </.link>
                  </li>
                </ul>
              </li>
            </ul>
          </section>
          <section :if={@active != "admin"} id="nav-reference">
            <ul class="tree">
              <li>
                <h2>{dgettext("shared", "Reference")}</h2>
                <ul>
                  <li>
                    <.link href={~p"/docs"}>{dgettext("shared", "Field notes")}
                    <span class="nav-hint">{dgettext("shared", "Docs ↗")}</span></.link>
                  </li>
                  <li>
                    <.link id="nav-source-code" href="https://github.com/ghuntley/overalls">
                      {dgettext("shared", "Source code")}
                      <span class="nav-hint">{dgettext("shared", "GitHub ↗")}</span>
                    </.link>
                  </li>
                </ul>
              </li>
            </ul>
          </section>
        </nav>
        <div class="sidebar-bottom">
          <div class="sidebar-appearance">
            <span>{dgettext("shared", "Make yourself comfy")}</span><.theme_toggle />
          </div>
          <details class="account-menu">
            <summary>{@current_scope.user.email}</summary>
            <p>{@current_scope.user.email}</p>
            <p :if={@time_zone && @now} class="account-clock">
              <.local_clock id="account-local-clock" zone={@time_zone} now={@now} />
              <.link navigate={~p"/settings#profile"} class="nav-hint">{dgettext(
                "shared",
                "Time zone"
              )}</.link>
            </p>
            <.link href={~p"/sign-out"}>{dgettext("shared", "Sign out")}</.link>
          </details>
        </div>
      </aside>
    </div>
    """
  end

  @spec navigation(String.t() | nil) :: [{String.t(), [{String.t(), String.t(), String.t()}]}]
  defp navigation("admin") do
    [
      {dgettext("shared", "Accounting"),
       [{"usage", dgettext("shared", "Fleet AI usage"), "/admin/usage"}]},
      {dgettext("shared", "Operations"),
       [
         {"nodes", dgettext("shared", "Node maintenance"), "/admin/nodes"},
         {"workloads", dgettext("shared", "Workloads"), "/admin/workloads"},
         {"jobs", dgettext("shared", "Jobs"), "/admin/jobs"},
         {"operations", dgettext("shared", "Platform status"), "/admin/operations"}
       ]},
      {dgettext("shared", "Administration"),
       [
         {"users", dgettext("shared", "Users"), "/admin/users"},
         {"access", dgettext("shared", "Access authority"), "/admin/access"},
         {"git", dgettext("shared", "Git mirrors"), "/admin/git"},
         {"audit", dgettext("shared", "Audit"), "/admin/audit"},
         {"redaction", dgettext("shared", "Thread redaction"), "/admin/redaction"},
         {"artifacts", dgettext("shared", "Artifact moderation"), "/admin/artifacts"},
         {"scim", dgettext("shared", "SCIM provisioning"), "/admin/scim"}
       ]}
    ]
  end

  defp navigation(_) do
    [
      {dgettext("shared", "Your workspace"),
       [
         {"overview", dgettext("shared", "Overview"), "/overview"},
         {"threads", dgettext("shared", "Threads"), "/threads"},
         {"artifacts", dgettext("shared", "Artifacts"), "/artifacts"},
         {"machines", dgettext("shared", "Machines"), "/machines"},
         {"integrations", dgettext("shared", "Integrations"), "/integrations"},
         {"git", dgettext("shared", "Git repositories"), "/git"},
         {"teams", dgettext("shared", "Teams"), "/teams"}
       ]}
    ]
  end

  @spec section_title(String.t(), String.t()) :: String.t()
  defp section_title("admin", "usage"), do: dgettext("shared", "Control room · AI usage")

  defp section_title("admin", key),
    do: dgettext("shared", "Control room · %{section}", section: section_name(key))

  defp section_title("usage", _), do: dgettext("shared", "AI usage")
  defp section_title(key, _), do: section_name(key)

  @spec section_name(String.t()) :: String.t()
  defp section_name(key) do
    %{
      "account" => dgettext("shared", "Account"),
      "overview" => dgettext("shared", "Overview"),
      "threads" => dgettext("shared", "Threads"),
      "artifacts" => dgettext("shared", "Artifacts"),
      "machines" => dgettext("shared", "Machines"),
      "integrations" => dgettext("shared", "Integrations"),
      "git" => dgettext("shared", "Git repositories"),
      "teams" => dgettext("shared", "Teams"),
      "nodes" => dgettext("shared", "Node maintenance"),
      "workloads" => dgettext("shared", "Workloads"),
      "jobs" => dgettext("shared", "Jobs"),
      "operations" => dgettext("shared", "Platform status"),
      "users" => dgettext("shared", "Users"),
      "access" => dgettext("shared", "Access authority"),
      "audit" => dgettext("shared", "Audit"),
      "scim" => dgettext("shared", "SCIM provisioning")
    }[key] || dgettext("shared", "Workspace")
  end

  @doc """
  Renders an action as a button, or as a link when `href`, `navigate` or
  `patch` is given. Tones: default, primary (inverse video), danger, ghost.
  """
  attr(:class, :any, default: nil)
  attr(:tone, :string, default: "default", values: ~w(default primary danger ghost))

  attr(:rest, :global,
    include: ~w(disabled type name value href navigate patch method download target rel)
  )

  slot(:inner_block, required: true)

  def action(%{rest: rest} = assigns) do
    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={["console-button", @tone, @class]} {@rest}>{render_slot(@inner_block)}</.link>
      """
    else
      ~H"""
      <button class={["console-button", @tone, @class]} {@rest}>{render_slot(@inner_block)}</button>
      """
    end
  end

  attr(:id, :string, default: nil)
  attr(:state, :string, default: nil)
  attr(:tone, :string, default: nil, values: [nil, "success", "warning", "danger", "muted"])
  slot(:inner_block, required: true)

  def status(assigns) do
    ~H"""
    <span id={@id} class="status-label" data-state={@state} data-tone={@tone}>{render_slot(
      @inner_block
    )}</span>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <label class="appearance-control select">
      <span class="sr-only">{dgettext("shared", "Appearance")}</span>
      <select data-appearance aria-label={dgettext("shared", "Appearance")}>
        <option value="system">{dgettext("shared", "System")}</option>
        <option value="light">{dgettext("shared", "Light")}</option>
        <option value="dark">{dgettext("shared", "Dark")}</option>
      </select>
    </label>
    """
  end
end
