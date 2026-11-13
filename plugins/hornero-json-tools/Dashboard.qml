import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// JSON Tools 2.0 dashboard surface: the optional detailed panel
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
    property string errorText: ""
    function showOutcome(outcome) { output.text = outcome.ok ? outcome.text : ""; root.errorText = outcome.ok ? "" : outcome.error; }
    function formatJson() { root.showOutcome(formatJsonText(input.text, root.indentSpaces)); }
    function minifyJson() { root.showOutcome(minifyJsonText(input.text)); }

    UiCard {
        id: card
        anchors.fill: parent
        Accessible.name: i18n.tr("JSON Tools")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("JSON Tools") }

            TextArea {
                id: input; width: parent.width; height: 90; placeholderText: "{\"key\": 1}"
                wrapMode: TextArea.Wrap; Accessible.name: i18n.tr("JSON input")
                ToolTip.text: i18n.tr("JSON to format or minify"); ToolTip.visible: hovered
            }
            UiStack {
                orientation: root.hostOrientation; compact: root.hostCompact
                UiButton { text: i18n.tr("Format"); accessibleName: i18n.tr("Format JSON"); tooltipText: i18n.tr("Format JSON"); onClicked: root.formatJson() }
                UiButton { variant: "ghost"; text: i18n.tr("Minify"); accessibleName: i18n.tr("Minify JSON"); tooltipText: i18n.tr("Minify JSON"); onClicked: root.minifyJson() }
            }
            UiState { visible: root.errorText !== ""; width: parent.width; kind: "error"; message: root.errorText }
            TextArea {
                id: output; width: parent.width; height: 90; readOnly: true; selectByMouse: true
                wrapMode: TextArea.Wrap; placeholderText: i18n.tr("Output")
                Accessible.name: i18n.tr("JSON output")
                ToolTip.text: i18n.tr("JSON output (read-only, selectable)"); ToolTip.visible: hovered
            }
        }
    }
}
