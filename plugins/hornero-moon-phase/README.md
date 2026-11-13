# Hornero Moon Phase

Moon Phase 2.0 (HorneroOS/plugins#27): a desktop widget
(`"placement": "desktop"`) plus a contextual bar indicator
(`Bar.qml`, manifest v2), keeping the 1.x pure-JS synodic
approximation exactly: age since the known new moon
2000-01-06 18:14 UTC, modulo the 29.530588853-day cycle, with
illumination `(1 - cos(2π·age/cycle)) / 2`, refreshed hourly as
before. New in 2.0 are the illumination progress bar and the
approximate days to the next new and full moons, both derived
from the same age — no new model and no new precision claim.

All controls are PluginKit `Ui*` controls: keyboard operable,
accessible names, host-owned tooltips, Theme tokens, host context
via `UiStack` and English source strings with an Argentine
Spanish catalog (`translations/es.json`, via PluginKit
`Translations`).

## Honesty about the data

No PluginKit facade exposes lunar data: `Weather` (verified in
the shell facade source) has no moon phase, moonrise/moonset or
ephemeris fields, and there is no astronomy facade. Everything
this widget shows is therefore the local synodic approximation,
labelled "approximate" / "~" in every surface; it ignores orbital
perturbation and can be off around phase boundaries. Moonrise
and moonset times are not shown because nothing truthful backs
them.

## Compatibility

- Typed settings (via PluginKit `Settings`): `showIllumination`
  and `showAge` (boolean, default **true** — the 1.x rows),
  `showNextPhases` (boolean, default **true**; additive derived
  rows) and `dataDensity` (enum `compact`/`standard`/`detailed`,
  default **`standard`** — the 1.x density; `detailed` adds the
  approximation note in the widget).
- 1.x declared no settings, so no stored values migrate.
- No processes, no network, no facade subscription: the hourly
  timer only recomputes local arithmetic, as in 1.x.

First-party HorneroOS extension. Install with:

```sh
horneroctl plugin install https://github.com/HorneroOS/plugins.git --dry-run
```

(then re-run with `--yes`, and enable it from the Control Center Extensions pane or `horneroctl plugin enable hornero-moon-phase --yes`.)

QML plugins run with your user privileges — Hornero Shell does not sandbox them. Review the source in this repository before enabling.

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
