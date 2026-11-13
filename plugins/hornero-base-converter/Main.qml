import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Base Converter 2.0 bar surface (primary): a one-button quick action.
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

    function runQuick() {
        var outcome = quickResult(quickInput.text, root.uppercaseHex);
        root.quickText = outcome.ok ? outcome.text : (outcome.error && outcome.error !== "" ? outcome.error : outcome.text);
    }

    UiStack {
        id: stack
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator
            variant: "ghost"
            text: "01"
            tooltipText: i18n.tr("Base Converter: activate for a quick conversion")
            accessibleName: i18n.tr("Base Converter quick action")
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
        accessibleName: i18n.tr("Base Converter quick action")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Base Converter") }

            TextField {
                id: quickInput
                width: parent.width
                placeholderText: i18n.tr("255 or 0xFF")
                Accessible.name: i18n.tr("Quick base conversion")
                ToolTip.text: i18n.tr("Quick base conversion")
                ToolTip.visible: hovered
                onAccepted: root.runQuick()
            }

            UiButton {
                text: i18n.tr("Convert")
                tooltipText: i18n.tr("Convert")
                accessibleName: i18n.tr("Convert")
                onClicked: root.runQuick()
            }

            UiState {
                visible: root.quickText === ""
                width: parent.width
                kind: "empty"
                message: i18n.tr("Type a decimal integer or a 0x-prefixed hex value and press Convert.")
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
