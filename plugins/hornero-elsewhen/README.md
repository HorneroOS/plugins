# Hornero Elsewhen

World timezone converter dashboard card for distributed teams (PluginKit 3,
`schemaVersion: 3`).

## What it does

- Compares time across UTC, Americas (Los Angeles, New York, Buenos Aires),
  Europe (London, Madrid) and Asia (New Delhi, Tokyo)
- Interactive `-1h` / `Now` / `+1h` scrubber to test meeting times up to ±12h
- Highlights working-hour overlap (`WORK` / `OFF`) per zone
- Built-in pure-JS DST rules; uses the shared PluginKit `time` provider with no
  processes, no network requests, and no private timer

## Settings

`twentyFourHour`, `workStartHour` (0-23), `workEndHour` (1-24), `showOffHours`.

## Permissions

None (`processCommands: []`, `networkHosts: []`, `providers: ["time"]`).

## Enable

```sh
horneroctl plugin catalog install hornero-elsewhen --yes
horneroctl plugin enable hornero-elsewhen --yes
```

Original HorneroOS code, MIT licensed.
