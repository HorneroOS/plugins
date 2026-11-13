import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Uptime 2.0 dashboard surface (HorneroOS/plugins#31): the card
// form of the bar popover. Each surface entrypoint runs in its
// own Loader, so this card keeps its own declared `cat
// /proc/uptime` read on the same typed cadence; it shares no
// process with the bar surface. See Main.qml for the documented
// PluginKit uptime facade gap and the honest error contract.
Item {
    id: root

    // Host context (opt-in): defaults keep a roomy dashboard card.
    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    property bool hasData: false
    property bool failed: false
    property int uptimeSeconds: 0
    property int idleSeconds: -1
    property string buffer: ""

    // LOGIC-BEGIN (kept verbatim in Dashboard.qml; pure logic only)
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

    function parseUptime(text) {
        const fields = String(text).trim().split(/\s+/);
        const up = parseFloat(fields[0]);
        const idle = parseFloat(fields[1]);
        return [isFinite(up) && up > 0 ? Math.floor(up) : -1, isFinite(idle) && idle >= 0 ? Math.floor(idle) : -1];
    }

    function bootEpochMs(nowMs, uptimeSeconds) {
        return nowMs - uptimeSeconds * 1000;
    }
    // LOGIC-END

    function refresh(): void {
        if (!uptimeProc.running) {
            root.buffer = "";
            uptimeProc.running = true;
        }
    }

    function bootText() {
        if (!hasData)
            return i18n.tr("Unavailable");
        return i18n.formatDateTime(new Date(bootEpochMs(Date.now(), uptimeSeconds)), "yyyy-MM-dd hh:mm");
    }

    readonly property int refreshSeconds: {
        const value = Number(pluginSettings.value("refreshSeconds", 60));
        return isFinite(value) && value >= 15 ? Math.min(600, Math.floor(value)) : 60;
    }

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    Component.onCompleted: refresh()

    Translations {
        id: i18n

        pluginId: "hornero-uptime"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-uptime"
    }

    Timer {
        interval: root.refreshSeconds * 1000
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
            const parsed = root.parseUptime(root.buffer);
            if (exitCode === 0 && parsed[0] > 0) {
                root.uptimeSeconds = parsed[0];
                root.idleSeconds = parsed[1];
                root.hasData = true;
                root.failed = false;
            } else {
                root.hasData = false;
                root.failed = true;
                root.idleSeconds = -1;
            }
        }
    }

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("Uptime")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Uptime")
            }

            UiState {
                visible: !root.hasData && !root.failed
                width: parent.width
                kind: "loading"
                message: i18n.tr("Reading /proc/uptime...")
            }

            UiState {
                visible: root.failed
                width: parent.width
                kind: "error"
                message: i18n.tr("Uptime is unavailable: /proc/uptime could not be read or parsed. No value is fabricated.")
            }

            Column {
                visible: root.hasData
                width: parent.width
                spacing: Theme.spacingSmall

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        label: i18n.tr("Uptime")
                        value: root.fmt(root.uptimeSeconds)
                    }

                    UiMetric {
                        label: i18n.tr("Idle time")
                        value: root.idleSeconds >= 0 ? root.fmt(root.idleSeconds) : i18n.tr("Unavailable")
                    }
                }

                UiMetric {
                    label: i18n.tr("Booted at (derived)")
                    value: root.bootText()
                }

                UiText {
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Idle time is summed across CPUs in /proc/uptime and can exceed wall-clock time. Boot time is derived as now minus uptime; PluginKit exposes no uptime or boot-time facade.")
                }
            }

            UiButton {
                variant: "ghost"
                text: i18n.tr("Refresh")
                tooltipText: i18n.tr("Read /proc/uptime again")
                accessibleName: i18n.tr("Refresh uptime")
                onClicked: root.refresh()
            }
        }
    }
}
