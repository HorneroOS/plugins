import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Base Converter 2.0 dashboard surface: the optional detailed panel
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

    Translations { id: i18n; pluginId: "hornero-base-converter" }
    Settings { id: pluginSettings; pluginId: "hornero-base-converter" }

    readonly property bool uppercaseHex: pluginSettings.value("uppercaseHex", true) !== false
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
    property string decError: ""
    property string decResult: ""
    property string hexError: ""
    property string hexResult: ""
    function convertDec() { var o = convertDecText(decInput.text, root.uppercaseHex); root.decError = o.error; root.decResult = o.text; }
    function convertHex() { var o = convertHexText(hexInput.text); root.hexError = o.error; root.hexResult = o.text; }

    UiCard {
        id: card
        anchors.fill: parent
        Accessible.name: i18n.tr("Base Converter")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Base Converter") }

            TextField { id: decInput; width: parent.width; placeholderText: i18n.tr("Decimal integer"); Accessible.name: i18n.tr("Decimal input"); ToolTip.text: i18n.tr("Decimal integer within safe range"); ToolTip.visible: hovered; onAccepted: root.convertDec() }
            UiButton { text: i18n.tr("Convert decimal"); accessibleName: i18n.tr("Convert decimal"); tooltipText: i18n.tr("Convert decimal to binary, octal and hex"); onClicked: root.convertDec() }
            UiState { visible: root.decError !== ""; width: parent.width; kind: "error"; message: root.decError }
            UiText { visible: root.decResult !== ""; width: parent.width; Accessible.name: i18n.tr("Decimal conversion result"); text: root.decResult }
            TextField { id: hexInput; width: parent.width; placeholderText: "Hex, e.g. FF"; Accessible.name: i18n.tr("Hexadecimal input"); ToolTip.text: i18n.tr("Hexadecimal digits to convert to decimal"); ToolTip.visible: hovered; onAccepted: root.convertHex() }
            UiButton { variant: "ghost"; text: i18n.tr("Convert hex"); accessibleName: i18n.tr("Convert hexadecimal"); tooltipText: i18n.tr("Convert hex to decimal"); onClicked: root.convertHex() }
            UiState { visible: root.hexError !== ""; width: parent.width; kind: "error"; message: root.hexError }
            UiText { visible: root.hexResult !== ""; width: parent.width; Accessible.name: i18n.tr("Hex conversion result"); text: root.hexResult }
        }
    }
}
