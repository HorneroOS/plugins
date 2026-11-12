import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Volume - bar widget over PluginKit Audio
// (volume, muted, hasSink, toggleMute, decrementVolume,
// incrementVolume). Shows "Muted" when muted and
// "No output device" when Audio.hasSink is false.
Item {
    id: root

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 34

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.onSurface
            font.pixelSize: 12
            Accessible.name: !Audio.hasSink ? "No output device" : (Audio.muted ? "Volume muted" : "Volume " + Math.round(Audio.volume * 100) + " percent")
            text: {
                if (!Audio.hasSink)
                    return "No output device";
                if (Audio.muted)
                    return "Muted";
                return Math.round(Audio.volume * 100) + "%";
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: Audio.muted ? "Unmute" : "Mute"
            enabled: Audio.hasSink
            Accessible.name: Audio.muted ? "Unmute output" : "Mute output"
            ToolTip.text: Audio.muted ? "Unmute output" : "Mute output"
            ToolTip.visible: hovered
            onClicked: Audio.toggleMute()
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "-"
            enabled: Audio.hasSink
            Accessible.name: "Decrease volume"
            ToolTip.text: "Decrease volume"
            ToolTip.visible: hovered
            onClicked: Audio.decrementVolume()
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            enabled: Audio.hasSink
            Accessible.name: "Increase volume"
            ToolTip.text: "Increase volume"
            ToolTip.visible: hovered
            onClicked: Audio.incrementVolume()
        }
    }
}
