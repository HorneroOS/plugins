import QtQuick

// Starter plugin: shows HH:mm, updates every 30 seconds.
Item {
    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 8

    Text {
        id: label

        anchors.centerIn: parent
        text: Qt.formatDateTime(new Date(), "HH:mm")

        Timer {
            interval: 30000
            repeat: true
            running: true
            onTriggered: label.text = Qt.formatDateTime(new Date(), "HH:mm")
        }
    }
}
