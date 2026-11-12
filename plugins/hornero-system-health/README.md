# Hornero System Health

Dashboard card (`"placement": "dashboard"`) summarising system
health from the PluginKit services: CPU, memory and storage from
`System` (`cpuPerc`, `memPerc`, `storagePerc`), battery from
`Power` (`hasBattery`, `percentage`, `charging`, `stateText`),
and download/upload speeds from `Network` (`downloadSpeed`,
`uploadSpeed`).

Each row is honest about missing data: the battery row shows
`No battery` on machines without a battery, and numeric rows show
`Unavailable` when a service reports no usable value instead of
fabricating a reading.

Original HorneroOS design. No processes, no network, no settings.
MIT licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
