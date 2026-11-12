# Hornero System Monitor

Dashboard card (`"placement": "dashboard"`) with CPU, memory,
GPU and storage usage bars, plus CPU/GPU temperature when the
shell reports it. Data comes only from the read-only PluginKit
`System` service.

No processes, no network, no settings. Original HorneroOS code,
MIT licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
