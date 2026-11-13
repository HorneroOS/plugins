import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Text Tools - dashboard card. Pure JS string transforms.
Item {
    id: root
    implicitWidth: 320
    implicitHeight: content.implicitHeight + 24
    property string mode: "Uppercase"
    function transformed() {
        var t = input.text;
        if (root.mode === "Uppercase") return t.toUpperCase();
        if (root.mode === "Lowercase") return t.toLowerCase();
        if (root.mode === "Reverse") { var s=""; for (var i=t.length-1;i>=0;i--) s+=t[i]; return s; }
        // Title Case
        var lower = t.toLowerCase(); var out = ""; var cap = true;
        for (var k = 0; k < lower.length; k++) { var ch = lower[k]; out += cap ? ch.toUpperCase() : ch; cap = (ch === " " || ch === "\t" || ch === "\n"); }
        return out;
    }
    function countWords() { var t=input.text.trim(); return t===""?0:t.split(/\s+/).length; }
    function countLines() { return input.text===""?0:input.text.split("\n").length; }
    Column {
        id: content
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        Text { color: Theme.onSurface; text: "Text Tools"; font.bold: true; font.pixelSize: 14 }
        TextArea {
            id: input; width: parent.width; height: 90; placeholderText: "Type or paste text..."
            wrapMode: TextArea.Wrap; Accessible.name: "Text input"
            ToolTip.text: "Text to transform"; ToolTip.visible: hovered
        }
        Text {
            width: parent.width; wrapMode: Text.Wrap; color: Theme.onSurfaceVariant; font.pixelSize: 12
            Accessible.name: "Counts"
            text: input.text.length + " characters, " + root.countWords() + " words, " + root.countLines() + " lines"
        }
        Row {
            spacing: 6
            Repeater {
                model: ["Uppercase","Lowercase","Title Case","Reverse"]
                delegate: Button {
                    required property var modelData
                    text: modelData; highlighted: root.mode===String(modelData)
                    Accessible.name: "Transform " + modelData
                    ToolTip.text: "Show " + modelData + " output"; ToolTip.visible: hovered
                    onClicked: root.mode = String(modelData)
                }
            }
        }
        Text {
            width: parent.width; color: Theme.onSurfaceVariant; font.pixelSize: 12; text: root.mode + " output:"
        }
        TextArea {
            id: output; width: parent.width; height: 80; readOnly: true; selectByMouse: true
            wrapMode: TextArea.Wrap; text: root.transformed()
            Accessible.name: "Transformed text output"
            ToolTip.text: "Transformed text (read-only, selectable)"; ToolTip.visible: hovered
        }
    }
}
