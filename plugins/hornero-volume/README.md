# Hornero Volume

Bar widget (`"placement": "bar"`) showing output volume as a
percentage from the PluginKit `Audio` service (`volume`, `muted`,
`hasSink`). Shows `Muted` when muted and `No output device` when
`Audio.hasSink` is false instead of a fabricated percentage.

Buttons: Mute/Unmute (`Audio.toggleMute()`), `-`
(`Audio.decrementVolume()`) and `+` (`Audio.incrementVolume()`),
disabled when no output device is present.

No processes, no network, no settings. Original HorneroOS code,
MIT licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
