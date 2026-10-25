import QtQuick

// Hornero Focus Card — dashboard card: date plus a rotating
// one-line focus reminder (original lines, written for HorneroOS).
Item {
    id: root

    property int lineIndex: 0
    readonly property var lines: [
        "El futuro se construye acá.",
        "One thing at a time, done well.",
        "Build the nest before the storm.",
        "Small commits, honest releases.",
        "Measure twice, ship once."
    ]

    implicitWidth: 260
    implicitHeight: 96

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.lineIndex = (root.lineIndex + 1) % root.lines.length
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Text {
            color: palette.windowText
            text: Qt.formatDateTime(new Date(), "dddd d 'de' MMMM")
            font.bold: true
        }

        Text {
            color: palette.windowText
            width: parent.width
            text: root.lines[root.lineIndex]
            wrapMode: Text.Wrap
            opacity: 0.85
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.lineIndex = (root.lineIndex + 1) % root.lines.length
    }
}
