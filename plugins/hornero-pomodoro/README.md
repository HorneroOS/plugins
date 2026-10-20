# Hornero Pomodoro

A 25-minute focus timer for the bar. Click to start or pause; it rings (visually) at zero and resets. No processes, no network, just time and discipline.

First-party HorneroOS extension. Install with:

```sh
horneroctl plugin install https://github.com/HorneroOS/plugins.git --dry-run
```

(then re-run with `--yes`, and enable it from the Control Center Extensions pane or `horneroctl plugin enable hornero-pomodoro --yes`.)

QML plugins run with your user privileges — Hornero Shell does not sandbox them. Review the source in this repository before enabling.
