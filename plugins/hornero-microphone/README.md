# Hornero Microphone

Audio Extensions 2.0 (manifest v2, HorneroOS/plugins#25): one
package, two surfaces over the shared PluginKit `Audio` facade
(source state, event-pushed; the surfaces hold a
`Subscription { domain: "audio" }` lease and never poll, and no
PipeWire object is manipulated from this QML).

- **Bar** (`"placement": "bar"`, primary): a compact indicator —
  state glyph plus, on roomy horizontal bars, the percentage.
  Activating it opens a host-owned `UiPopover` with the input
  state, a read-only level bar and the mute control.
- **Dashboard** (`surfaces.dashboard`, `size: "standard"`,
  `category: "Audio"`): the same state and mute control as a card.

The only mutating call is `Audio.toggleSourceMute()`, from a user
click. Privacy: this widget displays only muted/volume state; it
never records, captures or transmits audio.

## Honest limits (PluginKit Audio surface)

The facade exposes `sourceVolume` and `sourceMuted` read-only
plus `toggleSourceMute()`; there is **no source-volume setter**
and no source/device or profile selection (shell
`docs/PLUGINS.md`). So the level is shown with a read-only
progress bar — not a slider that would fake control — and the
popover/card state that level adjustment and device switching
stay in the shell audio settings. Adding them needs a shell-side
PluginKit Audio expansion first.

## States

- **No input device** (`hasSource` false): the bar stays labelled
  as such (unless `showWhenNoSource` is off); popover and card
  show an empty state with mute disabled.
- **Muted**: labelled muted everywhere; unmuting is a user click,
  which matters because a live microphone is a privacy-relevant
  state the user should enter deliberately.

## Compatibility

- No settings existed before 2.0, so no stored values migrate.
  New typed settings default to the 1.x behaviour:
  `showPercentage` (boolean, default `true`) and
  `showWhenNoSource` (boolean, default `true`).
- 1.x kept the mute button inline in the bar; 2.0 moves it into
  the popover and dashboard card to keep the bar compact (issue
  acceptance).
- Installing this manifest v2 package needs a shell/`horneroctl`
  that accepts `schemaVersion` 2, `translations` and
  `marketplace`.

Both surfaces use PluginKit `Ui*` primitives, host context,
host-owned tooltips, accessible names, Theme tokens and an
Argentine Spanish catalog (`translations/es.json`). No processes
and no network. Original HorneroOS code, MIT licensed. Plugin QML
runs with your user privileges inside Quickshell; it is not
sandboxed.
