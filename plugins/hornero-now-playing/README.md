# Hornero Now Playing

Bar widget (`"placement": "bar"`) showing the active player's
identity, track title and artist from the read-only PluginKit
`Media` service. Previous, play/pause and next buttons (with
accessible names and tooltips) call `Media.previous()`,
`Media.playPause()` and `Media.next()` only when clicked.

No processes, no network, no settings. Original HorneroOS code,
MIT licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
