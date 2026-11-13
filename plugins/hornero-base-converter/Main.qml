import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Base Converter - decimal <-> binary/octal/hex, pure JS.
Item {
    id: root
    implicitWidth: 320
    implicitHeight: content.implicitHeight + 24
    property string decError: ""
    property string decResult: ""
    property string hexError: ""
    property string hexResult: ""
    function convertDec() {
        var t = decInput.text.trim();
        if (!/^-?[0-9]+$/.test(t)) { root.decError="Enter a decimal integer (digits only, optional minus)."; root.decResult=""; return; }
        var v = Number(t);
        if (!isFinite(v) || Math.abs(v) > Number.MAX_SAFE_INTEGER) { root.decError="Out of safe range (max Number.MAX_SAFE_INTEGER)."; root.decResult=""; return; }
        root.decError="";
        var sign = v<0 ? "-" : ""; var a = Math.abs(v);
        root.decResult = "Binary: " + sign + a.toString(2) + "\nOctal: " + sign + a.toString(8) + "\nHex: " + sign + a.toString(16).toUpperCase();
    }
    function convertHex() {
        var t = hexInput.text.trim();
        if (!/^-?[0-9A-Fa-f]+$/.test(t)) { root.hexError="Enter hex digits (0-9, A-F, optional minus) only."; root.hexResult=""; return; }
        var neg = t[0]==="-"; var digits = neg ? t.substring(1) : t;
        var v = parseInt(digits, 16);
        if (!isFinite(v) || v > Number.MAX_SAFE_INTEGER) { root.hexError="Out of safe range (max Number.MAX_SAFE_INTEGER)."; root.hexResult=""; return; }
        root.hexError=""; root.hexResult = "Decimal: " + (neg ? -v : v);
    }
    Column {
        id: content
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        Text { color: Theme.onSurface; text: "Base Converter"; font.bold: true; font.pixelSize: 14 }
        TextField {
            id: decInput; width: parent.width; placeholderText: "Decimal integer"
            Accessible.name: "Decimal input"
            ToolTip.text: "Decimal integer within safe range"; ToolTip.visible: hovered
            onAccepted: root.convertDec()
        }
        Button { text: "Convert decimal"; Accessible.name: "Convert decimal"; ToolTip.text: "Convert decimal to binary, octal and hex"; ToolTip.visible: hovered; onClicked: root.convertDec() }
        Text { visible: root.decError!==""; width: parent.width; wrapMode: Text.Wrap; color: Theme.error; font.pixelSize: 12; Accessible.name: "Decimal error"; text: root.decError }
        Text { visible: root.decResult!==""; width: parent.width; wrapMode: Text.Wrap; color: Theme.onSurface; font.pixelSize: 13; Accessible.name: "Decimal conversion result"; text: root.decResult }
        TextField {
            id: hexInput; width: parent.width; placeholderText: "Hex, e.g. FF"
            Accessible.name: "Hexadecimal input"
            ToolTip.text: "Hexadecimal digits to convert to decimal"; ToolTip.visible: hovered
            onAccepted: root.convertHex()
        }
        Button { text: "Convert hex"; Accessible.name: "Convert hexadecimal"; ToolTip.text: "Convert hex to decimal"; ToolTip.visible: hovered; onClicked: root.convertHex() }
        Text { visible: root.hexError!==""; width: parent.width; wrapMode: Text.Wrap; color: Theme.error; font.pixelSize: 12; Accessible.name: "Hex error"; text: root.hexError }
        Text { visible: root.hexResult!==""; width: parent.width; wrapMode: Text.Wrap; color: Theme.onSurface; font.pixelSize: 13; Accessible.name: "Hex conversion result"; text: root.hexResult }
    }
}
