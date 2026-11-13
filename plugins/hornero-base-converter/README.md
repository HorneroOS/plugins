# Hornero Base Converter

Utility Tools 2.0 (HorneroOS/plugins#30, manifest v2): launcher-first
shape with one package and three declared surfaces over one shared
pure-JS `LOGIC` block (verbatim in all three entrypoints, because
plugins cannot share code across files; checked by
`tests/test_utility_logic.py` against independent Python oracles).

- **Bar quick action** (`"placement": "bar"`, primary): `01` in the bar, a decimal integer (binary/octal/hex out) or a `0x`-prefixed hex value (decimal out); bare hex stays a dashboard-panel field so digits are never guessed.
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

Validation is the 1.x rule on both paths: decimal digits (optional minus) or hex digits only, absolute value at most `Number.MAX_SAFE_INTEGER`; invalid digits or out-of-range values show an error instead of a rounded guess.

## Compatibility

- Typed settings, all with the 1.x behaviour as default:
  `uppercaseHex` (boolean, default **true**). The settings descriptions in the manifest
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
