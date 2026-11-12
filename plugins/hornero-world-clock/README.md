# Hornero World Clock

Dashboard card (`"placement": "dashboard"`) showing local time,
UTC, and three fixed cities: Buenos Aires, Madrid and Tokyo.

City times are computed by round-tripping a JS `Date` through
Offsets are computed in pure JS: Buenos Aires UTC-3 and Tokyo UTC+9 year-round; Madrid follows the EU DST rule (UTC+1, UTC+2 from the last Sunday of March 01:00 UTC to the last Sunday of October 01:00 UTC). Each row is labelled with the offset actually applied.

Data comes only from the read-only PluginKit `Time` service
ticking once per second. No processes, no network, no settings.
Original HorneroOS code, MIT licensed. Plugin QML runs with your
user privileges inside Quickshell; it is not sandboxed.
