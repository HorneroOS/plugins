# Hornero Studio Audio

A compact bar indicator for the HorneroOS Studio audio mode:
`STUDIO BAL` (Balanced), `STUDIO LL` (Low Latency) or `STUDIO ADV`
(Advanced), plus `· PERF` while Temporary Performance is active.

It reads the typed contract `horneroctl --json studio mode`
(HorneroOS/hornero#286/#287) every 60 seconds; clicking it refreshes
immediately. Balanced is the device default; Low Latency and Advanced
are explicit opt-ins, and the previous state is always restorable —
but switching modes is an explicit action that stays in the CLI
(`horneroctl studio mode audio …`) and the Control Center Studio pane.
This indicator changes nothing.

## Install

```sh
horneroctl plugin catalog install hornero-studio-audio --yes
horneroctl plugin enable hornero-studio-audio --yes
```

Then restart the shell (`horneroctl shell restart --yes`). The
indicator appears at the end of the bar.

## Trust note

Enabled plugin QML runs inside Quickshell with your user privileges;
it is **not sandboxed**. This plugin only runs the fixed command
`horneroctl --json studio mode` (declared in
`capabilities.processCommands`) and displays the recorded mode. It
never writes PipeWire configuration, restarts services, or touches
power profiles.

## License

MIT — see `LICENSE`.
