import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Countdown - bar countdown with 5/10/25 minute presets,
// start/pause and reset. At zero the ring and text flash DONE
// visually; there is no sound.
Item {
    id: root

    property int totalSeconds: 5 * 60
    property int remainingSeconds: 5 * 60
    property bool running: false
    property bool finished: false
    property bool flashOn: true

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 40

    function fmt(s) {
        const m = Math.floor(s / 60);
        const r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    function setPreset(minutes) {
        root.running = false;
        root.finished = false;
        root.totalSeconds = minutes * 60;
        root.remainingSeconds = root.totalSeconds;
        ring.requestPaint();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (root.remainingSeconds > 0)
                root.remainingSeconds -= 1;
            if (root.remainingSeconds === 0) {
                root.running = false;
                root.finished = true;
            }
            ring.requestPaint();
        }
    }

    Timer {
        interval: 600
        repeat: true
        running: root.finished
        onTriggered: {
            root.flashOn = !root.flashOn;
            ring.requestPaint();
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Canvas {
            id: ring

            width: 28
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                const frac = root.totalSeconds > 0 ? root.remainingSeconds / root.totalSeconds : 0;
                ctx.lineWidth = 3;
                ctx.strokeStyle = Theme.surfaceContainer;
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, 11, 0, Math.PI * 2);
                ctx.stroke();
                ctx.strokeStyle = root.finished ? Theme.error : Theme.primary;
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, 11, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0, Math.min(1, frac)));
                ctx.stroke();
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.finished ? Theme.error : Theme.onSurface
            font.pixelSize: 12
            font.bold: true
            opacity: root.finished && !root.flashOn ? 0.25 : 1.0
            text: root.finished ? "DONE" : root.fmt(root.remainingSeconds)
        }

        Repeater {
            model: [5, 10, 25]

            delegate: Button {
                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                text: modelData + "m"
                Accessible.name: "Set countdown to " + modelData + " minutes"
                ToolTip.text: "Set countdown to " + modelData + " minutes"
                ToolTip.visible: hovered
                onClicked: root.setPreset(modelData)
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: root.running ? "Pause" : "Start"
            Accessible.name: root.running ? "Pause countdown" : "Start countdown"
            ToolTip.text: root.running ? "Pause countdown" : "Start countdown"
            ToolTip.visible: hovered
            onClicked: {
                if (root.finished || root.remainingSeconds === 0)
                    root.setPreset(Math.floor(root.totalSeconds / 60));
                root.finished = false;
                root.running = !root.running;
                ring.requestPaint();
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Reset"
            Accessible.name: "Reset countdown"
            ToolTip.text: "Reset countdown"
            ToolTip.visible: hovered
            onClicked: root.setPreset(Math.floor(root.totalSeconds / 60))
        }
    }
}
