import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Calculator 2.0 bar surface (primary): a one-button quick action.
// The button opens a host-owned UiPopover with one quick-query field
// and the same pure logic as the dashboard detail panel; the full
// controls stay there. This is the launcher-style quick action that
// is hosted today. The declared launcher surface (Launcher.qml) is
// a validated declaration only until the shell launcher provider
// host (HorneroOS/shell#250) exists; no parallel launcher and no
// invented PluginKit launcher member is used here. PluginKit has
// no text-input primitive, so the query field is a QtQuick.Controls
// TextField with an accessible name and tooltip.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property string hostEdge: "top"
    property string hostSurface: "bar"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: stack.implicitWidth
    implicitHeight: stack.implicitHeight

    property string quickText: ""

    Translations { id: i18n; pluginId: "hornero-calculator" }
    Settings { id: pluginSettings; pluginId: "hornero-calculator" }

    readonly property bool liveResult: pluginSettings.value("liveResult", false) === true

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

    function runQuick() {
        var outcome = quickResult(quickInput.text);
        root.quickText = outcome.ok ? outcome.text : (outcome.error && outcome.error !== "" ? outcome.error : outcome.text);
    }

    UiStack {
        id: stack
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator
            variant: "ghost"
            text: "="
            tooltipText: i18n.tr("Calculator: activate for a quick expression")
            accessibleName: i18n.tr("Calculator quick action")
            onClicked: popover.toggle()
        }

        UiText {
            visible: !root.hostCompact && root.hostOrientation !== "vertical" && root.quickText !== ""
            width: 140
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            text: root.quickText
        }
    }

    UiPopover {
        id: popover
        target: indicator
        accessibleName: i18n.tr("Calculator quick action")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Calculator") }

            TextField {
                id: quickInput
                width: parent.width
                placeholderText: i18n.tr("e.g. (2 + 3) * 4")
                Accessible.name: i18n.tr("Quick calculator expression")
                ToolTip.text: i18n.tr("Quick calculator expression")
                ToolTip.visible: hovered
                onAccepted: root.runQuick()
                onTextChanged: { if (root.liveResult) root.runQuick(); }
            }

            UiButton {
                text: i18n.tr("Compute")
                tooltipText: i18n.tr("Compute")
                accessibleName: i18n.tr("Compute")
                onClicked: root.runQuick()
            }

            UiState {
                visible: root.quickText === ""
                width: parent.width
                kind: "empty"
                message: i18n.tr("Type an expression and press Compute. Division by zero shows Error.")
            }

            UiText {
                visible: root.quickText !== ""
                width: parent.width
                text: root.quickText
            }

            UiText {
                width: parent.width
                role: "caption"
                text: i18n.tr("Full controls are in the dashboard Utilities panel.")
            }
        }
    }
}
