import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Color Converter 2.0 bar surface (primary): a one-button quick action.
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
            text: "#"
            tooltipText: i18n.tr("Color Converter: activate for a quick hex conversion")
            accessibleName: i18n.tr("Color Converter quick action")
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
        accessibleName: i18n.tr("Color Converter quick action")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Color Converter") }

            TextField {
                id: quickInput
                width: parent.width
                placeholderText: i18n.tr("#RGB or #RRGGBB")
                Accessible.name: i18n.tr("Quick hex color")
                ToolTip.text: i18n.tr("Quick hex color")
                ToolTip.visible: hovered
                onAccepted: root.runQuick()
            }

            UiButton {
                text: i18n.tr("Convert hex")
                tooltipText: i18n.tr("Convert hex")
                accessibleName: i18n.tr("Convert hex")
                onClicked: root.runQuick()
            }

            UiState {
                visible: root.quickText === ""
                width: parent.width
                kind: "empty"
                message: i18n.tr("Type a hex color like #336699 and press Convert hex.")
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
