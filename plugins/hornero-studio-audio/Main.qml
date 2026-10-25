import QtQuick
import Quickshell.Io

// Hornero Studio Audio — a compact bar indicator for the Studio audio
// mode and Temporary Performance state, read from the typed contract
// `horneroctl --json studio mode` (HorneroOS/hornero#286/#287) every
// 60 seconds. Read-only: switching modes is an explicit opt-in that
// belongs to the CLI and Control Center, never to this indicator.
Item {
    id: root

    property string mode: ""
    property bool performance: false
    property bool available: false
    property string buffer: ""

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 8

    readonly property string shortMode: {
        if (root.mode === "low-latency")
            return "LL";
        if (root.mode === "advanced")
            return "ADV";
        if (root.mode === "balanced")
            return "BAL";
        return "?";
    }

    function refresh(): void {
        if (!modeProc.running) {
            root.buffer = "";
            modeProc.running = true;
        }
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: modeProc

        command: ["horneroctl", "--json", "studio", "mode"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data;
            }
        }
        onExited: {
            try {
                const env = JSON.parse(root.buffer.trim());
                const data = (env && env.data) || {};
                root.mode = String(data.audio_mode || "");
                root.performance = data.performance_active === "true";
                root.available = env.ok === true && root.mode.length > 0;
            } catch (e) {
                root.available = false;
                root.mode = "";
                root.performance = false;
            }
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.available ? `STUDIO ${root.shortMode}${root.performance ? " · PERF" : ""}` : "STUDIO ?"
        opacity: root.available ? 1.0 : 0.5
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.refresh()
    }
}
