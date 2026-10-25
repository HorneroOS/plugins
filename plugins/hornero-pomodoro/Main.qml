import QtQuick

// Hornero Pomodoro — a 25 minute focus timer for the bar.
// Click toggles run/pause. At zero it flashes DONE three times and
// resets to 25:00. Pure QML: no processes, no network, no files.
Item {
    id: root

    readonly property int focusSeconds: 25 * 60
    property int remaining: focusSeconds
    property bool running: false
    property int flashes: 0

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 8

    function fmt(s) {
        const m = Math.floor(s / 60);
        const r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (root.remaining > 0)
                root.remaining -= 1;
            if (root.remaining === 0) {
                root.running = false;
                root.flashes = 3;
                flashTimer.start();
            }
        }
    }

    Timer {
        id: flashTimer

        interval: 600
        repeat: true
        onTriggered: {
            root.flashes -= 1;
            if (root.flashes <= 0) {
                stop();
                root.remaining = root.focusSeconds;
            }
        }
    }

    Text {
        color: palette.windowText
        id: label

        anchors.centerIn: parent
        text: root.flashes > 0 ? "DONE" : (root.running || root.remaining < root.focusSeconds ? "● " : "○ ") + root.fmt(root.remaining)
        opacity: root.flashes > 0 && root.flashes % 2 === 0 ? 0.25 : 1.0
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.flashes > 0) {
                flashTimer.stop();
                root.flashes = 0;
                root.remaining = root.focusSeconds;
                return;
            }
            if (!root.running && root.remaining === 0)
                root.remaining = root.focusSeconds;
            root.running = !root.running;
        }
        onDoubleClicked: {
            root.running = false;
            root.remaining = root.focusSeconds;
        }
    }
}
