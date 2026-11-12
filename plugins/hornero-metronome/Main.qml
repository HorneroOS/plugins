import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Metronome - bar widget with a flashing beat
// indicator. BPM is persisted via PluginKit Settings
// (declared integer setting "bpm", default 96, 40-208).
Item {
    id: root

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 34

    property int bpm: 96
    property bool running: false
    property bool beatOn: false

    Settings {
        id: pluginSettings
        pluginId: "hornero-metronome"
    }

    function clampBpm(value) { return Math.max(40, Math.min(208, Math.round(value))); }
    function setBpm(value) {
        root.bpm = root.clampBpm(value);
        pluginSettings.setValue("bpm", root.bpm);
    }

    Component.onCompleted: {
        var stored = pluginSettings.value("bpm", 96);
        root.bpm = root.clampBpm(stored === undefined || stored === null ? 96 : stored);
    }

    Timer {
        interval: Math.round(60000 / Math.max(1, root.bpm))
        repeat: true
        running: root.running
        onTriggered: {
            root.beatOn = true;
            flashTimer.restart();
        }
    }
    Timer {
        id: flashTimer
        interval: 140
        repeat: false
        onTriggered: root.beatOn = false
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            width: 14; height: 14; radius: 7
            anchors.verticalCenter: parent.verticalCenter
            color: root.beatOn ? Theme.primary : Theme.surfaceContainer
            Accessible.name: root.beatOn ? "Metronome beat on" : "Metronome beat off"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.onSurface
            font.pixelSize: 12
            Accessible.name: "Metronome " + root.bpm + " beats per minute"
            text: root.bpm + " BPM"
        }
        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "-"
            Accessible.name: "Decrease BPM"
            ToolTip.text: "Decrease BPM"
            ToolTip.visible: hovered
            onClicked: root.setBpm(root.bpm - 1)
        }
        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            Accessible.name: "Increase BPM"
            ToolTip.text: "Increase BPM"
            ToolTip.visible: hovered
            onClicked: root.setBpm(root.bpm + 1)
        }
        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: root.running ? "Stop" : "Start"
            Accessible.name: root.running ? "Stop metronome" : "Start metronome"
            ToolTip.text: root.running ? "Stop metronome" : "Start metronome"
            ToolTip.visible: hovered
            onClicked: {
                root.running = !root.running;
                if (!root.running) root.beatOn = false;
            }
        }
    }
}
