import QtQuick
import Hornero.PluginKit

// Base Converter 2.0 launcher surface: VALIDATED DECLARATION ONLY.
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
    function convertDecText(t, uppercaseHex) {
        var s = String(t).trim();
        if (!/^-?[0-9]+$/.test(s)) return { "ok": false, "text": "", "error": "Enter a decimal integer (digits only, optional minus)." };
        var v = Number(s);
        if (!isFinite(v) || Math.abs(v) > Number.MAX_SAFE_INTEGER) return { "ok": false, "text": "", "error": "Out of safe range (max Number.MAX_SAFE_INTEGER)." };
        var sign = v < 0 ? "-" : ""; var a = Math.abs(v);
        var hex = a.toString(16);
        if (uppercaseHex !== false) hex = hex.toUpperCase();
        return { "ok": true, "text": "Binary: " + sign + a.toString(2) + "\nOctal: " + sign + a.toString(8) + "\nHex: " + sign + hex, "error": "" };
    }
    function convertHexText(t) {
        var s = String(t).trim();
        if (!/^-?[0-9A-Fa-f]+$/.test(s)) return { "ok": false, "text": "", "error": "Enter hex digits (0-9, A-F, optional minus) only." };
        var neg = s[0] === "-"; var digits = neg ? s.substring(1) : s;
        var v = parseInt(digits, 16);
        if (!isFinite(v) || v > Number.MAX_SAFE_INTEGER) return { "ok": false, "text": "", "error": "Out of safe range (max Number.MAX_SAFE_INTEGER)." };
        return { "ok": true, "text": "Decimal: " + (neg ? -v : v), "error": "" };
    }
    function quickResult(query, uppercaseHex) {
        var s = String(query).trim();
        var m = /^(-?)0x([0-9A-Fa-f]+)$/.exec(s);
        if (m) return convertHexText(m[1] + m[2]);
        return convertDecText(s, uppercaseHex);
    }
    // LOGIC-END

    function quickResultFor(q) {
        return quickResult(q, true);
    }
}
