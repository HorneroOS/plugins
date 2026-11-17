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
  approximation note in the widget). `hemisphere` (enum `north`/`south`,
  default **north**) mirrors the lit side of the disc for the southern sky.
- 1.x declared no settings, so no stored values migrate.
- No processes, no network, no facade subscription: the hourly
  timer only recomputes local arithmetic, as in 1.x.

First-party HorneroOS extension. Install with:

```sh
horneroctl plugin install https://github.com/HorneroOS/plugins.git --dry-run
```

(then re-run with `--yes`, and enable it from the Control Center Extensions pane or `horneroctl plugin enable hornero-moon-phase --yes`.)

QML plugins run with your user privileges — Hornero Shell does not sandbox them. Review the source in this repository before enabling.

## Desktop widget (PluginKit 3)

This is a PluginKit 3 desktop widget: the shell host draws the module (panel
fill, 1 px rule border, eyebrow header with a channel number) and owns the
widget's position, size, persistence and edit mode. The package declares
default geometry hints on its `desktop` surface (`width`, `height`,
`minWidth`, `minHeight`, `anchor`; default 320 x 300) and lays out content in the
host's content box (`hostAvailableWidth`). To move or resize it, run
`qs ipc call plugins editDesktop` (drag the module, use the corner grip);
positions persist per display in the shell config. The 2.x in-widget
`sizeClass` / `showOnDesktop` settings, the `Placement & size` popover and
`Desktop.position` are gone; the shell now owns all of that.

In the `gaming` experience the host suspends desktop widgets entirely. No
live-shell rendering, edit-mode or multi-monitor behaviour is claimed here;
offscreen renders and static checks only.

## PluginKit 3

This package targets PluginKit 3 on Hornero Signal (`schemaVersion: 3`): colours, type, spacing and glyphs come from the shared Theme tokens and Hornero Glyph names, and the shared data domains it reads are declared in `capabilities.providers`. Shells older than Hornero Signal cannot load it.
