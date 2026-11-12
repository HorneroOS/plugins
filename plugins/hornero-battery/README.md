# Hornero Battery

Bar widget (`"placement": "bar"`) showing battery percentage and
charging indicator from the PluginKit `Power` service
(`hasBattery`, `percentage`, `charging`, `onBattery`, `stateText`).

When `Power.hasBattery` is false — for example on a desktop with
no battery — it shows "No battery" honestly instead of a fabricated
percentage. No processes, no network, no settings. Original
HorneroOS code, MIT licensed. Plugin QML runs with your user
privileges inside Quickshell; it is not sandboxed.
