# Hornero System Insight

A Rainmeter/Conky-class desktop instrument for Hornero Signal, built on
PluginKit 3 (`placement: "desktop"`, `schemaVersion: 3`). The shell host
draws the module frame and owns position, size and edit mode
(`qs ipc call plugins editDesktop`); this package lays out the content.

## What it shows (real data only)

- **CPU oscilloscope** (`UiScope`): the shared `Telemetry` window of the
  `cpu` channel, the previous window as persistence, scale stated in the
  eyebrow. In the Signal experience (dark theme, motion allowed) the trace
  gets the luminous accent; day themes and Gaming/Focus get none.
- **Segmented meters** (`UiMeterRow`) for CPU, memory, GPU and storage that
  cross to `signal` at the typed threshold (default 85 %). A sensor that
  does not exist shows an em dash and all segments off, never 0.
- **Per-core load strips** (`UiSegmentMeter`, one per logical CPU) from the
  same /proc/stat sample, when the widget is tall enough.
- **Temperatures and memory** as readouts when the provider reports them.

No placeholder waves, no idle animation, no interpolated samples. The widget
holds one `Subscription { domain: "system" }` lease and starts no timer,
process or file poll of its own: the shared provider samples once per shell,
at 1 Hz everyday and 2 Hz in Signal, and stops when nothing holds a lease.
The host suspends desktop widgets in the `gaming` experience.

## Settings

`showCores` (default `true`), `showTemperatures` (default `true`),
`warnPercent` (50-100, default `85`), `showGpu` and `showDisk` (default
`true`), `temperatureUnit` (`celsius` default, or `fahrenheit`; a display
conversion of the provider's Celsius value). The scope window length is fixed
by the shared Telemetry history, so it is not a setting.

## Enable

```sh
horneroctl plugin catalog install hornero-system-insight --yes
horneroctl plugin enable hornero-system-insight --yes
```

Plugin QML runs with your user privileges inside Quickshell; it is not
sandboxed. Original HorneroOS code, MIT licensed. No processes, no network.

## PluginKit 3

This package targets PluginKit 3 on Hornero Signal (`schemaVersion: 3`):
colours, type, spacing and glyphs come from the shared Theme tokens and the
shared data domain it reads is declared in `capabilities.providers`.
