import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Color Converter 2.0 dashboard surface: the optional detailed panel
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

    Translations { id: i18n; pluginId: "hornero-color-converter" }
    Settings { id: pluginSettings; pluginId: "hornero-color-converter" }

    readonly property string defaultHex: String(pluginSettings.value("defaultHex", "#336699"))
    readonly property bool showPreview: pluginSettings.value("showPreview", true) !== false
    // LOGIC-BEGIN
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
    function quickResult(query) {
        var c = parseHex(query);
        if (!c) return { "ok": false, "text": "Invalid hex: use #RGB or #RRGGBB with hex digits." };
        var hsl = toHsl(c.r, c.g, c.b);
        return { "ok": true, "text": "RGB: " + c.r + ", " + c.g + ", " + c.b + "\nHSL: " + hsl.h + ", " + hsl.s + "%, " + hsl.l + "%", "r": c.r, "g": c.g, "b": c.b };
    }
    // LOGIC-END
    property string errorText: ""
    property var rgb: null
    function applyHex() {
        var c = parseHex(hexInput.text);
        if (!c) { root.rgb = null; root.errorText = i18n.tr("Invalid hex: use #RGB or #RRGGBB with hex digits."); return; }
        root.errorText = ""; root.rgb = c; rSpin.value = c.r; gSpin.value = c.g; bSpin.value = c.b;
    }
    function applyRgb() {
        root.rgb = { "r": rSpin.value, "g": gSpin.value, "b": bSpin.value }; root.errorText = "";
        hexInput.text = toHex(rSpin.value, gSpin.value, bSpin.value);
    }

    UiCard {
        id: card
        anchors.fill: parent
        Accessible.name: i18n.tr("Color Converter")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Color Converter") }

            TextField {
                id: hexInput; width: parent.width; text: root.defaultHex; placeholderText: "#RGB or #RRGGBB"
                Accessible.name: i18n.tr("Hex color input")
                ToolTip.text: i18n.tr("Hex color, #RGB or #RRGGBB"); ToolTip.visible: hovered
                onAccepted: root.applyHex()
            }
            UiButton { text: i18n.tr("Convert hex"); accessibleName: i18n.tr("Convert hex color"); tooltipText: i18n.tr("Convert hex to RGB and HSL"); onClicked: root.applyHex() }
            Rectangle {
                width: parent.width; height: 36; radius: Theme.roundingSmall
                color: root.rgb ? toHex(root.rgb.r, root.rgb.g, root.rgb.b) : "transparent"
                border.color: Theme.outline; visible: root.showPreview && root.rgb !== null
                Accessible.name: i18n.tr("Color preview")
            }
            UiText {
                width: parent.width; Accessible.name: i18n.tr("RGB and HSL output")
                text: root.rgb ? quickResult(toHex(root.rgb.r, root.rgb.g, root.rgb.b)).text : i18n.tr("No valid color yet")
            }
            UiState { visible: root.errorText !== ""; width: parent.width; kind: "error"; message: root.errorText }
            Row {
                spacing: 6
                SpinBox { id: rSpin; from: 0; to: 255; value: 51; editable: true; Accessible.name: i18n.tr("Red value"); ToolTip.text: i18n.tr("Red 0-255"); ToolTip.visible: hovered; onValueModified: root.applyRgb() }
                SpinBox { id: gSpin; from: 0; to: 255; value: 102; editable: true; Accessible.name: i18n.tr("Green value"); ToolTip.text: i18n.tr("Green 0-255"); ToolTip.visible: hovered; onValueModified: root.applyRgb() }
                SpinBox { id: bSpin; from: 0; to: 255; value: 153; editable: true; Accessible.name: i18n.tr("Blue value"); ToolTip.text: i18n.tr("Blue 0-255"); ToolTip.visible: hovered; onValueModified: root.applyRgb() }
            }
            UiText { width: parent.width; role: "caption"; Accessible.name: i18n.tr("Hex from RGB output"); text: i18n.tr("Hex from RGB:") + " " + toHex(rSpin.value, gSpin.value, bSpin.value) }
            Component.onCompleted: root.applyHex()
        }
    }
}
