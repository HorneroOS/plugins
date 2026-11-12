import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Hornero Uptime - bar widget reading /proc/uptime with the
// declared `cat` command on load and every 60 seconds. The first
// field is uptime in seconds, shown as days/hours/minutes. When
// the file is unreadable or unparsable an error state is shown;
// a fabricated zero is never displayed.
Item {
    id: root

    property bool hasData: false
    property bool failed: false
    property int uptimeSeconds: 0
    property string buffer: ""

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 34

    function refresh(): void {
        if (!uptimeProc.running) {
            root.buffer = "";
            uptimeProc.running = true;
        }
    }

    function fmt(totalSeconds) {
        const d = Math.floor(totalSeconds / 86400);
        const h = Math.floor((totalSeconds % 86400) / 3600);
        const m = Math.floor((totalSeconds % 3600) / 60);
        if (d > 0)
            return d + "d " + h + "h " + m + "m";
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: uptimeProc

        command: ["cat", "/proc/uptime"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data;
            }
        }
        onExited: exitCode => {
            const seconds = parseFloat(String(root.buffer).trim().split(/\s+/)[0]);
            if (exitCode === 0 && isFinite(seconds) && seconds > 0) {
                root.uptimeSeconds = Math.floor(seconds);
                root.hasData = true;
                root.failed = false;
            } else {
                root.hasData = false;
                root.failed = true;
            }
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        color: root.failed ? Theme.error : Theme.onSurface
        font.pixelSize: 11
        text: root.failed ? "Uptime unavailable" : (root.hasData ? "Up " + root.fmt(root.uptimeSeconds) : "Up ...")
    }
}
