import QtQuick
import Hornero.PluginKit

// Color Converter 2.0 launcher surface: VALIDATED DECLARATION ONLY.
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
    function parseHex(t) {
        var m = /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$/.exec(String(t).trim());
        if (!m) return null;
        var h = m[1];
        if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
        return { "r": parseInt(h.substring(0, 2), 16), "g": parseInt(h.substring(2, 4), 16), "b": parseInt(h.substring(4, 6), 16) };
    }
    function toHex(r, g, b) {
        function h(v) { var s = v.toString(16).toUpperCase(); return s.length === 1 ? "0" + s : s; }
        return "#" + h(r) + h(g) + h(b);
    }
    function toHsl(r, g, b) {
        var rn = r / 255, gn = g / 255, bn = b / 255;
        var mx = Math.max(rn, gn, bn), mn = Math.min(rn, gn, bn), l = (mx + mn) / 2, d = mx - mn;
        var h = 0, s = 0;
        if (d !== 0) { s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
            if (mx === rn) h = (gn - bn) / d + (gn < bn ? 6 : 0); else if (mx === gn) h = (bn - rn) / d + 2; else h = (rn - gn) / d + 4; h *= 60; }
        return { "h": Math.round(h), "s": Math.round(s * 100), "l": Math.round(l * 100) };
    }
    function quickResult(query) {
        var c = parseHex(query);
        if (!c) return { "ok": false, "text": "Invalid hex: use #RGB or #RRGGBB with hex digits." };
        var hsl = toHsl(c.r, c.g, c.b);
        return { "ok": true, "text": "RGB: " + c.r + ", " + c.g + ", " + c.b + "\nHSL: " + hsl.h + ", " + hsl.s + "%, " + hsl.l + "%", "r": c.r, "g": c.g, "b": c.b };
    }
    // LOGIC-END

    function quickResultFor(q) {
        return quickResult(q);
    }
}
