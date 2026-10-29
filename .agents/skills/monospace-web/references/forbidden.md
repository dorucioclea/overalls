# Forbidden patterns

`mix monospace.check` (marshall/scripts/check_monospace.exs) fails the build on
the first four; the browser probe catches the rest.

- Utility-framework classes in templates (`rounded-*`, `px-*`, `text-sm`,
  `bg-*`, `dark:*`, `md:*`, `flex`, `truncate`, `font-semibold`, …). The only
  allowed legacy class is `strong.font-mono` in the agent CLI approval page,
  pinned by a NixOS browser test.
- Colour literals outside `assets/css/tokens.css` (hex, `rgb()`, `hsl()`,
  `color-mix()`), except the dialog backdrop and print overrides.
- External resources: `@import url(https://…)`, `url(https://…)`, hosted
  fonts, CDN scripts or stylesheets in templates, layouts or CSS.
- JavaScript toggling utility classes (`classList.add("opacity-0")`); toggle
  semantic classes (`hidden`, `unread`) instead.
- Colour as the only carrier of meaning; add a text label, weight or inverse
  video.
- Styling inside `.xterm` or Mermaid SVG; chrome only.
- Changing an `id`, `data-*`, `aria-*` attribute or hook name that a test or
  probe consumes (`#main-content`, `#workspace-sidebar`, `#navigation-open`,
  `#machine-connect`, `#terminal-*`, `data-terminal-*`, `[data-appearance]`,
  `a#nav-source-code`,
  `.clone-source`, `.auth-panel`, `button.console-button.primary`).
- Inline `<script>` tags, SVG icon sets, mascots, rounded corners, drop
  shadows, gradients, transitions beyond the drawer slide and `button:active`.
