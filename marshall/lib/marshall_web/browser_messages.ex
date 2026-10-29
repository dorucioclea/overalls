defmodule MarshallWeb.BrowserMessages do
  @moduledoc "Server-rendered translations for browser hooks; keys are Gettext msgids."
  use Gettext, backend: MarshallWeb.Gettext

  @spec messages() :: %{String.t() => String.t()}
  def messages do
    %{
      "%{name} · Terminals" => dgettext("browser", "%{name} · Terminals", name: "%{name}"),
      "%{name} · %{count} viewing" =>
        dgettext("browser", "%{name} · %{count} viewing", name: "%{name}", count: "%{count}"),
      "%{name} · %{count} viewing · %{activity}" =>
        dgettext("browser", "%{name} · %{count} viewing · %{activity}",
          name: "%{name}",
          count: "%{count}",
          activity: "%{activity}"
        ),
      "%{count}d ago" => dgettext("browser", "%{count}d ago", count: "%{count}"),
      "%{count}h ago" => dgettext("browser", "%{count}h ago", count: "%{count}"),
      "%{count}m ago" => dgettext("browser", "%{count}m ago", count: "%{count}"),
      "%{label} copied." => dgettext("browser", "%{label} copied.", label: "%{label}"),
      "+ New" => dgettext("browser", "+ New"),
      "Applying administrative change…" => dgettext("browser", "Applying administrative change…"),
      "Boot log · read-only" => dgettext("browser", "Boot log · read-only"),
      "Close this terminal session?" => dgettext("browser", "Close this terminal session?"),
      "Command" => dgettext("browser", "Command"),
      "Could not copy. Select the text and copy it manually." =>
        dgettext("browser", "Could not copy. Select the text and copy it manually."),
      "Could not update access. Check the account's machine access." =>
        dgettext("browser", "Could not update access. Check the account's machine access."),
      "Enter full screen" => dgettext("browser", "Enter full screen"),
      "Exit full screen" => dgettext("browser", "Exit full screen"),
      "Input buffer full — that input was not sent" =>
        dgettext("browser", "Input buffer full — that input was not sent"),
      "— output before this view is not in the scrollback window —" =>
        dgettext("browser", "— output before this view is not in the scrollback window —"),
      "Connecting…" => dgettext("browser", "Connecting…"),
      "No terminals" => dgettext("browser", "No terminals"),
      "Diagram unavailable. Source:\n%{source}" =>
        dgettext("browser", "Diagram unavailable. Source:\n%{source}", source: "%{source}"),
      "Match found" => dgettext("browser", "Match found"),
      "No matches" => dgettext("browser", "No matches"),
      "Open this link?\n\n%{url}" =>
        dgettext("browser", "Open this link?\n\n%{url}", url: "%{url}"),
      "Opening…" => dgettext("browser", "Opening…"),
      "Passkey request cancelled. You can try again." =>
        dgettext("browser", "Passkey request cancelled. You can try again."),
      "Passkey verification failed or unavailable. Try again." =>
        dgettext("browser", "Passkey verification failed or unavailable. Try again."),
      "Terminal name (this browser only; empty restores the generated name)" =>
        dgettext(
          "browser",
          "Terminal name (this browser only; empty restores the generated name)"
        ),
      "The result could not be confirmed. Reload the page and check the result before retrying." =>
        dgettext(
          "browser",
          "The result could not be confirmed. Reload the page and check the result before retrying."
        ),
      "This machine asks to write %{bytes} bytes to your clipboard. Type once, session, or mute." =>
        dgettext(
          "browser",
          "This machine asks to write %{bytes} bytes to your clipboard. Type once, session, or mute.",
          bytes: "%{bytes}"
        ),
      "This repository link could not be launched. Open the link again." =>
        dgettext("browser", "This repository link could not be launched. Open the link again."),
      "Terminal input" => dgettext("browser", "Terminal input"),
      "Too much output to announce, navigate to rows manually to read" =>
        dgettext("browser", "Too much output to announce, navigate to rows manually to read"),
      "Type to interact" => dgettext("browser", "Type to interact"),
      "Updating viewing access…" => dgettext("browser", "Updating viewing access…"),
      "Verification could not be completed. Try again." =>
        dgettext("browser", "Verification could not be completed. Try again."),
      "Verify with your passkey to %{action}. This runs once after verification." =>
        dgettext(
          "browser",
          "Verify with your passkey to %{action}. This runs once after verification.",
          action: "%{action}"
        ),
      "View only" => dgettext("browser", "View only"),
      "Viewing access updated." => dgettext("browser", "Viewing access updated."),
      "Waiting for your passkey…" => dgettext("browser", "Waiting for your passkey…"),
      "complete this administrative change" =>
        dgettext("browser", "complete this administrative change"),
      "just now" => dgettext("browser", "just now"),
      "● live" => dgettext("browser", "● live"),
      "● read-only" => dgettext("browser", "● read-only"),
      "⟳ reconnecting…" => dgettext("browser", "⟳ reconnecting…"),
      "⟳ restoring scrollback…" => dgettext("browser", "⟳ restoring scrollback…")
    }
  end
end
