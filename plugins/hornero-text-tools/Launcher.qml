import QtQuick
import Hornero.PluginKit

// Text Tools 2.0 launcher surface: VALIDATED DECLARATION ONLY.
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
    function transformText(t, mode) {
        if (mode === "Uppercase") return t.toUpperCase();
        if (mode === "Lowercase") return t.toLowerCase();
        if (mode === "Reverse") { var s = ""; for (var i = t.length - 1; i >= 0; i--) s += t[i]; return s; }
        var lower = t.toLowerCase(); var out = ""; var cap = true;
        for (var k = 0; k < lower.length; k++) { var ch = lower[k]; out += cap ? ch.toUpperCase() : ch; cap = (ch === " " || ch === "\t" || ch === "\n"); }
        return out;
    }
    function countWordsText(t) { var s = t.trim(); return s === "" ? 0 : s.split(/\s+/).length; }
    function countLinesText(t) { return t === "" ? 0 : t.split("\n").length; }
    function modeFromSetting(key) {
        if (key === "lowercase") return "Lowercase";
        if (key === "title-case") return "Title Case";
        if (key === "reverse") return "Reverse";
        return "Uppercase";
    }
    function quickResult(query, modeKey) {
        var t = String(query);
        return { "ok": true, "text": transformText(t, modeFromSetting(modeKey)), "characters": t.length, "words": countWordsText(t), "lines": countLinesText(t) };
    }
    // LOGIC-END

    function quickResultFor(q) {
        return quickResult(q, "uppercase");
    }
}
