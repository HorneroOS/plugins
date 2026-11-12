import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Microphone - bar widget over PluginKit Audio
// (sourceVolume, sourceMuted, hasSource, toggleSourceMute).
// Shows "No input device" when Audio.hasSource is false.
// Privacy: displays only muted/volume state; it never records,
// captures or transmits audio.
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
            Accessible.name: !Audio.hasSource ? "No input device" : (Audio.sourceMuted ? "Microphone muted" : "Microphone " + Math.round(Audio.sourceVolume * 100) + " percent")
            text: {
                if (!Audio.hasSource)
                    return "No input device";
                if (Audio.sourceMuted)
                    return "Mic muted " + Math.round(Audio.sourceVolume * 100) + "%";
                return "Mic " + Math.round(Audio.sourceVolume * 100) + "%";
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: Audio.sourceMuted ? "Unmute" : "Mute"
            enabled: Audio.hasSource
            Accessible.name: Audio.sourceMuted ? "Unmute microphone" : "Mute microphone"
            ToolTip.text: Audio.sourceMuted ? "Unmute microphone" : "Mute microphone"
            ToolTip.visible: hovered
            onClicked: Audio.toggleSourceMute()
        }
    }
}
