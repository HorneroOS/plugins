import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Text Tools 2.0 bar surface (primary): a one-button quick action.
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

    Translations { id: i18n; pluginId: "hornero-text-tools" }
    Settings { id: pluginSettings; pluginId: "hornero-text-tools" }

    readonly property string defaultMode: String(pluginSettings.value("defaultMode", "uppercase"))
    readonly property bool showCounts: pluginSettings.value("showCounts", true) !== false

    // LOGIC-BEGIN
    function transformText(t, mode) {
        if (mode === "Uppercase") return t.toUpperCase();
        if (mode === "Lowercase") return t.toLowerCase();
        if (mode === "Reverse") { var s = ""; for (var i = t.length - 1; i >= 0; i--) s += t[i]; return s; }
        var lower = t.toLowerCase(); var out = ""; var cap = true;
        for (var k = 0; k < lower.length; k++) { var ch = lower[k]; out += cap ? ch.toUpperCase() : ch; cap = (ch === " " || ch === "\t" || ch === "\n"); }
        return out;
    }
    function countWordsText(t) { var s = t.trim(); return s === "" ? 0 : s.split(/\s+/).length; }
    function countLinesText(t) { return t === "" ? 0 : t.split("\n").length; }
    function modeFromSetting(key) {
        if (key === "lowercase") return "Lowercase";
        if (key === "title-case") return "Title Case";
        if (key === "reverse") return "Reverse";
        return "Uppercase";
    }
    function quickResult(query, modeKey) {
        var t = String(query);
        return { "ok": true, "text": transformText(t, modeFromSetting(modeKey)), "characters": t.length, "words": countWordsText(t), "lines": countLinesText(t) };
    }
    // LOGIC-END

    function runQuick() {
        var outcome = quickResult(quickInput.text, root.defaultMode);
        root.quickText = outcome.ok ? outcome.text : (outcome.error && outcome.error !== "" ? outcome.error : outcome.text);
    }

    UiStack {
        id: stack
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator
            variant: "ghost"
            text: "Aa"
            tooltipText: i18n.tr("Text Tools: activate for a quick transform")
            accessibleName: i18n.tr("Text Tools quick action")
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
        accessibleName: i18n.tr("Text Tools quick action")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Text Tools") }

            TextField {
                id: quickInput
                width: parent.width
                placeholderText: i18n.tr("Text to transform")
                Accessible.name: i18n.tr("Quick text to transform")
                ToolTip.text: i18n.tr("Quick text to transform")
                ToolTip.visible: hovered
                onAccepted: root.runQuick()
            }

            UiButton {
                text: i18n.tr("Transform")
                tooltipText: i18n.tr("Transform")
                accessibleName: i18n.tr("Transform")
                onClicked: root.runQuick()
            }

            UiState {
                visible: root.quickText === ""
                width: parent.width
                kind: "empty"
                message: i18n.tr("Type text and press Transform.")
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
