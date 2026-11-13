# Hornero Calendar

Calendar 2.0 (HorneroOS/plugins#28): a desktop widget
(`"placement": "desktop"`, single surface, exactly as in 1.x)
keeping the 1.x header — large time, full date and the
shell-formatted time line — and adding the current month as a
grid with today marked. It reads the shared PluginKit `Time`
facade behind a `Subscription { domain: "time" }` lease and
lays out with PluginKit `Ui*` primitives and Theme tokens inside
a `UiCard`. Month and weekday names come from
`Translations.formatDateTime` in the resolved locale, and day
numbers from `formatNumber`. The grid is computed from the local
calendar fields of `Time.date` with UTC day math (the
`DATE-LOGIC` block in `Main.qml`), so a DST transition in the
system zone can never shift a cell to the wrong day;
`tests/test_time_logic.py` checks that block against Python's
`calendar` module.

**No events — honestly.** PluginKit has no calendar/events
facade (checked against the shell `plugin/qml/Hornero/PluginKit`
sources: `Time`, `Weather`, `Media`, `System`, `Network`,
`Power`, `Audio`, `Desktop`, `Notifications`, `Providers` —
nothing exposes appointments), so 2.0 deliberately shows no
"upcoming events": inventing a calendar backend or reading a
user's calendar files behind the manifest's empty capability
declaration would be worse than having none. The widget says so
in its caption. An events row belongs to a future shell data
source, not to this package.

## Compatibility

- Every 1.x element is still shown by default: the large clock
  (`twentyFourHour`, boolean, default **true** = the old
  `HH:mm`), the full date, and the shell time line
  (`showShellTime`, default **true**). The month grid is
  additive (`showMonthGrid`, default **true**).
- `weekStart` (enum `monday`/`sunday`, default **monday**) picks
  the grid's first column. PluginKit `Translations` resolves
  the locale for formatting but does not expose the locale's
  first weekday, so this is a setting rather than a guess.
- 1.x declared no settings, so no stored values migrate.
  Settings changed in Control Center apply from the next
  plugin reload, as in the other 2.0 families.
- No processes, no network. Original HorneroOS code, MIT
  licensed. Plugin QML runs with your user privileges inside
  Quickshell; it is not sandboxed.
