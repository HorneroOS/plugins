import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Stopwatch - bar stopwatch. Pure QML elapsed timer:
// start/pause/resume and reset, displayed as mm:ss.t.
Item {
    id: root

    property int elapsedMs: 0
    property bool running: false

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 34

    function fmt(ms) {
        const totalTenths = Math.floor(ms / 100);
        const tenths = totalTenths % 10;
        const totalSeconds = Math.floor(totalTenths / 10);
        const seconds = totalSeconds % 60;
        const minutes = Math.floor(totalSeconds / 60);
        return (minutes < 10 ? "0" : "") + minutes + ":" + (seconds < 10 ? "0" : "") + seconds + "." + tenths;
    }

    Timer {
        interval: 100
        repeat: true
        running: root.running
        onTriggered: root.elapsedMs += 100
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.onSurface
            font.pixelSize: 12
            font.bold: true
            text: root.fmt(root.elapsedMs)
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: root.running ? "Pause" : (root.elapsedMs > 0 ? "Resume" : "Start")
            Accessible.name: root.running ? "Pause stopwatch" : "Start stopwatch"
            ToolTip.text: root.running ? "Pause stopwatch" : "Start stopwatch"
            ToolTip.visible: hovered
            onClicked: root.running = !root.running
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Reset"
            enabled: root.elapsedMs > 0 || root.running
            Accessible.name: "Reset stopwatch"
            ToolTip.text: "Reset stopwatch"
            ToolTip.visible: hovered
            onClicked: {
                root.running = false;
                root.elapsedMs = 0;
            }
        }
    }
}
