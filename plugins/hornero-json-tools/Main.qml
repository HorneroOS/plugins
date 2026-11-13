import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero JSON Tools - Format/Minify via JSON.parse/stringify only.
Item {
    id: root
    implicitWidth: 320
    implicitHeight: content.implicitHeight + 24
    property string errorText: ""
    function formatJson() {
        try { output.text = JSON.stringify(JSON.parse(input.text), null, 2); root.errorText=""; }
        catch (e) { root.errorText = String(e); output.text=""; }
    }
    function minifyJson() {
        try { output.text = JSON.stringify(JSON.parse(input.text)); root.errorText=""; }
        catch (e) { root.errorText = String(e); output.text=""; }
    }
    Column {
        id: content
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        Text { color: Theme.onSurface; text: "JSON Tools"; font.bold: true; font.pixelSize: 14 }
        TextArea {
            id: input; width: parent.width; height: 90; placeholderText: "{\"key\": 1}"
            wrapMode: TextArea.Wrap; Accessible.name: "JSON input"
            ToolTip.text: "JSON to format or minify"; ToolTip.visible: hovered
        }
        Row {
            spacing: 6
            Button { text: "Format"; Accessible.name: "Format JSON"; ToolTip.text: "Format with 2-space indentation"; ToolTip.visible: hovered; onClicked: root.formatJson() }
            Button { text: "Minify"; Accessible.name: "Minify JSON"; ToolTip.text: "Minify JSON"; ToolTip.visible: hovered; onClicked: root.minifyJson() }
        }
        Text {
            visible: root.errorText!==""; width: parent.width; wrapMode: Text.Wrap
            color: Theme.error; font.pixelSize: 12; Accessible.name: "JSON error"; text: root.errorText
        }
        TextArea {
            id: output; width: parent.width; height: 90; readOnly: true; selectByMouse: true
            wrapMode: TextArea.Wrap; placeholderText: "Output"
            Accessible.name: "JSON output"
            ToolTip.text: "JSON output (read-only, selectable)"; ToolTip.visible: hovered
        }
    }
}
