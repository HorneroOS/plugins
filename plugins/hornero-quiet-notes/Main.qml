import QtQuick

// Hornero Quiet Notes — a dashboard card for one short intention
// for this session. In-memory only: no files, no processes, no
// network, no history. When the shell closes, the note is gone.
Item {
    id: root

    property string note: ""

    implicitWidth: 280
    implicitHeight: 132

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "Session intention"
            font.bold: true
        }

        Text {
            width: parent.width
            text: root.note.length > 0 ? root.note : "Click to write one line for this session. It is never saved."
            wrapMode: Text.Wrap
            opacity: root.note.length > 0 ? 1.0 : 0.7
            font.italic: root.note.length === 0
        }

        Text {
            visible: root.note.length > 0
            text: "Session only — closing the shell erases this."
            font.pixelSize: 11
            opacity: 0.6
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: editor.open()
    }

    // A tiny inline editor: the card itself becomes the input.
    Rectangle {
        id: editor

        anchors.fill: parent
        visible: false
        color: "#1d1b26"
        radius: 8

        function open() {
            input.text = root.note;
            editor.visible = true;
            input.forceActiveFocus();
            input.selectAll();
        }

        function close(save) {
            if (save)
                root.note = input.text.trim();
            editor.visible = false;
        }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            TextInput {
                id: input

                width: parent.width
                color: "#f2eefc"
                font.pixelSize: 14
                maximumLength: 140
                onAccepted: editor.close(true)
                Keys.onEscapePressed: editor.close(false)
            }

            Text {
                text: "Enter saves · Esc cancels · 140 characters, this session only"
                color: "#9a93ad"
                font.pixelSize: 11
            }
        }
    }
}
