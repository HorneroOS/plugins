# Hornero Network Scope

A desktop instrument for Hornero Signal, built on PluginKit 3
(`placement: "desktop"`, `schemaVersion: 3`). The shell host draws the module
frame and owns position, size and edit mode (`qs ipc call plugins
editDesktop`); this package lays out the content.

## What it shows (real data only)

- **Download and upload oscilloscopes** (`UiScope`, `cue` tone) from the
  shared `Telemetry` history (`netDown`, `netUp`), the previous window as
  persistence. Each eyebrow states its scale: a 1/2/5 step above the window
  peak, four divisions (`1.2 MiB/s/DIV`). In the Signal experience the trace
  gets the luminous accent; day themes, Gaming and Focus get none.
- **Current rates** in each scope's context eyebrow, formatted by the shared
  `Network.formatRate`.
- **Wi-Fi signal meter** when on Wi-Fi (`Network.signalStrength`), unavailable
  otherwise.
- **Session totals** (since the shell started) as readouts.

The facade exposes only aggregate rates, totals and link state: no interface
list, addresses or per-process traffic, so none is shown. The Wi-Fi name is
personal data and is hidden unless the `showNetworkName` setting is on. With
no usable rates the scopes say unavailable; nothing is simulated.

The widget holds one `Subscription { domain: "network" }` lease and starts no
timer, process or network access of its own; the shared provider reads
`/proc/net/dev` once per shell at the experience cadence. The host suspends
desktop widgets in the `gaming` experience.

## Settings

`showSessionTotals` (default `true`), `showNetworkName` (default `false`), `scale` (`auto` default, or a fixed
`1 MiB/s`, `10 MiB/s`, `100 MiB/s`; samples above a fixed scale are clipped).
There is no interface setting: the shared network provider reports the
active connection only.

## Enable

```sh
horneroctl plugin catalog install hornero-network-scope --yes
horneroctl plugin enable hornero-network-scope --yes
```

Plugin QML runs with your user privileges inside Quickshell; it is not
sandboxed. Original HorneroOS code, MIT licensed. No processes, no network.

## PluginKit 3

This package targets PluginKit 3 on Hornero Signal (`schemaVersion: 3`):
colours, type, spacing and glyphs come from the shared Theme tokens and the
shared data domain it reads is declared in `capabilities.providers`.
