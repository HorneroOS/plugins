import QtQuick
import Quickshell.Io
import Hornero.PluginKit

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

    implicitWidth: 320
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

    Translations {
        id: i18n

        pluginId: "hornero-studio-jobs"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-studio-jobs"
    }

    readonly property int maxRows: Math.max(1, Math.min(8, Number(pluginSettings.value("maxRows", 4)) || 4))
    readonly property int refreshSeconds: Math.max(5, Math.min(300, Number(pluginSettings.value("refreshSeconds", 30)) || 30))
    readonly property bool showAdapter: pluginSettings.value("showAdapter", true) !== false
    readonly property bool showFinished: pluginSettings.value("showFinished", true) !== false

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: root.visible && Theme.experience !== "gaming"
        onTriggered: root.refresh()
    }

    onVisibleChanged: if (visible && Theme.experience !== "gaming")
        refresh()

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
                for (let i = 0; i < count && rows.length < root.maxRows; i++) {
                    const parts = String(data["job_" + i] || "").split("\t");
                    const finished = parts[1] === "succeeded" || parts[1] === "failed" || parts[1] === "cancelled";
                    if (parts.length === 5 && (root.showFinished || !finished)) {
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

    function stateName(state: string): string {
        if (state === "succeeded")
            return i18n.tr("succeeded");
        if (state === "failed")
            return i18n.tr("failed");
        if (state === "cancelled")
            return i18n.tr("cancelled");
        if (state === "running")
            return i18n.tr("running");
        if (state === "queued")
            return i18n.tr("queued");
        return state;
    }

    function stateIcon(state: string): string {
        if (state === "succeeded")
            return "circle-check";
        if (state === "failed" || state === "cancelled")
            return "alert-circle";
        if (state === "running")
            return "player-play";
        return "clock";
    }

    function stateColor(state: string): color {
        if (state === "succeeded")
            return Theme.palette.phosphor;
        if (state === "failed" || state === "cancelled")
            return Theme.palette.alert;
        if (state === "running")
            return Theme.palette.signal;
        return Theme.palette.inkMuted;
    }

    UiCard {
        id: content

        width: parent.width
        title: i18n.tr("Studio jobs")
        glyph: "movie"
        channel: 7

        Column {
            width: parent.width
            spacing: Theme.spacing.small

            UiState {
                visible: !root.available
                width: parent.width
                kind: "error"
                message: i18n.tr("Studio jobs are unavailable: horneroctl did not answer.")
            }

            UiState {
                visible: root.available && root.jobs.length === 0
                width: parent.width
                kind: "empty"
                message: i18n.tr("No jobs yet. Start one with horneroctl studio jobs submit.")
            }

            Repeater {
                model: root.jobs

                delegate: Row {
                    required property var modelData

                    width: parent.width
                    spacing: Theme.spacing.small

                    UiIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.stateIcon(modelData.state)
                        color: root.stateColor(modelData.state)
                    }

                    Column {
                        width: parent.width - Theme.font.size.larger * 2 - Theme.spacing.small - (modelData.state === "running" ? liveChip.width + Theme.spacing.small : 0)
                        spacing: 0

                        UiText {
                            width: parent.width
                            text: root.basename(modelData.output)
                            elide: Text.ElideMiddle
                            wrapMode: Text.NoWrap
                        }

                        UiText {
                            width: parent.width
                            role: "caption"
                            text: (root.showAdapter ? modelData.adapter + " · " : "") + root.stateName(modelData.state)
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                    }

                    // On-air chip only while a job is really running.
                    UiChip {
                        id: liveChip

                        visible: modelData.state === "running"
                        anchors.verticalCenter: parent.verticalCenter
                        text: i18n.tr("running")
                        tone: "live"
                    }
                }
            }
        }
    }
}
