# Hornero Volume

Audio Extensions 2.0 (manifest v2, HorneroOS/plugins#25): one
package, two surfaces over the shared PluginKit `Audio` facade
(event-pushed by the shell PipeWire service; the surfaces hold a
`Subscription { domain: "audio" }` lease and never poll, and no
PipeWire object is manipulated from this QML).

- **Bar** (`"placement": "bar"`, primary): a compact indicator —
  state glyph plus, on roomy horizontal bars, the percentage.
  Activating it opens a host-owned `UiPopover` with the output
  state, a volume slider and decrease / mute / increase controls.
- **Dashboard** (`surfaces.dashboard`, `size: "standard"`,
  `category: "Audio"`): the same state and controls as a card.

Controls call `Audio.setVolume()` / `decrementVolume()` /
`incrementVolume()` / `toggleMute()` only from user handlers
(click or slider move); nothing changes volume on load.

## Honest limits (PluginKit Audio surface)

The facade exposes `volume`, `muted`, `sourceVolume`,
`sourceMuted`, `hasSink`, `hasSource` and the output controls
above (shell `docs/PLUGINS.md`). It exposes **no** sink/source
selection and no device or profile controls, so this package
does not invent them: device switching stays in the shell audio
settings, and the popover/card say so. Adding selection needs a
shell-side PluginKit Audio expansion first.

## States

- **No output device** (`hasSink` false): the bar stays labelled
  as such (unless `showWhenNoSink` is off, then it takes no bar
  space); popover and card show an empty state and controls stay
  disabled instead of pretending a volume exists.
- **Muted**: labelled muted in the bar, popover and card; the
  slider still reflects the stored level and unmuting is a user
  click.

## Compatibility

- No settings existed before 2.0, so no stored values migrate.
  New typed settings default to the 1.x behaviour:
  `showPercentage` (boolean, default `true`) and
  `showWhenNoSink` (boolean, default `true`).
- 1.x kept mute/step buttons inline in the bar; 2.0 moves them
  into the popover and dashboard card to keep the bar compact
  (issue acceptance).
- Installing this manifest v2 package needs a shell/`horneroctl`
  that accepts `schemaVersion` 2, `translations` and
  `marketplace`.

Both surfaces use PluginKit `Ui*` primitives, host context,
host-owned tooltips, accessible names, Theme tokens and an
Argentine Spanish catalog (`translations/es.json`). No processes
and no network. Original HorneroOS code, MIT licensed. Plugin QML
runs with your user privileges inside Quickshell; it is not
sandboxed.
