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

## Desktop Widgets 2.0 (#32, package 2.1.0)

Manifest v2 redeclares the `desktop` surface on the same
entrypoint (no new surface is loaded). A `Placement & size`
ghost button opens a host-owned `UiPopover` showing the current
display (`hostScreenName`, falling back to `Screen.name`) and
slot, read with the only PluginKit `Desktop` member,
`Desktop.position(pluginId, screenName)`. The popover cycles
the persisted size class, hides the content, and resets size
and visibility.

- **Move / monitor migration (shell-owned).** PluginKit has no
  slot setter, no edit-mode signal and no monitor list — a
  documented facade gap, not something this package fakes.
  Users move the widget in Control Center › Extensions; the
  shell persists one of nine named slots per display, keeps a
  disconnected display's saved slot, and falls back to
  `bottom-right` on a new/unrecognized display or malformed
  saved state. This widget only reads and labels that slot.
- **Resize.** `sizeClass` (enum `compact`/`standard`/`wide`,
  default **`standard`** = the pre-#32 size) sizes the content
  within the host desktop cap (`hostAvailableWidth`, 300
  logical px today; the shell host also always reports
  `hostCompact: false` on desktop, so `wide` cannot exceed
  the cap). Compact drops secondary rows/captions in favour
  of the core content.
- **Hide, reset, recovery.** `showOnDesktop` (boolean, default
  **true**) hides the content but always leaves a visible
  `Show widget` button, and the generated Control Center
  settings field is a second recovery path — content can
  never be trapped off-screen or hidden without a way back.
  `Reset size and visibility` calls `Settings.resetValue` for
  both keys. Full host-side hide is still a shell gap: the
  host renders its own card and plugin name around the
  entrypoint even when the content is hidden.
- **Persistence.** Size and visibility are typed PluginKit
  `Settings` in shell-owned storage and survive restarts;
  malformed stored values read as the declared defaults
  (shell migration) and are additionally normalized by the
  `DESKTOP-LOGIC` block in `Main.qml`, which
  `tests/test_desktop_logic.py` runs under Node against
  independent Python oracles. That is stub/static evidence
  only — no live-shell rendering, popover placement, slot
  move or multi-monitor behaviour is claimed here.
