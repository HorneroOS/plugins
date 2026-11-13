# Hornero World Clock

World Clock 2.0 (HorneroOS/plugins#28): a dashboard card
(`"placement": "dashboard"`, redeclared as a manifest-v2
dashboard surface with `size: "standard"` and category
**Time**) showing local time, UTC and three city rows. The card
reads the shared PluginKit `Time` facade behind a
`Subscription { domain: "time" }` lease (event-pushed, second
precision); the 1.x per-instance 1 s timer is gone. Layout uses
PluginKit `Ui*` primitives and Theme tokens, host context
(`hostOrientation` / `hostCompact` via `UiStack`,
`hostAvailableWidth` for the card width), and English source
strings with an Argentine Spanish catalog
(`translations/es.json`, via PluginKit `Translations`). Weekday
and month names come from `Translations.formatDateTime` in the
resolved locale.

## Timezones: what is real and what is not

PluginKit `Time` exposes only the local system clock (`date`,
`hours`, `minutes`, `seconds`, `timeStr`, `format(fmt)`, checked
in the shell `plugin/qml/Hornero/PluginKit/Time.qml`). There is
no IANA timezone database and no zoned-conversion call in the
facade, and the Qt JS engine ignores the `timeZone` option of
`toLocaleString`. Other zones are therefore computed in pure JS
from UTC — the 1.x approach — now as an explicit rule table
(the `TZ-LOGIC` block in `Main.qml`):

- Fixed offsets: UTC, Buenos Aires (UTC−3), New Delhi (UTC+5:30),
  Tokyo (UTC+9) — none of these observes DST today.
- EU rule (UTC+1→+2 for Madrid/Berlin, UTC→+1 for London): last
  Sunday of March to last Sunday of October, 01:00 UTC. This is
  exactly the 1.x Madrid rule, preserved.
- US rule (New York, Chicago, Los Angeles): second Sunday of
  March to first Sunday of November, 02:00 local wall time.
- Southern rule (Sydney, Auckland): starts in September/October,
  ends the first Sunday of April, and spans the new year.

Every row is labelled with the offset actually applied, a
**DST** chip when daylight time is in effect, and the zoned
calendar date (with *yesterday*/*tomorrow* when it differs from
the local date). `tests/test_time_logic.py` in this repository
runs the shipped JS block against the system timezone database
(Python `zoneinfo`) around every 2024–2027 transition. The
honest limit stays: only the twelve zones in the table exist,
and if a government changes its DST law this code needs an
update — there is no live tz database behind it. Ambiguous or
nonexistent local wall times during a transition hour are not
special-cased; the card shows the instant's actual offset,
which is unambiguous.

## Compatibility

- Typed settings, all with the 1.x behaviour as default:
  `city1`/`city2`/`city3` (enum, defaults **buenos-aires**,
  **madrid**, **tokyo** — the old fixed rows, in order),
  `showLocal` / `showUtc` / `showSeconds` / `twentyFourHour`
  (boolean, default **true** — 1.x always showed those rows and
  24-hour `HH:mm:ss` times). An unknown stored city falls back
  to the slot default instead of failing.
- 1.x declared no settings, so no stored values migrate.
  Settings changed in Control Center apply from the next
  plugin reload, as in the other 2.0 families.
- No processes, no network, no calendar/event backend. Original
  HorneroOS code, MIT licensed. Plugin QML runs with your user
  privileges inside Quickshell; it is not sandboxed.
