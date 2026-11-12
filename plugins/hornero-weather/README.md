# Hornero Weather

Dashboard card (`"placement": "dashboard"`) for current
conditions (temperature, description, humidity, wind, sunrise
and sunset) plus the first forecast entries, from the read-only
PluginKit `Weather` service.

When no location is configured the card says so and shows no
fake data; provider errors are shown as errors.

No processes, no network access of its own, no settings.
Original HorneroOS code, MIT licensed. Plugin QML runs with your
user privileges inside Quickshell; it is not sandboxed.
