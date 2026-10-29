defmodule MarshallWeb.SecurityHeaders do
  @moduledoc """
  Browser security headers for every response of the browser endpoint.

  The plug runs before health probes, static files, the early `/api` refusals,
  body parsing and the router, so pages, redirects, JSON, downloads and error
  responses all carry the same policy. The production policy is fixed at
  compile time; development tooling (live reload, LiveDashboard, live_debugger)
  needs inline and `localhost` sources, which `config :marshall,
  MarshallWeb.SecurityHeaders, development_tooling: true` enables in `dev.exs`
  only. The test environment keeps the production policy so the browser probe
  exercises what production sends.
  """
  @behaviour Plug
  import Plug.Conn

  @type policy_source :: String.t()

  @development_tooling Application.compile_env(
                         :marshall,
                         [MarshallWeb.SecurityHeaders, :development_tooling],
                         false
                       )

  # Only the xterm.js vendor renderer needs `'unsafe-inline'`: it
  # creates `<style>` elements and sets `style` attributes (`setAttribute("style")`),
  # which a nonce cannot cover. Scripts stay strictly same-origin; the vendored
  # xterm image addon compiles its bundled sixel decoder with WebAssembly, so
  # `'wasm-unsafe-eval'` (ADR-0230) admits WebAssembly compilation only, never
  # JavaScript `eval`, inline or foreign script.
  @production_directives [
    {"default-src", "'self'"},
    {"script-src", "'self' 'wasm-unsafe-eval'"},
    {"style-src", "'self' 'unsafe-inline'"},
    {"img-src", "'self' data:"},
    {"font-src", "'self'"},
    {"connect-src", "'self'"},
    {"object-src", "'none'"},
    {"base-uri", "'self'"},
    {"form-action", "'self' https://ghuntley.com https://github.com"},
    {"frame-ancestors", "'self'"},
    {"frame-src", "'self'"},
    {"worker-src", "'self'"},
    {"manifest-src", "'self'"}
  ]

  @development_additions %{
    "script-src" => " 'unsafe-inline' 'unsafe-eval' http://localhost:*",
    "style-src" => " http://localhost:*",
    "connect-src" => " http://localhost:* ws://localhost:*",
    "frame-src" => " http://localhost:*",
    "img-src" => " http://localhost:*"
  }

  # Passkeys (`publickey-credentials-*`) and the terminal fullscreen control keep
  # their default `self` allowlists. Only features current Chromium recognises
  # are listed; unknown names produce console warnings in the browser probe. The terminal reads the clipboard for paste
  # and the copy buttons write it, so both clipboard features stay allowed for
  # this origin only.
  @permissions_policy Enum.join(
                        [
                          "accelerometer=()",
                          "autoplay=()",
                          "camera=()",
                          "clipboard-read=(self)",
                          "clipboard-write=(self)",
                          "display-capture=()",
                          "geolocation=()",
                          "gyroscope=()",
                          "hid=()",
                          "idle-detection=()",
                          "local-fonts=()",
                          "magnetometer=()",
                          "microphone=()",
                          "midi=()",
                          "payment=()",
                          "picture-in-picture=()",
                          "screen-wake-lock=()",
                          "serial=()",
                          "usb=()",
                          "xr-spatial-tracking=()"
                        ],
                        ", "
                      )

  @impl true
  @spec init(Plug.opts()) :: Plug.opts()
  def init(options), do: options

  # @cc [owner:ghuntley,label:security] endpoint-security-headers-everywhere
  # Every browser-endpoint response, including redirects, static files, health
  # probes, early /api refusals, JSON and error pages, MUST carry this exact
  # header set. No route or pipeline may send a second, conflicting
  # content-security-policy header.

  # @cc [owner:ghuntley,label:security] browser-form-fixed-external-origins
  # Form navigation MUST allow only this origin, the reviewed newsletter origin
  # and GitHub.com's fixed OAuth origin, including the authorization POST redirect.
  # Arbitrary HTTPS origins and wildcard subdomains MUST remain excluded.
  @impl true
  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(conn, _options) do
    Enum.reduce(headers(), conn, fn {name, value}, acc -> put_resp_header(acc, name, value) end)
  end

  @doc "The headers sent on every response, in the order they are set."
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"content-security-policy", policy(@development_tooling, artifact_content_host())},
      {"permissions-policy", @permissions_policy},
      {"cross-origin-opener-policy", "same-origin"},
      {"cross-origin-resource-policy", "same-origin"},
      {"referrer-policy", "strict-origin-when-cross-origin"},
      {"x-content-type-options", "nosniff"},
      {"x-frame-options", "SAMEORIGIN"},
      {"x-permitted-cross-domain-policies", "none"}
    ]
  end

  # @cc [owner:ghuntley,label:security] production-csp-no-inline-script
  # The production policy MUST keep script-src at 'self' plus
  # 'wasm-unsafe-eval' (ADR-0230): no inline, JavaScript eval, data:, blob: or
  # foreign script source. Development additions MUST be
  # selected only by the compile-time development_tooling flag, never by a
  # request, header or runtime option.
  @doc "The Content-Security-Policy value; `true` adds the development-tooling sources."
  @spec policy(boolean()) :: policy_source()
  def policy(development_tooling?) when is_boolean(development_tooling?),
    do: policy(development_tooling?, nil)

  # @cc [owner:ghuntley,label:security] browser-frame-src-artifact-origin
  # The only foreign frame source MUST be the configured artifact content
  # origin (ADR-0254); without one, frames stay same-origin only.
  @doc "The policy with the configured artifact content origin admitted as a frame source."
  @spec policy(boolean(), String.t() | nil) :: policy_source()
  def policy(development_tooling?, content_host) when is_boolean(development_tooling?) do
    @production_directives
    |> Enum.map(fn {directive, sources} ->
      extra =
        if development_tooling?, do: Map.get(@development_additions, directive, ""), else: ""

      frame =
        if directive == "frame-src" and is_binary(content_host),
          do: " https://" <> content_host,
          else: ""

      directive <> " " <> sources <> frame <> extra
    end)
    |> Enum.join("; ")
  end

  @spec artifact_content_host() :: String.t() | nil
  defp artifact_content_host do
    (Application.get_env(:marshall, :artifact_content) || %{}) |> Map.get(:host)
  end

  @doc "Whether the compiled policy includes the development-tooling sources."
  @spec development_tooling?() :: boolean()
  def development_tooling?, do: @development_tooling
end
