# Hornero Dual Clock

Dual Clock 2.0 (HorneroOS/plugins#28): local time next to a
second zone in the bar (`"placement": "bar"`, single surface),
for coordinating with people in other time zones. The indicator
is a PluginKit `UiButton` — keyboard operable, accessible name
announcing both times, Theme tokens (1.x used the raw
`palette.windowText`) — opening a host-owned `UiPopover` with
locale-formatted dates for both zones, the offset actually
applied to each, a DST mark when daylight time is in effect in
the second zone, and the signed offset difference from local
time. Time comes from the shared PluginKit `Time` facade behind
a `Subscription { domain: "time" }` lease; the 1.x per-instance
1 s timer is gone. English source strings ship with an Argentine
Spanish catalog (`translations/es.json`, via PluginKit
`Translations`).

## Timezones: what is real and what is not

PluginKit `Time` exposes only the local system clock; neither it
nor any other facade offers an IANA timezone database or zoned
conversion, and the Qt JS engine ignores `toLocaleString`'s
`timeZone` option. The local line and its offset are the real
system zone (JS `getTimezoneOffset()` on the facade date, DST
included). A non-UTC second zone uses the same pure-JS rule
table as Hornero World Clock (fixed offsets, EU, US and
southern-hemisphere DST rules for twelve zones), copied verbatim
into this package's `TZ-LOGIC` block because plugin packages
cannot share code; `tests/test_time_logic.py` in this repository
checks both copies against the system timezone database and
against each other. Zones outside the table cannot be selected,
and a future DST law change needs a code update.

## Compatibility

- With default settings the label is exactly the 1.x one: local
  `HH:mm` over `HH:mm UTC`, two lines, centred.
- Typed settings, defaults equal to 1.x: `secondZone` (enum,
  default **utc**), `showSeconds` (boolean, default **false**),
  `twentyFourHour` (boolean, default **true**). An unknown
  stored zone falls back to UTC. When the second zone is not
  UTC, the second line's suffix is its applied offset
  (for example `UTC+02:00`) and the popover names the city.
- 1.x declared no settings, so no stored values migrate.
  Settings changed in Control Center apply from the next
  plugin reload, as in the other 2.0 families.
- No processes, no network.

First-party HorneroOS extension. Install with:

```sh
horneroctl plugin install https://github.com/HorneroOS/plugins.git --dry-run
```

(then re-run with `--yes`, and enable it from the Control Center Extensions pane or `horneroctl plugin enable hornero-dual-clock --yes`.)

QML plugins run with your user privileges — Hornero Shell does not sandbox them. Review the source in this repository before enabling.
