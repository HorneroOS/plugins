# Hornero Metronome

Bar widget (`"placement": "bar"`) with a flashing beat indicator
driven by a `Timer` at `60000 / bpm` ms. BPM is a persisted
PluginKit `Settings` integer (`pluginId` `hornero-metronome`,
declared setting `bpm`, default `96`), clamped to 40-208 and
saved on every `-`/`+` change. Start/Stop toggles the beat.

No processes, no network. Original HorneroOS code, MIT licensed.
Plugin QML runs with your user privileges inside Quickshell; it
is not sandboxed.
