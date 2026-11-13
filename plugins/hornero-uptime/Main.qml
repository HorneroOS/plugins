import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Uptime 2.0 bar surface (primary, HorneroOS/plugins#31):
// PluginKit exposes no uptime/boot member -- Power is battery
// only, System has no uptime field and Time is the wall clock
// (shell plugin/qml/Hornero/PluginKit/{Power,System,Time}.qml) --
// so, as in 1.x, this surface reads /proc/uptime with the
// declared `cat` command on load, on its refresh tick and when
// the user activates it. The first field is seconds since boot
// and the second is idle seconds summed across CPUs. Unreadable
// or unparsable input shows a real unavailable state; a
// fabricated zero is never displayed. Boot time is derived
// arithmetic (now minus uptime), labelled as derived.
Item {
    id: root

    // Host context (opt-in): defaults match the 1.x roomy
    // horizontal bar layout when no host values are injected.
    property string hostOrientation: "horizontal"
    property string hostEdge: "top"
    property string hostSurface: "bar"
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

    // Typed settings: defaults reproduce 1.x exactly (60 s reads,
    // "Up" prefix, permanent unavailable label). The plugin
    // stored no settings before 2.0, so nothing migrates.
    readonly property int refreshSeconds: {
        const value = Number(pluginSettings.value("refreshSeconds", 60));
        return isFinite(value) && value >= 15 ? Math.min(600, Math.floor(value)) : 60;
    }
    readonly property bool showLabel: pluginSettings.value("showLabel", true) !== false
    readonly property bool showWhenUnavailable: pluginSettings.value("showWhenUnavailable", true) !== false
    readonly property bool shown: hasData || showWhenUnavailable
    readonly property string statusText: failed ? i18n.tr("Uptime unavailable") : hasData ? (showLabel ? i18n.tr("Up %1").arg(fmt(uptimeSeconds)) : fmt(uptimeSeconds)) : i18n.tr("Up ...")

    implicitWidth: shown ? stack.implicitWidth : 0
    implicitHeight: shown ? stack.implicitHeight : 0

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

    UiStack {
        id: stack

        visible: root.shown
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator

            variant: "ghost"
            text: root.hostCompact || root.hostOrientation === "vertical" ? "⏱" : root.statusText
            tooltipText: root.statusText
            accessibleName: i18n.tr("Uptime details")
            onClicked: {
                popover.toggle();
                root.refresh();
            }
        }
    }

    UiTooltip {
        target: indicator
        text: root.statusText
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Uptime details")

        Column {
            width: 300
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
