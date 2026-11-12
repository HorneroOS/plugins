# Hornero Sun Card

Dashboard card (`"placement": "dashboard"`) showing sunrise,
sunset, temperature, description and humidity from the
PluginKit `Weather` service. Shows a not-configured state when
`Weather.locationConfigured` is false instead of fake data, an
error state for `Weather.lastError`, and a loading state until
`Weather.ready`.

No processes, no network (weather fetching is owned by the
shell service), no settings. Original HorneroOS code, MIT
licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
