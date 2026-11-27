import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Toolbox: the everyday calculators in one Signal-styled dashboard card:
// Calculator, Units, Base, Colour, Dates, JSON and Text. It replaces seven
// single-purpose extensions (calculator, unit, base, colour and date
// converters, JSON and text tools) with one tabbed surface that shares one
// frame, one set of settings and one translation catalogue. Everything is
// pure local arithmetic: no process, no network, nothing stored except the
// settings you set. Results are computed as you type and an invalid input is
// said plainly, never guessed.
Item {
    id: root

    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Toolbox")
    readonly property string widgetContext: tabNames[tab].toUpperCase()
    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 380

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-toolbox"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-toolbox"
    }

    readonly property var toolIds: ["calculator", "units", "base", "colour", "dates", "json", "text"]
    readonly property var tabNames: [i18n.tr("Calculator"), i18n.tr("Units"), i18n.tr("Base"), i18n.tr("Colour"), i18n.tr("Dates"), i18n.tr("JSON"), i18n.tr("Text")]
    property int tab: Math.max(0, toolIds.indexOf(String(pluginSettings.value("defaultTool", "calculator"))))

    readonly property bool showKeypad: pluginSettings.value("showKeypad", true) !== false
    readonly property int precision: Math.max(0, Math.min(10, Number(pluginSettings.value("precision", 6)) || 0))
    readonly property bool uppercaseHex: pluginSettings.value("uppercaseHex", true) !== false
    readonly property int indentSpaces: Math.max(0, Math.min(8, Number(pluginSettings.value("indentSpaces", 2))))
    readonly property bool showCounts: pluginSettings.value("showCounts", true) !== false
    readonly property bool showUtcNote: pluginSettings.value("showUtcNote", true) !== false
    readonly property string defaultHex: String(pluginSettings.value("defaultHex", "#E8A33D"))
    readonly property string defaultCategory: String(pluginSettings.value("defaultCategory", "length"))
    readonly property string textMode: String(pluginSettings.value("defaultTextMode", "uppercase"))

    // TOOLBOX-LOGIC-BEGIN
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
    function calcText(input) {
        var outcome = calculate(String(input));
        if (!outcome.ok) return { "ok": false, "text": "" };
        return { "ok": true, "text": String(Math.round(outcome.value * 10000000000) / 10000000000) };
    }

    // Units: table driven. Each category has a base unit and a factor to it;
    // temperature is converted through Celsius.
    function unitTable() {
        return {
        "length": { "mm": 0.001, "cm": 0.01, "m": 1, "km": 1000, "in": 0.0254, "ft": 0.3048, "yd": 0.9144, "mi": 1609.344 },
        "mass": { "g": 0.001, "kg": 1, "oz": 0.028349523125, "lb": 0.45359237 },
        "data": { "B": 1, "kB": 1000, "MB": 1000000, "GB": 1000000000, "KiB": 1024, "MiB": 1048576, "GiB": 1073741824 },
        "temperature": { "C": 1, "F": 1, "K": 1 }
    };
    }
    function unitList(category) { return Object.keys(unitTable()[category] || {}); }
    function convertUnit(value, category, from, to) {
        var t = unitTable()[category];
        if (!t || t[from] === undefined || t[to] === undefined) return NaN;
        if (category === "temperature") {
            var c = from === "F" ? (value - 32) * 5 / 9 : from === "K" ? value - 273.15 : value;
            return to === "F" ? c * 9 / 5 + 32 : to === "K" ? c + 273.15 : c;
        }
        return value * t[from] / t[to];
    }
    function unitText(valueText, category, from, to, precision) {
        var s = String(valueText).trim();
        var value = Number(s);
        if (s === "" || !isFinite(value)) return { "ok": false, "text": "" };
        var result = convertUnit(value, category, from, to);
        if (!isFinite(result)) return { "ok": false, "text": "" };
        var factor = Math.pow(10, precision);
        return { "ok": true, "text": value + " " + from + " = " + (Math.round(result * factor) / factor) + " " + to };
    }

    function convertDecText(t, uppercaseHex) {
        var s = String(t).trim();
        if (!/^-?[0-9]+$/.test(s)) return { "ok": false, "text": "", "error": "dec" };
        var v = Number(s);
        if (!isFinite(v) || Math.abs(v) > Number.MAX_SAFE_INTEGER) return { "ok": false, "text": "", "error": "range" };
        var sign = v < 0 ? "-" : ""; var a = Math.abs(v);
        var hex = a.toString(16);
        if (uppercaseHex !== false) hex = hex.toUpperCase();
        return { "ok": true, "bin": sign + a.toString(2), "oct": sign + a.toString(8), "hex": sign + hex, "error": "" };
    }
    function convertHexText(t) {
        var s = String(t).trim().replace(/^(-?)0x/i, "$1");
        if (!/^-?[0-9A-Fa-f]+$/.test(s)) return { "ok": false, "dec": "", "error": "hex" };
        var neg = s[0] === "-"; var digits = neg ? s.substring(1) : s;
        var v = parseInt(digits, 16);
        if (!isFinite(v) || v > Number.MAX_SAFE_INTEGER) return { "ok": false, "dec": "", "error": "range" };
        return { "ok": true, "dec": String(neg ? -v : v), "error": "" };
    }

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
    // WCAG relative luminance and contrast ratio against black and white text.
    function luminance(r, g, b) {
        function ch(v) { var c = v / 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
        return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b);
    }
    function contrast(l1, l2) { var a = Math.max(l1, l2), b = Math.min(l1, l2); return (a + 0.05) / (b + 0.05); }

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
        if (!a || !b) return { "ok": false, "text": "" };
        return { "ok": true, "days": Math.round((b.getTime() - a.getTime()) / 86400000) };
    }
    function addDaysText(baseText, daysText) {
        var a = parseDate(baseText);
        var s = String(daysText).trim();
        var n = Number(s);
        if (!a || s === "" || !isFinite(n) || Math.floor(n) !== n) return { "ok": false, "text": "" };
        return { "ok": true, "text": fmtDate(new Date(a.getTime() + n * 86400000)) };
    }

    function formatJsonText(t, indent) {
        try { return { "ok": true, "text": JSON.stringify(JSON.parse(String(t)), null, indent), "error": "" }; }
        catch (e) { return { "ok": false, "text": "", "error": String(e) }; }
    }
    function minifyJsonText(t) {
        try { return { "ok": true, "text": JSON.stringify(JSON.parse(String(t))), "error": "" }; }
        catch (e) { return { "ok": false, "text": "", "error": String(e) }; }
    }

    function transformText(t, mode) {
        if (mode === "uppercase") return t.toUpperCase();
        if (mode === "lowercase") return t.toLowerCase();
        if (mode === "reverse") { var s = ""; for (var i = t.length - 1; i >= 0; i--) s += t[i]; return s; }
        var lower = t.toLowerCase(); var out = ""; var cap = true;
        for (var k = 0; k < lower.length; k++) { var ch = lower[k]; out += cap ? ch.toUpperCase() : ch; cap = (ch === " " || ch === "\t" || ch === "\n"); }
        return out;
    }
    function countWordsText(t) { var s = t.trim(); return s === "" ? 0 : s.split(/\s+/).length; }
    function countLinesText(t) { return t === "" ? 0 : t.split("\n").length; }
    // TOOLBOX-LOGIC-END

    // Calculator state
    function keyPress(k) {
        if (k === "C")
            calcInput.text = "";
        else if (k === "=") {
            const r = calcText(calcInput.text);
            if (r.ok)
                calcInput.text = r.text;
        } else
            calcInput.text += k;
    }

    function errorText(code) {
        return code === "range" ? i18n.tr("Out of safe range.") : code === "hex" ? i18n.tr("Hex digits only (0-9, A-F).") : i18n.tr("Digits only, optional minus.");
    }

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.small
        Accessible.name: i18n.tr("Toolbox")

        Flow {
            width: parent.width
            spacing: Theme.spacing.smaller

            Repeater {
                model: root.tabNames

                delegate: UiButton {
                    required property int index
                    required property string modelData

                    text: modelData
                    variant: index === root.tab ? "primary" : "quiet"
                    accessibleName: i18n.tr("%1 tool").arg(modelData)
                    tooltipText: i18n.tr("Show the %1 tool").arg(modelData)
                    onClicked: root.tab = index
                }
            }
        }

        // ---- Calculator
        Column {
            id: calcTab

            visible: root.tab === 0
            width: parent.width
            spacing: Theme.spacing.small

            UiTextField {
                id: calcInput

                width: parent.width
                mono: true
                placeholderText: i18n.tr("e.g. (2 + 3) * 4")
                accessibleName: i18n.tr("Expression")
                onAccepted: root.keyPress("=")
            }

            UiMetric {
                width: parent.width
                size: "display"
                label: i18n.tr("RESULT")
                value: root.calcText(calcInput.text).text
                available: root.calcText(calcInput.text).ok
            }

            UiText {
                visible: calcInput.text.length > 0 && !root.calcText(calcInput.text).ok
                width: parent.width
                role: "caption"
                text: i18n.tr("Not a valid expression yet.")
                color: Theme.palette.inkMuted
            }

            Grid {
                visible: root.showKeypad
                width: parent.width
                columns: 4
                spacing: Theme.spacing.smaller

                Repeater {
                    model: ["7", "8", "9", "/", "4", "5", "6", "*", "1", "2", "3", "-", "0", ".", "%", "+", "(", ")", "C", "="]

                    delegate: UiButton {
                        required property string modelData

                        width: (column.width - 3 * Theme.spacing.smaller) / 4
                        text: modelData
                        variant: modelData === "=" ? "primary" : "secondary"
                        accessibleName: i18n.tr("Key %1").arg(modelData)
                        onClicked: root.keyPress(modelData)
                    }
                }
            }
        }

        // ---- Units
        Column {
            id: unitTab

            visible: root.tab === 1
            width: parent.width
            spacing: Theme.spacing.small

            readonly property var categories: ["length", "mass", "data", "temperature"]
            readonly property string category: categories[catBox.currentIndex]
            readonly property var unitModel: root.unitList(category)
            property int fromIdx: 0
            property int toIdx: 1

            UiComboBox {
                id: catBox

                width: parent.width
                model: [i18n.tr("Length"), i18n.tr("Mass"), i18n.tr("Data size"), i18n.tr("Temperature")]
                currentIndex: Math.max(0, unitTab.categories.indexOf(root.defaultCategory))
                accessibleName: i18n.tr("Conversion category")
                onActivated: {
                    unitTab.fromIdx = 0;
                    unitTab.toIdx = 1;
                }
            }

            UiTextField {
                id: unitValue

                width: parent.width
                mono: true
                text: "1"
                placeholderText: i18n.tr("Value")
                accessibleName: i18n.tr("Value to convert")
            }

            Row {
                width: parent.width
                spacing: Theme.spacing.small

                UiComboBox {
                    id: fromBox

                    width: (parent.width - parent.spacing) / 2
                    model: unitTab.unitModel
                    currentIndex: unitTab.fromIdx
                    onActivated: unitTab.fromIdx = currentIndex
                    accessibleName: i18n.tr("From unit")
                }

                UiComboBox {
                    id: toBox

                    width: (parent.width - parent.spacing) / 2
                    model: unitTab.unitModel
                    currentIndex: unitTab.toIdx
                    onActivated: unitTab.toIdx = currentIndex
                    accessibleName: i18n.tr("To unit")
                }
            }

            UiMetric {
                width: parent.width
                size: "value"
                label: i18n.tr("RESULT")
                readonly property var r: root.unitText(unitValue.text, unitTab.category, unitTab.unitModel[unitTab.fromIdx], unitTab.unitModel[unitTab.toIdx], root.precision)
                value: r.text
                available: r.ok
            }
        }

        // ---- Base
        Column {
            id: baseTab

            visible: root.tab === 2
            width: parent.width
            spacing: Theme.spacing.small

            UiTextField {
                id: decField

                width: parent.width
                mono: true
                text: "255"
                placeholderText: i18n.tr("Decimal integer")
                accessibleName: i18n.tr("Decimal integer")
            }

            readonly property var dec: root.convertDecText(decField.text, root.uppercaseHex)

            UiStack {
                width: parent.width

                UiMetric {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    size: "value"
                    label: i18n.tr("BIN")
                    value: baseTab.dec.bin || ""
                    available: baseTab.dec.ok
                }

                UiMetric {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    size: "value"
                    label: i18n.tr("OCT")
                    value: baseTab.dec.oct || ""
                    available: baseTab.dec.ok
                }

                UiMetric {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    size: "value"
                    label: i18n.tr("HEX")
                    value: baseTab.dec.hex || ""
                    available: baseTab.dec.ok
                }
            }

            UiText {
                visible: !baseTab.dec.ok && decField.text.length > 0
                width: parent.width
                role: "caption"
                text: root.errorText(baseTab.dec.error)
                color: Theme.palette.alert
            }

            UiTextField {
                id: hexField

                width: parent.width
                mono: true
                text: "FF"
                placeholderText: i18n.tr("Hex, e.g. FF or 0xFF")
                accessibleName: i18n.tr("Hexadecimal value")
            }

            readonly property var hx: root.convertHexText(hexField.text)

            UiMetric {
                width: parent.width
                size: "value"
                label: i18n.tr("DECIMAL")
                value: baseTab.hx.dec || ""
                available: baseTab.hx.ok
            }

            UiText {
                visible: !baseTab.hx.ok && hexField.text.length > 0
                width: parent.width
                role: "caption"
                text: root.errorText(baseTab.hx.error)
                color: Theme.palette.alert
            }
        }

        // ---- Colour
        Column {
            id: colTab

            visible: root.tab === 3
            width: parent.width
            spacing: Theme.spacing.small

            UiTextField {
                id: hexColour

                width: parent.width
                mono: true
                text: root.defaultHex
                placeholderText: "#RRGGBB"
                accessibleName: i18n.tr("Hex colour")
            }

            readonly property var rgb: root.parseHex(hexColour.text)
            readonly property var hsl: rgb ? root.toHsl(rgb.r, rgb.g, rgb.b) : null
            readonly property real lum: rgb ? root.luminance(rgb.r, rgb.g, rgb.b) : 0

            Rectangle {
                width: parent.width
                height: 56
                radius: Theme.rounding.small
                border.width: 1
                border.color: Theme.palette.ruleStrong
                color: colTab.rgb ? Qt.rgba(colTab.rgb.r / 255, colTab.rgb.g / 255, colTab.rgb.b / 255, 1) : Theme.palette.sunken

                UiText {
                    anchors.centerIn: parent
                    visible: !colTab.rgb
                    role: "caption"
                    text: i18n.tr("Use #RGB or #RRGGBB.")
                }
            }

            UiDetailRow {
                width: parent.width
                label: "RGB"
                value: colTab.rgb ? colTab.rgb.r + ", " + colTab.rgb.g + ", " + colTab.rgb.b : ""
                available: !!colTab.rgb
            }

            UiDetailRow {
                width: parent.width
                label: "HSL"
                value: colTab.hsl ? colTab.hsl.h + ", " + colTab.hsl.s + "%, " + colTab.hsl.l + "%" : ""
                available: !!colTab.hsl
            }

            UiDetailRow {
                width: parent.width
                label: i18n.tr("Contrast on white")
                value: colTab.rgb ? root.contrast(1, colTab.lum).toFixed(2) + " : 1" : ""
                available: !!colTab.rgb
            }

            UiDetailRow {
                width: parent.width
                label: i18n.tr("Contrast on black")
                value: colTab.rgb ? root.contrast(0, colTab.lum).toFixed(2) + " : 1" : ""
                available: !!colTab.rgb
            }
        }

        // ---- Dates
        Column {
            id: dateTab

            visible: root.tab === 4
            width: parent.width
            spacing: Theme.spacing.small

            UiText {
                width: parent.width
                role: "eyebrow"
                text: i18n.tr("DAYS BETWEEN")
            }

            Row {
                width: parent.width
                spacing: Theme.spacing.small

                UiTextField {
                    id: dateA

                    width: (parent.width - parent.spacing) / 2
                    mono: true
                    placeholderText: "YYYY-MM-DD"
                    text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                    accessibleName: i18n.tr("Start date")
                }

                UiTextField {
                    id: dateB

                    width: (parent.width - parent.spacing) / 2
                    mono: true
                    placeholderText: "YYYY-MM-DD"
                    accessibleName: i18n.tr("End date")
                }
            }

            readonly property var span: root.daysBetweenText(dateA.text, dateB.text)

            UiMetric {
                width: parent.width
                size: "value"
                label: i18n.tr("DAYS")
                value: dateTab.span.ok ? String(dateTab.span.days) : ""
                available: dateTab.span.ok
            }

            UiText {
                width: parent.width
                role: "eyebrow"
                text: i18n.tr("ADD DAYS")
            }

            Row {
                width: parent.width
                spacing: Theme.spacing.small

                UiTextField {
                    id: dateBase

                    width: (parent.width - parent.spacing) * 0.6
                    mono: true
                    placeholderText: "YYYY-MM-DD"
                    text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                    accessibleName: i18n.tr("Base date")
                }

                UiTextField {
                    id: dateDays

                    width: (parent.width - parent.spacing) * 0.4
                    mono: true
                    placeholderText: i18n.tr("days")
                    text: "30"
                    accessibleName: i18n.tr("Days to add")
                }
            }

            readonly property var added: root.addDaysText(dateBase.text, dateDays.text)

            UiMetric {
                width: parent.width
                size: "value"
                label: i18n.tr("RESULT")
                value: dateTab.added.ok ? dateTab.added.text : ""
                available: dateTab.added.ok
            }

            UiText {
                visible: root.showUtcNote
                width: parent.width
                role: "caption"
                text: i18n.tr("Real calendar dates only; the arithmetic uses UTC so daylight saving never shifts a result.")
                wrapMode: Text.WordWrap
                color: Theme.palette.inkMuted
            }
        }

        // ---- JSON
        Column {
            id: jsonTab

            visible: root.tab === 5
            width: parent.width
            spacing: Theme.spacing.small

            UiTextArea {
                id: jsonIn

                width: parent.width
                height: 96
                mono: true
                placeholderText: "{\"key\": 1}"
                accessibleName: i18n.tr("JSON input")
            }

            property var outcome: ({
                    "ok": true,
                    "text": "",
                    "error": ""
                })

            Row {
                spacing: Theme.spacing.small

                UiButton {
                    text: i18n.tr("Format")
                    variant: "primary"
                    accessibleName: i18n.tr("Format JSON")
                    onClicked: jsonTab.outcome = root.formatJsonText(jsonIn.text, root.indentSpaces)
                }

                UiButton {
                    text: i18n.tr("Minify")
                    accessibleName: i18n.tr("Minify JSON")
                    onClicked: jsonTab.outcome = root.minifyJsonText(jsonIn.text)
                }
            }

            UiText {
                visible: !jsonTab.outcome.ok
                width: parent.width
                role: "caption"
                wrapMode: Text.WordWrap
                text: jsonTab.outcome.error
                color: Theme.palette.alert
            }

            UiTextArea {
                width: parent.width
                height: 96
                mono: true
                readOnly: true
                text: jsonTab.outcome.text
                placeholderText: i18n.tr("Output")
                accessibleName: i18n.tr("JSON output")
            }
        }

        // ---- Text
        Column {
            id: textTab

            visible: root.tab === 6
            width: parent.width
            spacing: Theme.spacing.small

            UiTextArea {
                id: textIn

                width: parent.width
                height: 80
                placeholderText: i18n.tr("Type or paste text…")
                accessibleName: i18n.tr("Text input")
            }

            property string mode: root.textMode

            Flow {
                width: parent.width
                spacing: Theme.spacing.smaller

                Repeater {
                    model: ["uppercase", "lowercase", "title-case", "reverse"]

                    delegate: UiButton {
                        required property string modelData

                        text: modelData === "uppercase" ? i18n.tr("Uppercase") : modelData === "lowercase" ? i18n.tr("Lowercase") : modelData === "title-case" ? i18n.tr("Title Case") : i18n.tr("Reverse")
                        variant: modelData === textTab.mode ? "primary" : "quiet"
                        accessibleName: text
                        onClicked: textTab.mode = modelData
                    }
                }
            }

            UiTextArea {
                width: parent.width
                height: 80
                readOnly: true
                text: root.transformText(textIn.text, textTab.mode)
                placeholderText: i18n.tr("Output")
                accessibleName: i18n.tr("Text output")
            }

            UiText {
                visible: root.showCounts
                width: parent.width
                role: "caption"
                text: i18n.tr("%1 characters, %2 words, %3 lines").arg(textIn.text.length).arg(root.countWordsText(textIn.text)).arg(root.countLinesText(textIn.text))
                color: Theme.palette.inkMuted
            }
        }
    }
}
