# Hornero Weather

Weather 2.0 (HorneroOS/plugins#27): a dashboard card
(`"placement": "dashboard"`, manifest v2 surface hints
`size: "standard"`, `category: "Weather"`) plus a contextual bar
indicator (`Bar.qml`, compact on narrow hosts, host-owned popover
for detail), complementing — not duplicating — the shell's native
Weather view. The native view remains the full weather surface;
this extension adds configurable data density, a configurable
forecast length, a derived forecast range and a local high-wind
alert at a typed threshold.

All controls are PluginKit `Ui*` controls: keyboard operable,
accessible names, host-owned tooltips, Theme tokens, host context
(`hostOrientation` / `hostCompact` / `hostAvailableWidth` via
`UiStack`) and English source strings with an Argentine Spanish
catalog (`translations/es.json`, via PluginKit `Translations`).
States are explicit: not configured, loading and error are shown
with `UiState`; no fake data is ever rendered.

## What the facade does and does not provide

Read from the PluginKit `Weather` singleton only (verified in the
shell `plugin/qml/Hornero/PluginKit/Weather.qml`): `ready`,
`locationConfigured`, `temp` (a shell-formatted string),
`description`, `humidity`, `windSpeed` (labelled `km/h`, as the
native shell view labels the same service value), `sunrise`,
`sunset` (formatted strings), `lastError` and `forecast` entries
(`date`, `minTempC`/`maxTempC`/`minTempF`/`maxTempF`,
`weatherCode`, `icon` — the entry carries no description and none
is invented).

The facade does **not** expose official weather alerts, multiple
locations, the configured location's name, a unit preference,
feels-like, an hourly forecast, UV or precipitation, and has no
refresh call. So: there is no multi-location support (the single
shell-configured location only), forecast temperatures are shown
in °C as the facade fields name them, and the "High wind" chip is
a local threshold on the reported wind speed, labelled as not an
official alert. Detailed density lists the unavailable fields in
the card itself.

## Compatibility

- Typed settings (via PluginKit `Settings`): `forecastDays`
  (integer 0–7, default **3** — the 1.x count), `showHumidity` /
  `showWind` / `showSunTimes` (boolean, default **true** — the
  1.x rows), `dataDensity` (enum `compact`/`standard`/`detailed`,
  default **`standard`** — the 1.x density) and `windAlertKmh`
  (integer 1–200, default 50; 1.x had no threshold, the chip is
  additive).
- 1.x declared no settings, so no stored values migrate.
- A `Subscription { domain: "weather" }` lease holds the shared
  cached provider while a surface is loaded; the plugin starts
  no fetch, process or network access of its own.

First-party HorneroOS extension. Install with:

```sh
horneroctl plugin install https://github.com/HorneroOS/plugins.git --dry-run
```

(then re-run with `--yes`, and enable it from the Control Center Extensions pane or `horneroctl plugin enable hornero-weather --yes`.)

QML plugins run with your user privileges — Hornero Shell does not sandbox them. Review the source in this repository before enabling.
