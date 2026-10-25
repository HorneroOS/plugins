import QtQuick
import Quickshell.Io

// Hornero Studio Jobs — a read-only render/export monitor card.
// Data comes only from the typed contract `horneroctl --json studio
// jobs list` (HorneroOS/hornero#289), refreshed every 30 seconds.
// This plugin never submits, runs or cancels a job: those actions
// belong to the CLI and Control Center, where they are explicit.
Item {
    id: root

    property var jobs: []
    property bool available: true
    property string buffer: ""

    implicitWidth: 300
    implicitHeight: content.implicitHeight

    function refresh(): void {
        if (!listProc.running) {
            root.buffer = "";
            listProc.running = true;
        }
    }

    function basename(path) {
        const parts = String(path).split("/");
        return parts[parts.length - 1] || String(path);
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: listProc

        command: ["horneroctl", "--json", "studio", "jobs", "list"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data;
            }
        }
        onExited: {
            try {
                const env = JSON.parse(root.buffer.trim());
                const data = (env && env.data) || {};
                const count = parseInt(data.count || "0", 10);
                const rows = [];
                for (let i = 0; i < count && rows.length < 4; i++) {
                    const parts = String(data["job_" + i] || "").split("\t");
                    if (parts.length === 5) {
                        rows.push({
                            "id": parts[0],
                            "state": parts[1],
                            "adapter": parts[2],
                            "output": parts[4]
                        });
                    }
                }
                root.jobs = rows;
                root.available = env.ok === true;
            } catch (e) {
                root.jobs = [];
                root.available = false;
            }
        }
    }

    Column {
        id: content

        spacing: 4

        Text {
            color: palette.windowText
            text: root.available ? (root.jobs.length > 0 ? "Studio jobs" : "No Studio jobs yet") : "Studio jobs unavailable"
            font.bold: true
        }

        Text {
            color: palette.windowText
            visible: root.available && root.jobs.length === 0
            text: "Submit one: horneroctl studio jobs submit"
            opacity: 0.7
        }

        Text {
            color: palette.windowText
            visible: !root.available
            text: "Is horneroctl installed?"
            opacity: 0.7
        }

        Repeater {
            model: root.jobs

            Text {
                color: palette.windowText
                required property var modelData

                text: `${modelData.state} · ${modelData.adapter} · ${root.basename(modelData.output)}`
                opacity: modelData.state === "succeeded" ? 0.7 : 1.0
            }
        }
    }
}
