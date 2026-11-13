# Hornero Metronome

Metronome 2.0 (HorneroOS/plugins#24): a compact bar indicator
(`"placement": "bar"`, single surface — a second surface would
be a second, independent beat) opening a host-owned PluginKit
popover with the beat dot, tempo, a BPM `UiSlider`, the 1.x
`-`/`+` buttons and Start/Stop. All controls are PluginKit
`Ui*` controls: keyboard operable, accessible names,
host-owned tooltips, Theme tokens, host context
(`hostOrientation` / `hostCompact` via `UiStack`; the compact
indicator shows just the number) and English source strings
with an Argentine Spanish catalog (`translations/es.json`, via
PluginKit `Translations`).

Beats are deadline-scheduled: a 50 ms poll compares the wall
clock with the next beat deadline (every `60000 / bpm` ms, as
in 1.x) and advances by whole beat intervals, so Timer drift
cannot accumulate. Beats missed while suspended/asleep are
skipped in one step — never replayed as a flash burst — and
the schedule re-anchors on the next future beat. The beat
flash itself is still 140 ms, as in 1.x.

## Compatibility

- BPM stays the persisted PluginKit `Settings` integer `bpm`
  (default **96**), now declaring the `minimum: 40` /
  `maximum: 208` bounds the 1.x QML clamp already enforced on
  every write — so every previously stored value still
  satisfies the declaration and keeps working unchanged.
- New: `beatsPerBar` (integer, 1–12, default 4) and
  `accentFirstBeat` (boolean, default **false** — the 1.x
  uniform flash). With the accent on, beat 1 of each bar
  flashes in `Theme.tertiary`.
- The metronome does **not** persist its running state: a
  shell/plugin reload stops the beat, as in 1.x. It has no
  completion event, so it sends no toast.

No processes, no network. Original HorneroOS code, MIT
licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
