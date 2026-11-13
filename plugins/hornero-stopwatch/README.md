# Hornero Stopwatch

Stopwatch 2.0 (HorneroOS/plugins#24): a compact bar indicator
(`"placement": "bar"`, single surface — a second surface would
be a second, independent timer) opening a host-owned PluginKit
popover with elapsed time, Start/Pause/Resume and Reset. All
controls are PluginKit `Ui*` controls: keyboard operable,
accessible names, host-owned tooltips, Theme tokens, host
context (`hostOrientation` / `hostCompact` via `UiStack`; the
compact indicator drops tenths) and English source strings
with an Argentine Spanish catalog (`translations/es.json`, via
PluginKit `Translations`).

Timing is wall-clock-anchored: elapsed time is the persisted
`accumulatedMs` plus, while running, now minus
`startedEpochMs`. The 100 ms tick (needed for the tenths
display, as in 1.x) only re-reads that sum, so suspend/sleep
and tick drift no longer lose time the way the 1.x
`elapsedMs += 100` counter did. Both anchors are saved through
PluginKit `Settings`, so a shell/plugin reload restores a
running stopwatch.

## Compatibility

- `showTenths` is a typed boolean setting (default **true** —
  the 1.x `mm:ss.t` display).
- `accumulatedMs` / `startedEpochMs` are saved timer state
  managed by the plugin itself (the same Settings pattern as
  Quick Notes' note); they are not user preferences.
- 1.x declared no settings, so no stored values migrate. No
  laps, as in 1.x. There is no completion event, so the
  stopwatch sends no toast.

Pure QML: no processes, no network. Original HorneroOS code,
MIT licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
