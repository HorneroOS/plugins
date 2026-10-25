# Hornero Studio Jobs

A read-only render and export monitor for HorneroOS Studio, shown as a
card in the dashboard Extensions tab.

It lists the jobs recorded by the typed Hornero contract
(`horneroctl --json studio jobs list`, HorneroOS/hornero#289): state
(`queued`, `running`, `succeeded`, `failed`, `cancelled`,
`interrupted`), adapter (`blender-render`, `ffmpeg-export`) and output
file name. It refreshes every 30 seconds.

This plugin never submits, runs or cancels a job. Those are explicit
actions that belong to the CLI (`horneroctl studio jobs submit|run|cancel`)
and the Control Center Studio pane, so nothing here can start work on
your machine by itself.

## Install

```sh
horneroctl plugin catalog install hornero-studio-jobs --yes
horneroctl plugin enable hornero-studio-jobs --yes
```

Then restart the shell (`horneroctl shell restart --yes`) and open the
dashboard Extensions tab.

## Trust note

Enabled plugin QML runs inside Quickshell with your user privileges;
it is **not sandboxed**. This plugin only runs the fixed command
`horneroctl --json studio jobs list` (declared in
`capabilities.processCommands`) and displays what it returns. Job logs
stay in the CLI, where they are redacted on read; the plugin never
reads your project files.

## License

MIT — see `LICENSE`.
