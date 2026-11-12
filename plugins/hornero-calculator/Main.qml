import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Calculator - dashboard card with a safe expression
// parser: tokenizer plus recursive descent for + - * / %,
// parentheses, decimals and unary minus. No dynamic code
// execution is used. Division or modulo by zero shows Error.
Item {
    id: root

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    property string result: ""

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

    function compute() {
        var outcome = calculate(input.text);
        if (!outcome.ok) { root.result = "Error"; return; }
        var rounded = Math.round(outcome.value * 10000000000) / 10000000000;
        root.result = String(rounded);
    }

    function press(key) {
        if (key === "C") { input.text = ""; root.result = ""; return; }
        if (key === "=") { root.compute(); return; }
        input.text += key;
    }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text { color: Theme.onSurface; text: "Calculator"; font.bold: true; font.pixelSize: 14 }

        TextField {
            id: input
            width: parent.width
            placeholderText: "e.g. (2 + 3) * 4"
            Accessible.name: "Calculator expression"
            ToolTip.text: "Calculator expression"
            ToolTip.visible: hovered
            onAccepted: root.compute()
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            color: root.result === "Error" ? Theme.error : Theme.onSurface
            font.pixelSize: 16
            font.bold: true
            Accessible.name: "Calculator result"
            text: root.result === "" ? "Result" : (root.result === "Error" ? "Error" : "= " + root.result)
        }

        Grid {
            width: parent.width
            columns: 4
            spacing: 6

            Repeater {
                model: ["7", "8", "9", "/", "4", "5", "6", "*", "1", "2", "3", "-", "0", ".", "%", "+", "(", ")", "C", "="]

                delegate: Button {
                    required property var modelData
                    width: (parent.width - 18) / 4
                    text: modelData
                    Accessible.name: modelData === "C" ? "Clear calculator" : (modelData === "=" ? "Compute result" : "Calculator key " + modelData)
                    ToolTip.text: modelData === "C" ? "Clear" : (modelData === "=" ? "Compute result" : "Insert " + modelData)
                    ToolTip.visible: hovered
                    onClicked: root.press(String(modelData))
                }
            }
        }
    }
}
