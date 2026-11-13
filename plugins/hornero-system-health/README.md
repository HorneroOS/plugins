# Hornero System Health

System Health 2.0 (manifest v2): a dashboard health summary
over the shared PluginKit facades — `System` (`cpuPerc`,
`memPerc`, `storagePerc`), `Power` (`hasBattery`, `percentage`,
`charging`, `stateText`) and `Network` (`downloadSpeed`,
`uploadSpeed`) — holding `system`, `power` and `network`
`Subscription` leases. Every 1.x row is still there; 2.0 gives
each row a health state (`OK` / `Needs attention` /
`Unavailable`, plus `No battery` where no battery is fitted),
an overall verdict, and a one-line troubleshooting hint under
any row that needs attention.

States are derived only from the reported value and the user's
typed thresholds (`warnPercent`, `batteryWarnPercent`), and the
card says so. PluginKit exposes no disk SMART, battery-health,
temperature-history or per-process data to extensions, so this
card never presents a drive or battery as "healthy" in that
sense and never invents such data; the bottom of the card
states this limit in the UI as well.

## Compatibility

- The plugin declared no settings before 2.0, so no stored
  values migrate. New typed settings default to the 1.x visible
  rows: `showNetwork` (boolean, default `true`), plus additive
  `warnPercent` (integer 50–100, default `90`),
  `batteryWarnPercent` (integer 1–50, default `20`) and
  `showHints` (boolean, default `true`).
- The 1.x battery wording is kept (percentage, `charging`, the
  shell-reported `stateText`, `No battery` on desktops); the
  state text remains shell-reported and untranslated, as in 1.x.
- Installing this manifest v2 package needs a shell /
  `horneroctl` that accepts `schemaVersion` 2, the dashboard
  surface hints, the `translations` declaration and the
  `marketplace` block.

## The 8 Hornero quality questions

1. **Unique value.** A single health verdict over CPU, memory, storage, battery and network, with per-row states and troubleshooting hints — the answer to "is something wrong?" rather than five more percentages.
2. **Native overlap.** It reads the same facades as the native Performance view and the sibling System Monitor / Disk Usage / Network Monitor / Battery cards. Its distinct value is the combined state judgement and hints; users who want history use System Monitor, per-disk detail Disk Usage.
3. **Why an extension.** Health thresholds and hints are opinionated, tunable interpretation layered over native telemetry; that judgement belongs in an opt-in extension, not baked into the native presentation.
4. **Surfaces.** One dashboard surface (`"placement": "dashboard"`, redeclared in `surfaces.dashboard` with `size: "standard"`, `category: "System"`). No bar surface: a health verdict needs the card's room to explain itself.
5. **Actions.** None. No `horneroctl` broker actions, no processes, no buttons: hints only tell the user what to check in the shell's own tools.
6. **Configuration.** Typed settings listed under Compatibility, read via PluginKit `Settings`.
7. **Missing-data behaviour.** Each row shows `Unavailable` when its service reports no usable value and the overall verdict degrades to `Partial data`; `No battery` is a normal state, never a fault. Nothing is estimated or filled in.
8. **Disable behaviour.** Disabling the extension destroys the card and releases its `system`, `power` and `network` Subscription leases. No state is kept.

No processes and no network access of its own. Original
HorneroOS code, MIT licensed. Plugin QML runs with your user
privileges inside Quickshell; it is not sandboxed.
