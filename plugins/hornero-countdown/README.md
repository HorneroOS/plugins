# Hornero Countdown

Countdown 2.0 (HorneroOS/plugins#24): a compact bar indicator
(`"placement": "bar"`, single surface — a second surface would
be a second, independent timer) opening a host-owned PluginKit
popover with the 5/10/25 minute presets, Start/Pause, Reset and
progress (the 1.x Canvas ring is now a PluginKit `UiProgress`
in the popover). All controls are PluginKit `Ui*` controls:
keyboard operable, accessible names, host-owned tooltips,
Theme tokens, host context (`hostOrientation` / `hostCompact`
via `UiStack`) and English source strings with an Argentine
Spanish catalog (`translations/es.json`, via PluginKit
`Translations`).

Timing is deadline-based: while running, the remaining time is
derived from a wall-clock deadline instead of counting Timer
ticks, so suspend/sleep and tick drift cannot stretch the
countdown. Deadline, chosen length and paused remainder are
saved through PluginKit `Settings`, so a shell/plugin reload
restores a running countdown; one that ends while unloaded
reports itself finished on return. At zero the indicator
flashes `DONE`, as in 1.x (steady under host reduced-motion),
and now also sends a PluginKit `Notifications.toast`. No sound.

## Compatibility

- The starting length is the typed `defaultMinutes` setting
  (integer, 1–180, default **5** — the old initial preset);
  the 5/10/25 presets are unchanged.
- `deadlineEpochMs` / `totalSeconds` / `remainingSeconds` are
  saved timer state managed by the plugin itself (the same
  Settings pattern as Quick Notes' note); they are not user
  preferences.
- 1.x declared no settings, so no stored values migrate.

Pure QML: no processes, no network. Original HorneroOS code,
MIT licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
