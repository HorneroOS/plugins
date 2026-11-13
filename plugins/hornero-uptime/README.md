# Hornero Uptime

Uptime 2.0 (manifest v2, HorneroOS/plugins#31): one package, two
surfaces showing session length from `/proc/uptime`.

- **Bar** (`"placement": "bar"`, primary): the 1.x compact label
  (`Up 2h 3m`). Activating it opens a host-owned `UiPopover`
  (and re-reads) with uptime, idle time, the derived boot time
  and a Refresh control.
- **Dashboard** (`surfaces.dashboard`, `size: "compact"`,
  `category: "System"`): the same detail as a card.

## Facade gap: no PluginKit uptime member

Verified against shell `docs/PLUGINS.md` and
`plugin/qml/Hornero/PluginKit/{Power,System,Time,Providers}.qml`:
`Power` is battery-only, `System` exposes no uptime field, `Time`
is the wall clock and there is no uptime/session provider domain.
So, exactly as in 1.x, each surface reads `/proc/uptime` with the
declared `cat` command (`"processCommands": ["cat"]`) on load,
on its refresh tick and on user activation/Refresh. Each surface
runs in its own host Loader, so bar and dashboard keep separate
reads; there is no shared lease to hold for this data. If the
shell grows an uptime facade, this package should drop the
process entirely.

## States and derived values

- **Loading**: before the first read finishes.
- **Unavailable**: `/proc/uptime` unreadable, non-zero exit or
  unparsable (first field not a finite positive number). The
  bar shows "Uptime unavailable" (unless `showWhenUnavailable`
  is off, then it takes no bar space) and the popover/card show
  an error state. A fabricated zero is never displayed.
- **Idle time** is the second `/proc/uptime` field: idle seconds
  summed across CPUs, so it can exceed wall-clock time; when the
  field is missing or invalid it reads "Unavailable".
- **Booted at** is derived arithmetic (now minus uptime),
  labelled "(derived)" — not a kernel boot timestamp.

## Compatibility

- No settings existed before 2.0, so no stored values migrate.
  New typed settings default to the 1.x behaviour:
  `refreshSeconds` (integer, default `60`), `showLabel`
  (boolean, default `true`, the "Up" prefix) and
  `showWhenUnavailable` (boolean, default `true`).
- 1.x formatting is unchanged: `d/h/m` with days only when
  non-zero and minutes always shown.
- Installing this manifest v2 package needs a shell/`horneroctl`
  that accepts `schemaVersion` 2, `translations` and
  `marketplace`.

Both surfaces use PluginKit `Ui*` primitives, host context,
host-owned tooltip/popover, accessible names, Theme tokens and
an Argentine Spanish catalog (`translations/es.json`). No
network. Original HorneroOS code, MIT licensed. Plugin QML runs
with your user privileges inside Quickshell; it is not sandboxed.
