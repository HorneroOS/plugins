import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Text Tools 2.0 dashboard surface: the optional detailed panel
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
    property string mode: modeFromSetting(defaultMode)
    function transformed() { return transformText(input.text, root.mode); }
    function countWords() { return countWordsText(input.text); }
    function countLines() { return countLinesText(input.text); }

    UiCard {
        id: card
        anchors.fill: parent
        Accessible.name: i18n.tr("Text Tools")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Text Tools") }

            TextArea {
                id: input; width: parent.width; height: 90; placeholderText: i18n.tr("Type or paste text...")
                wrapMode: TextArea.Wrap; Accessible.name: i18n.tr("Text input")
                ToolTip.text: i18n.tr("Text to transform"); ToolTip.visible: hovered
            }
            UiText {
                visible: root.showCounts
                width: parent.width; role: "caption"; Accessible.name: i18n.tr("Counts")
                text: input.text.length + " " + i18n.tr("characters") + ", " + root.countWords() + " " + i18n.tr("words") + ", " + root.countLines() + " " + i18n.tr("lines")
            }
            UiStack {
                orientation: root.hostOrientation; compact: root.hostCompact
                Repeater {
                    model: ["Uppercase", "Lowercase", "Title Case", "Reverse"]
                    delegate: UiButton {
                        required property var modelData
                        variant: root.mode === String(modelData) ? "primary" : "ghost"
                        text: modelData
                        accessibleName: i18n.tr("Transform") + " " + modelData
                        tooltipText: i18n.tr("Show transformed output")
                        onClicked: root.mode = String(modelData)
                    }
                }
            }
            UiText { width: parent.width; role: "caption"; text: root.mode + " " + i18n.tr("output:") }
            TextArea {
                id: output; width: parent.width; height: 80; readOnly: true; selectByMouse: true
                wrapMode: TextArea.Wrap; text: root.transformed()
                Accessible.name: i18n.tr("Transformed text output")
                ToolTip.text: i18n.tr("Transformed text (read-only, selectable)"); ToolTip.visible: hovered
            }
        }
    }
}
