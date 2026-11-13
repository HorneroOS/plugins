import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Calculator 2.0 dashboard surface: the optional detailed panel
// (compact card, Utilities category) with the full 1.x controls
// over the same pure LOGIC block as the bar quick action and the
// declared launcher entrypoint. PluginKit has no text-input,
// combo-box or spin-box primitive, so those remain QtQuick.Controls
// with accessible names and tooltips; buttons, text, cards and
// states use PluginKit Ui primitives and Theme tokens.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    Translations { id: i18n; pluginId: "hornero-calculator" }
    Settings { id: pluginSettings; pluginId: "hornero-calculator" }

    readonly property bool showKeypad: pluginSettings.value("showKeypad", true) !== false
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
    property string result: ""
    function compute() {
        var outcome = quickResult(input.text);
        root.result = outcome.ok ? outcome.text : "Error";
    }
    function press(key) {
        if (key === "C") { input.text = ""; root.result = ""; return; }
        if (key === "=") { root.compute(); return; }
        input.text += key;
    }

    UiCard {
        id: card
        anchors.fill: parent
        Accessible.name: i18n.tr("Calculator")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Calculator") }

            TextField {
                id: input
                width: parent.width
                placeholderText: "e.g. (2 + 3) * 4"
                Accessible.name: i18n.tr("Calculator expression")
                ToolTip.text: i18n.tr("Calculator expression")
                ToolTip.visible: hovered
                onAccepted: root.compute()
            }
            UiText {
                width: parent.width
                role: "title"
                color: root.result === "Error" ? Theme.error : Theme.onSurface
                Accessible.name: i18n.tr("Calculator result")
                text: root.result === "" ? i18n.tr("Result") : (root.result === "Error" ? i18n.tr("Error") : "= " + root.result)
            }
            Grid {
                visible: root.showKeypad
                width: parent.width
                columns: 4
                spacing: 6
                Repeater {
                    model: ["7", "8", "9", "/", "4", "5", "6", "*", "1", "2", "3", "-", "0", ".", "%", "+", "(", ")", "C", "="]
                    delegate: UiButton {
                        required property var modelData
                        width: (parent.width - 18) / 4
                        variant: "ghost"
                        text: modelData
                        accessibleName: modelData === "C" ? i18n.tr("Clear calculator") : (modelData === "=" ? i18n.tr("Compute result") : i18n.tr("Calculator key") + " " + modelData)
                        tooltipText: modelData === "C" ? i18n.tr("Clear") : (modelData === "=" ? i18n.tr("Compute result") : i18n.tr("Insert") + " " + modelData)
                        onClicked: root.press(String(modelData))
                    }
                }
            }
        }
    }
}
