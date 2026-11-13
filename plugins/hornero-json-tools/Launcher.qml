import QtQuick
import Hornero.PluginKit

// JSON Tools 2.0 launcher surface: VALIDATED DECLARATION ONLY.
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
    function formatJsonText(t, indent) {
        try { return { "ok": true, "text": JSON.stringify(JSON.parse(String(t)), null, indent), "error": "" }; }
        catch (e) { return { "ok": false, "text": "", "error": String(e) }; }
    }
    function minifyJsonText(t) {
        try { return { "ok": true, "text": JSON.stringify(JSON.parse(String(t))), "error": "" }; }
        catch (e) { return { "ok": false, "text": "", "error": String(e) }; }
    }
    function quickResult(query, indent, action) {
        var n = (indent === undefined || indent === null) ? 2 : indent;
        return action === "minify" ? minifyJsonText(query) : formatJsonText(query, n);
    }
    // LOGIC-END

    function quickResultFor(q) {
        return quickResult(q, 2, "format");
    }
}
