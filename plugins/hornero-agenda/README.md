# Hornero Agenda

Agenda 2.0 (HorneroOS/plugins#28): a desktop widget
(`"placement": "desktop"`, single surface, exactly as in 1.x)
of date facts read from the shared PluginKit `Time` facade
behind a `Subscription { domain: "time" }` lease. The 1.x
figures are all still there, now as labelled `UiMetric`s in a
`UiCard`: weekday, day, month, ISO week, day of year and days
remaining in the year. 2.0 adds only facts that come from the
same real source — the system clock's calendar fields:
quarter, the ISO **week-year** (so the days around 1 January
name the year their ISO week belongs to, which 1.x's bare week
number could not say), days remaining in the month, and the
elapsed fraction of the year as a `UiProgress` bar. Dates and
numbers are formatted with `Translations.formatDateTime` /
`formatNumber` in the resolved locale (English source strings,
Argentine Spanish catalog in `translations/es.json`).

All arithmetic is UTC day math on the local (year, month, day)
fields — the `DATE-LOGIC` block in `Main.qml` — so a DST
transition in the system zone can never drift a count by an
hour into the wrong day. The ISO week keeps the 1.x Thursday
rule. `tests/test_time_logic.py` checks the block against
Python's `datetime.isocalendar()` and friends across leap years
and new-year edges.

**No events — honestly.** PluginKit has no calendar/events
facade (no source in the shell `plugin/qml/Hornero/PluginKit`
exposes appointments), so this widget never pretends to list
upcoming events: its "remaining" rows are date arithmetic, and
the caption says where the data ends. Real upcoming-event rows
need a real shell data source first.

## Compatibility

- Typed settings are row toggles with the 1.x rows on by
  default: `showIsoWeek` / `showDayOfYear` (boolean, default
  **true**). `showYearProgress` (default **true**) controls the
  new additive bar. Turning every toggle on reproduces the 1.x
  content plus the new rows; nothing 1.x showed can disappear
  unless the user turns it off.
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
