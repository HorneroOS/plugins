import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// JSON Tools 2.0 bar surface (primary): a one-button quick action.
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

    Translations { id: i18n; pluginId: "hornero-json-tools" }
    Settings { id: pluginSettings; pluginId: "hornero-json-tools" }

    readonly property int indentSpaces: { const v = Number(pluginSettings.value("indentSpaces", 2)); return isFinite(v) && v >= 0 && v <= 8 ? Math.floor(v) : 2; }
    readonly property string defaultAction: String(pluginSettings.value("defaultAction", "format"))

    // LOGIC-BEGIN
    function formatJsonText(t, indent) {
        try { return { "ok": true, "text": JSON.stringify(JSON.parse(String(t)), null, indent), "error": "" }; }
        catch (e) { return { "ok": false, "text": "", "error": String(e) }; }
    }
    function minifyJsonText(t) {
        try { return { "ok": true, "text": JSON.stringify(JSON.parse(String(t))), "error": "" }; }
        catch (e) { return { "ok": false, "text": "", "error": String(e) }; }
    }
    function quickResult(query, indent, action) {
        var n = (indent === undefined || indent === null) ? 2 : indent;
        return action === "minify" ? minifyJsonText(query) : formatJsonText(query, n);
    }
    // LOGIC-END

    function runQuick() {
        var outcome = quickResult(quickInput.text, root.indentSpaces, root.defaultAction);
        root.quickText = outcome.ok ? outcome.text : (outcome.error && outcome.error !== "" ? outcome.error : outcome.text);
    }

    UiStack {
        id: stack
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator
            variant: "ghost"
            text: "{}"
            tooltipText: i18n.tr("JSON Tools: activate for a quick format check")
            accessibleName: i18n.tr("JSON Tools quick action")
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
        accessibleName: i18n.tr("JSON Tools quick action")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("JSON Tools") }

            TextField {
                id: quickInput
                width: parent.width
                placeholderText: i18n.tr("JSON to format")
                Accessible.name: i18n.tr("Quick JSON input")
                ToolTip.text: i18n.tr("Quick JSON input")
                ToolTip.visible: hovered
                onAccepted: root.runQuick()
            }

            UiButton {
                text: i18n.tr("Run")
                tooltipText: i18n.tr("Run")
                accessibleName: i18n.tr("Run")
                onClicked: root.runQuick()
            }

            UiState {
                visible: root.quickText === ""
                width: parent.width
                kind: "empty"
                message: i18n.tr("Paste JSON and press Run.")
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
