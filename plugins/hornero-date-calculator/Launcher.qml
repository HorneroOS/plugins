import QtQuick
import Hornero.PluginKit

// Date Calculator 2.0 launcher surface: VALIDATED DECLARATION ONLY.
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
    function parseDate(t) {
        var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(t).trim());
        if (!m) return null;
        var y = Number(m[1]), mo = Number(m[2]), d = Number(m[3]);
        var dt = new Date(Date.UTC(y, mo - 1, d));
        if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== d) return null;
        return dt;
    }
    function fmtDate(dt) {
        function p(v) { return v < 10 ? "0" + v : String(v); }
        return dt.getUTCFullYear() + "-" + p(dt.getUTCMonth() + 1) + "-" + p(dt.getUTCDate());
    }
    function daysBetweenText(aText, bText) {
        var a = parseDate(aText), b = parseDate(bText);
        if (!a || !b) return { "ok": false, "text": "", "error": "Enter real dates as YYYY-MM-DD (e.g. 2026-02-30 is rejected)." };
        var days = Math.round((b.getTime() - a.getTime()) / 86400000);
        return { "ok": true, "text": "Days between: " + days, "error": "" };
    }
    function addDaysText(baseText, daysText) {
        var a = parseDate(baseText);
        if (!a) return { "ok": false, "text": "", "error": "Enter a real base date as YYYY-MM-DD." };
        var s = String(daysText).trim();
        var n = Number(s);
        if (s === "" || !isFinite(n) || Math.floor(n) !== n) return { "ok": false, "text": "", "error": "Enter an integer number of days to add." };
        var dt = new Date(a.getTime() + n * 86400000);
        return { "ok": true, "text": "Resulting date: " + fmtDate(dt), "error": "" };
    }
    function quickResult(query) {
        var parts = String(query).trim().split(/\s+/);
        if (parts.length === 2 && parseDate(parts[0]) && parseDate(parts[1])) return daysBetweenText(parts[0], parts[1]);
        if (parts.length === 2) return addDaysText(parts[0], parts[1]);
        return { "ok": false, "text": "", "error": "Enter real dates as YYYY-MM-DD (e.g. 2026-02-30 is rejected)." };
    }
    // LOGIC-END

    function quickResultFor(q) {
        return quickResult(q);
    }
}
