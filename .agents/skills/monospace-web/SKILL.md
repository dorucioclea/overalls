---
name: monospace-web
description: "Apply and verify The Monospace Web design language in Marshall's web UI: a character grid, locally served JetBrains Mono with multilingual fallbacks, four colour tokens per theme, semantic HTML with text glyphs, and both themes with no external resources. Use for every Marshall template, stylesheet, presentation JavaScript, component or browser-probe change, and when reviewing one."
---

# The Monospace Web for Marshall

Marshall's browser presentation is [The Monospace Web](https://owickstrom.github.io/the-monospace-web/)
by Oskar Wickström (MIT), adopted by ADR-0161 and carried forward by
[ADR-0207](../../../docs/architecture/decisions/0207-bundled-multilingual-font-fallback.md)
with multilingual font fallback. The stylesheet is hand-written
in `marshall/assets/css/` and bundled by esbuild; there is no Tailwind, daisyUI,
component generator or icon set, and nothing loads from another origin. Using
this skill is not evidence: run the checks in the last section.

## Principles

1. **Everything sits on the grid.** One cell is `1ch` wide and
   `var(--line-height)` (1.2rem) tall. Horizontal sizes are in `ch`, vertical
   sizes in multiples of the line height, borders are `var(--border-thickness)`
   (2px) and padding subtracts the border so boxes stay on the grid. See
   [references/grid.md](references/grid.md).
2. **Semantic HTML first.** Headings, paragraphs, lists, tables, `details`,
   `figure`, forms and `dialog` are styled at the element level. Reach for a
   helper class only when an element cannot express the layout. See
   [references/elements.md](references/elements.md).
3. **Four tokens, two themes.** `--text-color`, `--text-color-alt`,
   `--background-color` and `--background-color-alt`, defined for light and dark
   in `marshall/assets/css/tokens.css`. No other colour literal exists anywhere.
   State is text (`[running]`, `[failed]`), weight or inverse video, never
   colour alone. See [references/tokens.md](references/tokens.md).
4. **Text, not pictures.** Icons are Unicode glyphs through `<.glyph>`; diagrams
   are box drawing in `<pre>` or Mermaid themed from the tokens. Brand marks are
   words.
5. **No external resources.** Fonts (`priv/static/fonts`), scripts and
   stylesheets (`assets/vendor`) are served by Marshall. Never add an `@import
   url(https://…)`, a CDN script or a hosted font. JetBrains Mono remains first
   in `--font-family` and defines the layout grid; local Noto fallback families
   supply missing glyphs. Preserve native joining, combining marks and
   language-specific forms. Grid boxes do not require one Latin cell per
   Unicode code point; never force letter spacing or split graphemes to do so.
6. **Stable contracts.** Element ids, `data-*` and `aria-*` attributes and hook
   names are consumed by ExUnit tests, the browser probe and NixOS browser
   tests. Presentation work never changes them.

## Workflow

1. Read `marshall/assets/css/tokens.css`, `monospace.css` and the layer that owns
   the page (`shell.css`, `components.css`, `workspace.css`). Read the component
   you are touching in `marshall/lib/marshall_web/components/`.
2. Compose the page from elements and the helper classes in
   [references/elements.md](references/elements.md). Prefer `<table>` with
   `.width-min`/`.width-auto` for tabular data, `<.kv>` for key/value pairs,
   `<details>` for secondary content, `.grid` for equal-width form rows,
   `.stack` for vertical rhythm and `.row`/`.cols` for horizontal grouping.
3. Add page-specific CSS only in `workspace.css`, in grid units, and never
   inside renderer-owned DOM (`.xterm`, Mermaid SVG).
4. Check both themes with the appearance selector and the development grid
   overlay: `window.overallsGrid.debug(true)` in the browser console marks
   off-grid elements; `window.overallsGrid.check()` lists them. For localized
   presentation, also read the localization skill and the font inventory in
   `marshall/priv/static/fonts/README.md`. Check bundled glyph coverage and
   observe representative script shaping in LTR and RTL at mobile and desktop
   widths; a font-family declaration alone does not establish actual coverage.
5. Run the gates in the next section, then update ADRs and
   contracts as the repository guidance requires.

Forbidden patterns are listed in [references/forbidden.md](references/forbidden.md).

## Verification

From `marshall/` inside `devenv shell`:

```sh
mix monospace.check              # no utility classes, colour literals, external resources
mix workspace.check              # TypeScript over the presentation JavaScript
mix test test/marshall_web       # page tests pin ids and labels
```

Prefer Bombadil for new browser checks. Record script rendering, both themes,
mobile layout, contrast, grid and same-origin requests separately from static
font coverage. The existing disposable fixture/probe remains available:

```sh
MIX_ENV=test MIX_TEST_PARTITION=monospace_browser mix ash.setup
MIX_ENV=test MIX_TEST_PARTITION=monospace_browser MONOSPACE_BROWSER_PORT=4123 \
  MONOSPACE_BROWSER_CONTEXT=$SCRATCH/context.json \
  mix run --no-start scripts/monospace_browser_fixture.exs &
CHROMIUM_PATH=$(command -v chromium) python3 -I scripts/monospace_browser_probe.py \
  $SCRATCH/context.json $SCRATCH/artifacts
```

Keep the context file and screenshots outside the repository. See [references/verification.md](references/verification.md).

`assets/monospace.css` in this skill is a reference copy of the base
stylesheet; `marshall/assets/css/monospace.css` is the source of truth.
