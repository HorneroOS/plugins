# Hornero Pomodoro

Pomodoro 2.0 (HorneroOS/plugins#24): a compact bar indicator
(`"placement": "bar"`, single surface — a second surface would
be a second, independent timer) showing `●/○ mm:ss`, opening a
host-owned PluginKit popover with remaining time, session
progress, Start/Pause and Reset. All controls are PluginKit
`Ui*` controls: keyboard operable, accessible names, host-owned
tooltips, Theme tokens, host context (`hostOrientation` /
`hostCompact` via `UiStack`) and English source strings with an
Argentine Spanish catalog (`translations/es.json`, via PluginKit
`Translations`).

Timing is deadline-based: while running, the remaining time is
derived from a wall-clock deadline instead of counting Timer
ticks, so suspend/sleep and tick drift cannot stretch a
session. The deadline (and the paused remainder) is saved
through PluginKit `Settings`, so a shell/plugin reload restores
a running session; a session that ends while unloaded reports
itself complete on return. At zero it flashes `DONE` three
times and resets, as in 1.x (flashing is steady under host
reduced-motion), and now also sends a PluginKit
`Notifications.toast`.

## Compatibility

- Session length is the typed `focusMinutes` setting (integer,
  1–180, default **25** — the old hardcoded value). Changing it
  in Control Center applies from the next reset/reload.
- `deadlineEpochMs` / `remainingSeconds` are saved timer state
  managed by the plugin itself (the same Settings pattern as
  Quick Notes' note); they are not user preferences.
- 1.x declared no settings, so no stored values migrate. The
  old click-to-toggle / double-click-to-reset mouse-only
  gestures are replaced by the popover buttons. There is still
  no break cycle, no sound, no processes and no network.

First-party HorneroOS extension. Install with:

```sh
horneroctl plugin install https://github.com/HorneroOS/plugins.git --dry-run
```

(then re-run with `--yes`, and enable it from the Control Center Extensions pane or `horneroctl plugin enable hornero-pomodoro --yes`.)

QML plugins run with your user privileges — Hornero Shell does not sandbox them. Review the source in this repository before enabling.
