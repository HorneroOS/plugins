# Hornero Studio Audio

Audio Extensions 2.0 (manifest v2, HorneroOS/plugins#25): one
package, two surfaces. Studio mode and Temporary Performance
come from the existing typed contract
`horneroctl --json studio mode` (HorneroOS/hornero#286/#287);
current output state comes read-only from the shared PluginKit
`Audio` facade (the surfaces hold a
`Subscription { domain: "audio" }` lease). No PipeWire object is
manipulated from this QML.

- **Bar** (`"placement": "bar"`, primary): a compact mode-code
  indicator (`BAL` / `LL` / `ADV`, `?` while unavailable, as in
  1.x) with the `ST`/`PERF` captions on roomy horizontal bars.
  Activating it opens a host-owned `UiPopover` with the full
  mode name, Temporary Performance state, read-only output
  state and a refresh button.
- **Dashboard** (`surfaces.dashboard`, `size: "standard"`,
  `category: "Audio"`): the same detail as a card.

## Safe controls: deliberately read-only

The issue asks for safe device/profile controls *through
existing typed contracts*. The typed studio contract this
package already uses is a status read; mode switching is an
explicit opt-in owned by `horneroctl` and Control Center, and
PluginKit `Audio` exposes no device/profile selection at all
(shell `docs/PLUGINS.md`). So 2.0 keeps mode control where the
typed contract puts it and says so in the popover/card, instead
of shelling out to arbitrary PipeWire manipulation from QML.
The only user-initiated action here is Refresh (a re-read; 1.x
did the same on click, now via a real keyboard-operable button
instead of a mouse-only area).

## States

- **Unavailable** (horneroctl missing, failing or returning no
  usable mode): the bar keeps the honest 1.x `?` label (unless
  `showWhenUnavailable` is off); popover and card show an error
  state naming the failed read instead of a stale mode.
- **Unknown mode string**: shown as an unknown mode rather than
  mapped onto a known one.
- **No output device**: the popover/card output line says so
  instead of inventing a level.

## Compatibility

- No settings existed before 2.0, so no stored values migrate.
  New typed settings default to the 1.x behaviour:
  `refreshSeconds` (integer 15–3600, default `60`, the 1.x
  60-second poll — each surface polls on its own timer as the
  single 1.x surface did) and `showWhenUnavailable`
  (boolean, default `true`).
- The 1.x mouse-only click-to-refresh is replaced by the
  popover Refresh button (keyboard contract); the 60-second
  timer behaviour is unchanged at the default.
- Installing this manifest v2 package needs a shell/`horneroctl`
  that accepts `schemaVersion` 2, `translations` and
  `marketplace`.

Both surfaces use PluginKit `Ui*` primitives, host context,
host-owned tooltips, accessible names, Theme tokens (1.x used
raw palette text) and an Argentine Spanish catalog
(`translations/es.json`; mode codes `BAL`/`LL`/`ADV` and the
`ST`/`PERF` captions are codes, kept as-is). One declared
process (`horneroctl`), no network. Original HorneroOS code,
MIT licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
