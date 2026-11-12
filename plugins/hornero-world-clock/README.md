# Hornero World Clock

Dashboard card (`"placement": "dashboard"`) showing local time,
UTC, and three fixed cities: Buenos Aires, Madrid and Tokyo.

City times are computed by round-tripping a JS `Date` through
`toLocaleString("en-US", {timeZone})`, so the named zone's rules
(including daylight saving) apply when the JS engine supports
`timeZone`. When that conversion is unavailable, a fixed UTC
offset is used and the row is labelled with that offset (for
example `UTC-03:00`); no DST behaviour is claimed for the fallback.

Data comes only from the read-only PluginKit `Time` service
ticking once per second. No processes, no network, no settings.
Original HorneroOS code, MIT licensed. Plugin QML runs with your
user privileges inside Quickshell; it is not sandboxed.
