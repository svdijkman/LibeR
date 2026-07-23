# LibeR GUI design system

This document records the cross-package rules that keep the LibeR applications
recognisably related without erasing their product identities.

## Shared shell

- Browser titles contain the package name only.
- Headers use the transparent LibeR dove, package name, short product
  descriptor, optional version/status pills, and the same labelled theme
  switch pattern.
- Status and message bars sit directly under the header. They use semantic
  `info`, `working`, `success`, `warning`, and `error` states rather than
  package-specific meanings.
- Body copy uses the operating-system UI stack:
  `"Segoe UI", Arial, sans-serif` on Windows, with normal platform fallback.
  Monospace faces remain appropriate for code, identifiers, and worker logs.
- Primary, secondary, quiet, and destructive controls retain the same visual
  hierarchy. Product colour identifies primary action; destructive actions
  remain red.

## Product identities

| Package | Role | Primary identity |
|---|---|---|
| LibeRtAD | Automatic differentiation and benchmarks | Gentle purple |
| LibeRation | Population modelling and simulation | Blue/slate |
| LibeRties | Queue and server administration | Red/slate |
| LibeRary | Literature ingestion and model catalogue | Forest green |
| LibeRality | Optimal design | Warm amber |
| LibeRator | Therapeutic research and teaching | Clinical teal |

The dove artwork is shared and must be derived from the established
high-resolution source in `tools/assets/liber-dove-source.svg`; improvised
substitute paths are not acceptable. Only the package accent colour varies.
The generated SVG containers embed a high-quality 512 px rendering, remain
transparent outside the circle, and stay below 300 KiB. Run
`tools/rebuild-favicons.ps1` to reproduce every package variant.

## Geometry and component rhythm

- Desktop product headers are 58 px high; status/message bars are 32 px.
- Header logos are 42 px square, product names are 19 px, and descriptors are
  10 px.
- Standard controls are 32-34 px high with a 7 px corner radius.
- Workspace panels use a 10 px corner radius, a restrained 2 px/7 px shadow,
  and 12-13 px content spacing.
- Product colour changes identity, not hierarchy: shell geometry, typography,
  focus treatment, destructive actions, and information density remain shared.

## Theme contract

All applications read and write the shared local-storage key `liber.theme`,
whose value is `light` or `dark`. Legacy package keys are read for migration
and kept in sync for backwards compatibility. If neither shared nor legacy
state exists, the first visit follows `prefers-color-scheme`.

The chosen theme is applied in the document head before the main interface
renders to avoid a light/dark flash. Switching theme in any LibeR application
therefore becomes the starting preference for the other applications.

## Accessibility

- Interactive controls expose a visible `:focus-visible` outline.
- Icon-only controls have an accessible name; decorative icons are hidden from
  assistive technology.
- Custom modal dialogs have `role="dialog"`, `aria-modal="true"`, an accessible
  label, Escape-to-close, contained Tab focus, and focus restoration.
- Status colour is always accompanied by text.
- Tables and panels remain keyboard-scrollable when their content overflows.

## Responsive behaviour

Content may stack where the reading order remains clear. Navigation,
configuration, or assessment controls must never disappear without a
replacement. On narrow displays, persistent side rails become labelled
off-canvas drawers with a dismissible backdrop and Escape support. Tab rows may
scroll horizontally rather than compressing labels into unreadable widths.

## Regression expectations

Each package owns source-level GUI consistency tests. Opt-in browser tests use
`LIBER_RUN_BROWSER_TESTS=true` and should cover at least:

1. package-only browser title;
2. light and dark theme rendering;
3. no horizontal document overflow at desktop and narrow widths;
4. keyboard access to drawers and modal close actions; and
5. preservation of reachable scrolling at short viewport heights.
