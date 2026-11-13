import QtQuick
import Hornero.PluginKit

// Unit Converter 2.0 launcher surface: VALIDATED DECLARATION ONLY.
// The shell has no launcher provider host yet (HorneroOS/shell#250,
// plugin-side architecture shell#222), so this entrypoint is not
// loaded and no code runs from this declaration today (shell
// docs/PLUGINS.md, "Manifest v2: multiple surfaces"). There is no
// PluginKit launcher/search member to call, and this file invents
// none: it only carries the package-local quick-query logic (the
// LOGIC block, verbatim in Main.qml/Dashboard.qml/Launcher.qml and
// covered by tests/test_utility_logic.py) behind plain Item
// properties, so a future host contract can bind a query string
// and read a result without a parallel launcher being built here.
Item {
    id: root

    property string query: ""
    readonly property var result: quickResultFor(query)

    // LOGIC-BEGIN
    function toBase(value, unit) {
        if (unit === "km") return value * 1000;
        if (unit === "mi") return value * 1000 / 0.621371;
        if (unit === "ft") return value * 0.3048;
        if (unit === "lb") return value / 2.20462;
        if (unit === "F") return (value - 32) * 5 / 9;
        if (unit === "K") return value - 273.15;
        return value;
    }
    function fromBase(base, unit) {
        if (unit === "km") return base / 1000;
        if (unit === "mi") return (base / 1000) * 0.621371;
        if (unit === "ft") return base / 0.3048;
        if (unit === "lb") return base * 2.20462;
        if (unit === "F") return base * 9 / 5 + 32;
        if (unit === "K") return base + 273.15;
        return base;
    }
    function convert(value, fromUnit, toUnit) { return fromBase(toBase(value, fromUnit), toUnit); }
    function unitCategory(unit) {
        if (unit === "m" || unit === "km" || unit === "mi" || unit === "ft") return "length";
        if (unit === "kg" || unit === "lb") return "mass";
        if (unit === "C" || unit === "F" || unit === "K") return "temperature";
        return "";
    }
    function normalizeUnit(unit) {
        var u = String(unit);
        var lower = u.toLowerCase();
        if (lower === "c" || lower === "f" || lower === "k") return lower.toUpperCase();
        return lower;
    }
    function quickResult(query, precision) {
        var p = (precision === undefined || precision === null) ? 6 : precision;
        var m = /^\s*(-?\d+(?:\.\d+)?)\s*([A-Za-z]+)\s+(?:to\s+)?([A-Za-z]+)\s*$/.exec(String(query));
        if (!m) return { "ok": false, "text": "Enter a value" };
        var value = parseFloat(m[1]);
        var fromUnit = normalizeUnit(m[2]);
        var toUnit = normalizeUnit(m[3]);
        if (!isFinite(value) || unitCategory(fromUnit) === "" || unitCategory(fromUnit) !== unitCategory(toUnit))
            return { "ok": false, "text": "Enter a value" };
        var result = convert(value, fromUnit, toUnit);
        var factor = Math.pow(10, p);
        var rounded = Math.round(result * factor) / factor;
        return { "ok": true, "text": value + " " + fromUnit + " = " + rounded + " " + toUnit };
    }
    // LOGIC-END

    function quickResultFor(q) {
        return quickResult(q, 6);
    }
}
