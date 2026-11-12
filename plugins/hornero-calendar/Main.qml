import QtQuick
import Hornero.PluginKit

// Hornero Calendar - desktop widget over PluginKit Time.
Item {
    id: root

    implicitWidth: content.implicitWidth + 24
    implicitHeight: content.implicitHeight + 24

    Column {
        id: content

        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurface
            font.pixelSize: 28
            font.bold: true
            text: Time.format("HH:mm")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurface
            font.pixelSize: 14
            text: Qt.formatDateTime(Time.date, "dddd, d MMMM yyyy")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
            text: Time.timeStr
        }
    }
}
