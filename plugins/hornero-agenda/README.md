# Hornero Agenda

Desktop widget (`"placement": "desktop"`) showing weekday, day,
month, ISO week number, day of year and days remaining in the
year. All values are computed with pure Date math from the
PluginKit `Time` facade (`Time.date`, which updates as time
passes, so the widget rolls over daily). The ISO week uses the
Thursday rule (shift to Thursday, count from 1 January of that
year); day of year uses UTC date arithmetic to avoid DST drift.

No processes, no network, no settings. Original HorneroOS code,
MIT licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
