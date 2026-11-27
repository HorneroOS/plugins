# Hornero Uptime

Uptime 3.0 (manifest v3, PluginKit 3 on Hornero Signal, HorneroOS/plugins#31, #112): one package, two
surfaces showing live session length from the shared PluginKit `system` provider (`System.uptimeSeconds`).

- **Bar** (`"placement": "bar"`, primary): the compact label
  (`Up 2h 3m`). Activating it opens a host-owned `UiPopover`
  with live uptime and the derived boot time.
- **Dashboard** (`surfaces.dashboard`, `size: "compact"`,
  `category: "System"`): the same detail as a card.

## Native PluginKit provider (zero subprocesses)

Both surfaces hold a shared `Subscription { domain: "system" }` lease
and read `System.uptimeSeconds` (introduced in Hornero Shell 1.3.10),
which the shell samples natively from `/proc/uptime` via `FileView`.
No `Process`, `Timer`, or external command is used.

## States and derived values

- **Waiting / Unavailable**: before a positive uptime value arrives
  from `System.uptimeSeconds`. The bar shows "Uptime unavailable"
  (unless `showWhenUnavailable` is off, then it takes no bar space)
  and the popover/card show a loading state. A fabricated zero is
  never displayed.
- **Booted at** is derived arithmetic (`now - uptimeSeconds`), not a
  kernel boot timestamp.

## Compatibility

- Typed settings: `showLabel` (boolean, default `true`, the "Up"
  prefix) and `showWhenUnavailable` (boolean, default `true`).
- Formatting is unchanged: `d/h/m` with days only when non-zero and
  minutes always shown.
- Requires Hornero Shell `>= 1.3.10` (`System.uptimeSeconds` on the
  shared `system` provider).

Both surfaces use PluginKit `Ui*` primitives, host context,
host-owned tooltip/popover, accessible names, Theme tokens and
an Argentine Spanish catalog (`translations/es.json`). No
subprocesses, no timers, no network. Original HorneroOS code, MIT
licensed. Plugin QML runs with your user privileges inside Quickshell;
it is not sandboxed.
