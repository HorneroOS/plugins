# Hornero Microphone

Bar widget (`"placement": "bar"`) showing microphone volume as a
percentage and muted state from the PluginKit `Audio` service
(`sourceVolume`, `sourceMuted`, `hasSource`). Shows
`No input device` when `Audio.hasSource` is false instead of a
fabricated percentage. The button toggles the microphone mute via
`Audio.toggleSourceMute()` and is disabled with no input device.

Privacy: this widget shows only muted/volume state. It never
records, captures, stores or transmits audio.

No processes, no network, no settings. Original HorneroOS code,
MIT licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
