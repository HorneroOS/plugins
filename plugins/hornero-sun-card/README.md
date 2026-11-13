# Hornero Sun Card

Sun Card 2.0 (HorneroOS/plugins#27): an astronomy dashboard card
(`"placement": "dashboard"`, manifest v2 surface hints
`size: "compact"`, `category: "Weather"`) plus a contextual bar
indicator (`Bar.qml`), complementing the native Weather view and
Hornero Weather with the sunrise/sunset focus neither keeps as
its primary subject: the 1.x rows plus derived day length, sun
progress and the next sun event.

All controls are PluginKit `Ui*` controls: keyboard operable,
accessible names, host-owned tooltips, Theme tokens, host context
via `UiStack` and English source strings with an Argentine
Spanish catalog (`translations/es.json`, via PluginKit
`Translations`). Not-configured, loading and error states use
`UiState`, exactly as the 1.x text states did.

## What the facade does and does not provide

Read from PluginKit `Weather` only (verified in the shell
`Weather.qml` facade): `ready`, `locationConfigured`, `temp`,
`description`, `humidity`, `sunrise`, `sunset`, `lastError`, plus
PluginKit `Time.hours`/`Time.minutes` for "now". Sunrise and
sunset arrive as formatted strings (`h:mm` or `h:mm A`, or
`--:--` before data), so every astronomy row beyond the two times
is **derived in this plugin** by parsing those strings, and is
labelled "(derived)": an unparseable value reads *Unavailable*,
never a guessed time. Because the facade reports today's times
only, the next sun event after sunset is *Unavailable (the facade
reports today only)* rather than a fabricated tomorrow sunrise.

The facade does **not** expose solar noon, civil/nautical
twilight, golden hour, moonrise/moonset, the configured
location's name or multiple locations; detailed density says so
in the card. Moon data stays with Hornero Moon Phase's labelled
approximation — it is not duplicated here.

## Compatibility

- Typed settings (via PluginKit `Settings`): `showTemperature` /
  `showHumidity` (boolean, default **true** — the 1.x rows, which
  also cover the 1.x description under temperature),
  `showAstronomy` (boolean, default **true**; the derived rows
  are additive) and `dataDensity` (enum
  `compact`/`standard`/`detailed`, default **`standard`**).
- 1.x declared no settings, so no stored values migrate.
- `Subscription` leases for the shared `weather` (cached) and
  `time` (event) providers; no processes and no network of its
  own — weather fetching stays owned by the shell service.

First-party HorneroOS extension. Install with:

```sh
horneroctl plugin install https://github.com/HorneroOS/plugins.git --dry-run
```

(then re-run with `--yes`, and enable it from the Control Center Extensions pane or `horneroctl plugin enable hornero-sun-card --yes`.)

QML plugins run with your user privileges — Hornero Shell does not sandbox them. Review the source in this repository before enabling.
