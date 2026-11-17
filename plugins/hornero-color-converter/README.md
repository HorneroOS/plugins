# Hornero Color Converter

Utility Tools 2.0 (HorneroOS/plugins#30, manifest v2): launcher-first
shape with one package and three declared surfaces over one shared
pure-JS `LOGIC` block (verbatim in all three entrypoints, because
plugins cannot share code across files; checked by
`tests/test_utility_logic.py` against independent Python oracles).

- **Bar quick action** (`"placement": "bar"`, primary): `#` in the bar, a `#RGB` or `#RRGGBB` hex color.
  One glyph button opens a host-owned `UiPopover` with a single
  quick-query field; a short result also sits next to the glyph on
  roomy horizontal bars. This is the quick action that is hosted
  today -- it replaces keeping a large dashboard card around for a
  one-line job.
- **Dashboard detailed panel** (`surfaces.dashboard`,
  `size: "compact"`, category **Utilities**): the full 1.x controls
  as an optional compact card, no longer a standard-size card.
- **Launcher** (`surfaces.launcher`, `Launcher.qml`): see the
  honest gap below.

Layout uses PluginKit `Ui*` primitives and Theme tokens, host
context (`hostOrientation`/`hostCompact` via `UiStack`,
`hostAvailableWidth` for the dashboard card width), host-owned
tooltips/popover, accessible names, and English source strings
with an Argentine Spanish catalog (`translations/es.json`, via
PluginKit `Translations`). Computed result strings (values, units,
parser messages) are language-neutral output of the logic block.

## Launcher: what is real and what is not

There is **no launcher provider host in the shell yet**:
HorneroOS/shell#250 (launcher provider architecture) is still
open, plugin-defined providers are shell#222, and shell
`docs/PLUGINS.md` says the `launcher` surface is a "validated
declaration only; this entrypoint is not loaded yet". PluginKit
exposes no launcher/search member at all (checked in the shell
`plugin/qml/Hornero/PluginKit/qmldir`), so this package invents
none and builds no parallel launcher. `Launcher.qml` only carries
the same tested quick-query logic behind plain `query`/`result`
Item properties, ready for the #250 contract to bind when it
exists. Until then, searching for this tool in the shell launcher
will not run it -- the bar quick action above is the hosted
quick path, and claiming otherwise would be false.

PluginKit also has **no text-input, combo-box or spin-box
primitive** (same `qmldir`); those controls stay
`QtQuick.Controls` with `Accessible.name` and `ToolTip.text`, as
in 1.x, while buttons/text/cards/states/stacks use `Ui*`.

## Logic preserved from 1.x

Validation and conversion are the 1.x rules: only `#RGB`/`#RRGGBB` hex parses (invalid hex shows an error and no color), RGB channels are 0-255, and HSL is rounded the 1.x way. The preview swatch is the one place a computed hex string is bound as a fill color; chrome colours stay Theme tokens.

## Compatibility

- Typed settings, all with the 1.x behaviour as default:
  `defaultHex` (string, default **#336699**), `showPreview` (boolean, default **true**). The settings descriptions in the manifest
  state which 1.x behaviour each default reproduces.
- 1.x declared no settings, so no stored values migrate.
  Settings changed in Control Center apply from the next plugin
  reload, as in the other 2.0 families.
- 1.x was a single standard-size dashboard card; 2.0 keeps that
  panel (now `compact`, in Utilities) and adds the bar quick
  action as the primary surface per plugins#30, so existing
  installs gain a bar button and keep their card. Installing
  this manifest v2 package needs a shell/`horneroctl` that
  accepts `schemaVersion` 2, `translations` and `marketplace`.
- No processes, no network. Original HorneroOS code, MIT
  licensed. Plugin QML runs with your user privileges inside
  Quickshell; it is not sandboxed.

## PluginKit 3

This package targets PluginKit 3 on Hornero Signal (`schemaVersion: 3`): colours, type, spacing and glyphs come from the shared Theme tokens and Hornero Glyph names, and the shared data domains it reads are declared in `capabilities.providers`. Shells older than Hornero Signal cannot load it.

## Hornero Chromatic reference (3.1.0)

This package is the reference extension for Hornero Chromatic (RFC 0002,
plugins#70). When the desktop uses the dynamic palette, the dashboard panel
shows its seed colours from `Theme.chromatic` (read-only status, never a
wallpaper path) and clicking a seed loads it into the converter. The sample
ink is derived with `Theme.ensureContrast()` and re-evaluated when
`Theme.revision` changes, so it follows a recolour without depending on shell
internals. Curated themes report `Theme.chromatic === null` and the strip is
hidden.

`manifest.json` also declares one theme template (`palette.json.tmpl` to
`palette.json`). `horneroctl` renders it from the live palette into
`${XDG_CACHE_HOME}/hornero/themes/ext/hornero-color-converter/palette.json`
whenever the palette changes; the extension runs no command and no process.
Needs a shell that ships the PluginKit `Theme.chromatic` API (1.3.0 or newer).
