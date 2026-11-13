import QtQuick
import Hornero.PluginKit

// Calculator 2.0 launcher surface: VALIDATED DECLARATION ONLY.
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
    function tokenize(input) {
        var tokens = [];
        var i = 0;
        while (i < input.length) {
            var c = input[i];
            if (c === " " || c === "\t") { i++; continue; }
            if ((c >= "0" && c <= "9") || c === ".") {
                var j = i; var dots = 0;
                while (j < input.length && ((input[j] >= "0" && input[j] <= "9") || input[j] === ".")) {
                    if (input[j] === ".") dots++;
                    j++;
                }
                if (dots > 1) return null;
                var value = parseFloat(input.substring(i, j));
                if (!isFinite(value)) return null;
                tokens.push({ "type": "number", "value": value });
                i = j; continue;
            }
            if ("+-*/%()".indexOf(c) >= 0) { tokens.push({ "type": c }); i++; continue; }
            return null;
        }
        return tokens;
    }
    function calculate(input) {
        var tokens = tokenize(input);
        if (!tokens || tokens.length === 0) return { "ok": false };
        var pos = 0;
        function peek() { return pos < tokens.length ? tokens[pos] : null; }
        function parseExpr() {
            var v = parseTerm();
            if (v === null) return null;
            while (peek() && (peek().type === "+" || peek().type === "-")) {
                var op = tokens[pos++].type;
                var r = parseTerm();
                if (r === null) return null;
                v = (op === "+") ? v + r : v - r;
            }
            return v;
        }
        function parseTerm() {
            var v = parseFactor();
            if (v === null) return null;
            while (peek() && (peek().type === "*" || peek().type === "/" || peek().type === "%")) {
                var op = tokens[pos++].type;
                var r = parseFactor();
                if (r === null) return null;
                if ((op === "/" || op === "%") && r === 0) return null;
                if (op === "*") v = v * r;
                else if (op === "/") v = v / r;
                else v = v % r;
            }
            return v;
        }
        function parseFactor() {
            var t = peek();
            if (!t) return null;
            if (t.type === "-") { pos++; var n = parseFactor(); return n === null ? null : -n; }
            if (t.type === "+") { pos++; return parseFactor(); }
            if (t.type === "(") {
                pos++;
                var inner = parseExpr();
                if (inner === null || !peek() || peek().type !== ")") return null;
                pos++;
                return inner;
            }
            if (t.type === "number") { pos++; return t.value; }
            return null;
        }
        var resultValue = parseExpr();
        if (resultValue === null || pos !== tokens.length || !isFinite(resultValue)) return { "ok": false };
        return { "ok": true, "value": resultValue };
    }
    function quickResult(query) {
        var outcome = calculate(String(query));
        if (!outcome.ok) return { "ok": false, "text": "Error" };
        var rounded = Math.round(outcome.value * 10000000000) / 10000000000;
        return { "ok": true, "text": String(rounded) };
    }
    // LOGIC-END

    function quickResultFor(q) {
        return quickResult(q);
    }
}
