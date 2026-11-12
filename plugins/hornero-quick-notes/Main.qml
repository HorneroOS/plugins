import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Quick Notes - dashboard card with one persistent note.
// Stored via PluginKit Settings (declared string setting "note").
// Loaded on completion, saved debounced (600 ms) after edits,
// never saves more than 4096 characters.
Item {
    id: root

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    property bool truncated: false

    Settings {
        id: pluginSettings
        pluginId: "hornero-quick-notes"
    }

    function saveNote() {
        var text = noteArea.text;
        if (text.length > 4096) {
            text = text.substring(0, 4096);
            root.truncated = true;
        } else {
            root.truncated = false;
        }
        pluginSettings.setValue("note", text);
    }

    Component.onCompleted: {
        var stored = pluginSettings.value("note", "");
        noteArea.text = stored ? String(stored) : "";
    }

    Timer {
        id: saveTimer
        interval: 600
        repeat: false
        onTriggered: root.saveNote()
    }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            color: Theme.onSurface
            text: "Quick Notes"
            font.bold: true
            font.pixelSize: 14
        }

        TextArea {
            id: noteArea
            width: parent.width
            height: 110
            placeholderText: "Write a note..."
            wrapMode: TextArea.Wrap
            color: Theme.onSurface
            Accessible.name: "Quick note"
            ToolTip.text: "Quick note (saved automatically)"
            ToolTip.visible: hovered
            onTextChanged: saveTimer.restart()
        }

        Text {
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
            Accessible.name: "Character count " + noteArea.text.length + " of 4096"
            text: noteArea.text.length + " / 4096 characters"
        }

        Text {
            visible: root.truncated
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.error
            font.pixelSize: 11
            text: "Note truncated to 4096 characters; only the first 4096 were saved."
        }

        Text {
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
            text: "Saved automatically via Settings."
        }
    }
}
