# Hornero Uptime

Bar widget (`"placement": "bar"`) showing system uptime as
days/hours/minutes. It reads `/proc/uptime` with the declared
`cat` command (`"processCommands": ["cat"]`) on load and every
60 seconds, parsing the first field (seconds since boot).

If `/proc/uptime` is unreadable or unparsable, the widget shows
an "Uptime unavailable" error state instead of a fabricated
zero. No network, no settings. Original HorneroOS code, MIT
licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
