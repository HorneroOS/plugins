# Hornero Unit Converter

Dashboard card (`"placement": "dashboard"`) converting length
(m, km, mi, ft), mass (kg, lb) and temperature (C, F, K) in pure
JS. Enter a value in the text field, pick a category and from/to
units with the selectors; the result is computed live.

Formulas: `F = C * 9/5 + 32`, `K = C + 273.15`,
`mi = km * 0.621371`, `lb = kg * 2.20462` (applied via metre /
kilogram / Celsius base units; 1 ft = 0.3048 m). Invalid input
shows "Enter a value" instead of a fabricated result. No
processes, no network, no settings. Original HorneroOS code, MIT
licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
