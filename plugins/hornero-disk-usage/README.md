# Hornero Disk Usage

Dashboard card (`"placement": "dashboard"`) listing disks from
the read-only PluginKit `System.disks` service. Each disk shows
its mount point, used / total space and a percentage bar. When
the service reports no disks, an explicit empty state is shown
instead of fabricated values.

No processes, no network, no settings. Original HorneroOS code,
MIT licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
