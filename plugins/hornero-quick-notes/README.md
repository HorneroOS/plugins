# Hornero Quick Notes

Dashboard card (`"placement": "dashboard"`) with one persistent
note stored through the PluginKit `Settings` API (`pluginId`
`hornero-quick-notes`, declared string setting `note`, default
`""`). The stored value is loaded on completion, edits are saved
debounced after 600 ms, and the character count is shown. Text
longer than 4096 characters is truncated before saving (with a
visible truncation note) so it never exceeds the Settings limit.

No processes, no network. Original HorneroOS code, MIT licensed.
Plugin QML runs with your user privileges inside Quickshell; it
is not sandboxed.
