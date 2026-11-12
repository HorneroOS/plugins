import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Now Playing - bar widget over PluginKit Media.
// Transport functions are called only from button clicks.
Item {
    id: root

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 34

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                color: Theme.onSurface
                width: 180
                elide: Text.ElideRight
                font.pixelSize: 11
                font.bold: true
                text: Media.hasPlayer ? (Media.title.length > 0 ? Media.title : Media.identity) : "No player"
            }

            Text {
                color: Theme.onSurfaceVariant
                width: 180
                elide: Text.ElideRight
                font.pixelSize: 10
                visible: Media.hasPlayer && Media.artist.length > 0
                text: Media.artist
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            enabled: Media.hasPlayer
            text: "⏮"
            Accessible.name: "Previous track"
            ToolTip.text: "Previous track"
            ToolTip.visible: hovered
            onClicked: Media.previous()
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            enabled: Media.hasPlayer
            text: Media.isPlaying ? "⏸" : "▶"
            Accessible.name: Media.isPlaying ? "Pause" : "Play"
            ToolTip.text: Media.isPlaying ? "Pause" : "Play"
            ToolTip.visible: hovered
            onClicked: Media.playPause()
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            enabled: Media.hasPlayer
            text: "⏭"
            Accessible.name: "Next track"
            ToolTip.text: "Next track"
            ToolTip.visible: hovered
            onClicked: Media.next()
        }
    }
}
