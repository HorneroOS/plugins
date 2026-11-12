# Hornero Moon Phase

Desktop widget (`"placement": "desktop"`) showing the current
moon phase name and illumination, computed in pure JS with the
synodic approximation: age since the known new moon
2000-01-06 18:14 UTC, modulo the 29.530588853-day cycle, with
illumination `(1 - cos(2π·age/cycle)) / 2`.

The result is an approximation (it ignores orbital perturbation)
and is labelled "approximate" in the widget. No processes, no
network, no settings. Original HorneroOS code, MIT licensed.
Plugin QML runs with your user privileges inside Quickshell; it
is not sandboxed.
