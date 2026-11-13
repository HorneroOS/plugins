# Hornero Date Calculator

Dashboard card (`"placement": "dashboard"`) with two modes: days between two dates, and base date plus N days. Dates must be real `YYYY-MM-DD` dates (e.g. `2026-02-30` is rejected). All math uses UTC (`Date.UTC`, `getUTC*`, 86400000 ms/day) to avoid DST drift, as stated in the UI. Pure QML, no settings. Original HorneroOS code, MIT licensed. Plugin QML runs with your user privileges inside Quickshell; it is not sandboxed.
