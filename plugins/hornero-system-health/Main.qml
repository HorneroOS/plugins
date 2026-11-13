import QtQuick
import Hornero.PluginKit

// System Health 2.0: dashboard health summary over the shared
// PluginKit System, Power and Network facades. Each row carries a
// health state derived only from the value the facade reports and
// the user's typed thresholds, plus a short troubleshooting hint
// when a row needs attention. No SMART, disk-health, battery-
// health or process data is exposed by PluginKit, so none is
// shown or implied. Missing data stays an honest unavailable
// state, exactly as in 1.x.
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

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    Subscription {
        domain: "system"
    }

    Subscription {
        domain: "power"
    }

    Subscription {
        domain: "network"
    }

    Translations {
        id: i18n

        pluginId: "hornero-system-health"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-system-health"
    }

    // Typed settings: defaults keep every 1.x row visible.
    // Thresholds and hints are additive; the plugin stored no
    // settings before 2.0, so no stored values migrate.
    readonly property int warnPercent: {
        const value = Number(pluginSettings.value("warnPercent", 90));
        return isFinite(value) && value >= 50 ? Math.min(100, Math.floor(value)) : 90;
    }
    readonly property int batteryWarnPercent: {
        const value = Number(pluginSettings.value("batteryWarnPercent", 20));
        return isFinite(value) && value >= 1 ? Math.min(50, Math.floor(value)) : 20;
    }
    readonly property bool showNetwork: pluginSettings.value("showNetwork", true) !== false
    readonly property bool showHints: pluginSettings.value("showHints", true) !== false

    function valid(v) {
        return v !== undefined && v !== null && isFinite(Number(v));
    }

    function pct(v) {
        if (!valid(v))
            return i18n.tr("Unavailable");
        return Math.round(Math.max(0, Math.min(1, Number(v))) * 100) + "%";
    }

    // Health state for a 0..1 usage fraction: derived only from
    // the reported value and the warnPercent threshold.
    function usageState(v) {
        if (!valid(v))
            return "unavailable";
        return Math.max(0, Math.min(1, Number(v))) * 100 >= warnPercent ? "attention" : "ok";
    }

    function fmtSpeed(bytes) {
        if (!valid(bytes))
            return i18n.tr("Unavailable");
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let v = Math.max(0, Number(bytes) || 0);
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i] + "/s";
    }

    function batteryText() {
        if (!Power.hasBattery)
            return i18n.tr("No battery");
        var t = Power.percentage + "%";
        if (Power.charging)
            t += " (" + i18n.tr("charging") + ")";
        else if (Power.stateText)
            t += " (" + Power.stateText + ")";
        return t;
    }

    // "none" (no battery fitted) is a normal desktop state, not a
    // fault; a low discharging battery needs attention.
    function batteryState() {
        if (!Power.hasBattery)
            return "none";
        return (!Power.charging && Power.percentage <= batteryWarnPercent) ? "attention" : "ok";
    }

    function networkState() {
        return (valid(Network.downloadSpeed) && valid(Network.uploadSpeed)) ? "ok" : "unavailable";
    }

    readonly property var rowStates: [usageState(System.cpuPerc), usageState(System.memPerc), usageState(System.storagePerc), batteryState(), networkState()]
    readonly property bool anyAttention: rowStates.indexOf("attention") !== -1
    readonly property bool anyUnavailable: rowStates.indexOf("unavailable") !== -1
    readonly property string overallText: anyAttention ? i18n.tr("Needs attention") : anyUnavailable ? i18n.tr("Partial data") : i18n.tr("Healthy")

    function stateLabel(state) {
        if (state === "attention")
            return i18n.tr("Needs attention");
        if (state === "unavailable")
            return i18n.tr("Unavailable");
        if (state === "none")
            return i18n.tr("No battery");
        return i18n.tr("OK");
    }

    function stateTone(state) {
        if (state === "attention")
            return "error";
        if (state === "ok")
            return "primary";
        return "neutral";
    }

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("System Health")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiText {
                    role: "title"
                    text: i18n.tr("System Health")
                }

                UiChip {
                    text: root.overallText
                    tone: root.anyAttention ? "error" : root.anyUnavailable ? "neutral" : "primary"
                }
            }

            UiState {
                visible: root.anyUnavailable && !root.anyAttention
                width: parent.width
                kind: "empty"
                message: i18n.tr("Some services reported no usable data. Affected rows are marked unavailable instead of guessing.")
            }

            Repeater {
                model: [
                    { "label": i18n.tr("CPU"), "detail": root.pct(System.cpuPerc), "state": root.usageState(System.cpuPerc), "hint": i18n.tr("Sustained high CPU usually means a busy app or background job; check what is running if the system feels slow.") },
                    { "label": i18n.tr("Memory"), "detail": root.pct(System.memPerc), "state": root.usageState(System.memPerc), "hint": i18n.tr("High memory use can push the system into swap; closing unused apps frees memory.") },
                    { "label": i18n.tr("Storage"), "detail": root.pct(System.storagePerc), "state": root.usageState(System.storagePerc), "hint": i18n.tr("Nearly full storage can block updates and caches; free space or check the Disk Usage card per disk.") },
                    { "label": i18n.tr("Battery"), "detail": root.batteryText(), "state": root.batteryState(), "hint": i18n.tr("Battery is low and not charging; connect the charger soon.") }
                ]

                delegate: Column {
                    required property var modelData

                    width: parent.width
                    spacing: Theme.spacingSmall

                    UiStack {
                        orientation: root.hostOrientation
                        compact: root.hostCompact

                        UiMetric {
                            label: modelData.label
                            value: modelData.detail
                        }

                        UiChip {
                            text: root.stateLabel(modelData.state)
                            tone: root.stateTone(modelData.state)
                        }
                    }

                    UiText {
                        visible: root.showHints && modelData.state === "attention"
                        width: parent.width
                        role: "caption"
                        text: modelData.hint
                    }
                }
            }

            Column {
                visible: root.showNetwork
                width: parent.width
                spacing: Theme.spacingSmall

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        label: i18n.tr("Download")
                        value: root.fmtSpeed(Network.downloadSpeed)
                    }

                    UiMetric {
                        label: i18n.tr("Upload")
                        value: root.fmtSpeed(Network.uploadSpeed)
                    }

                    UiChip {
                        text: root.stateLabel(root.networkState())
                        tone: root.stateTone(root.networkState())
                    }
                }

                UiText {
                    visible: root.showHints && root.networkState() === "unavailable"
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("The Network service reported no usable speeds; the connection may be down or still starting.")
                }
            }

            UiText {
                width: parent.width
                role: "caption"
                text: i18n.tr("Health states use only the values and thresholds above. Disk SMART, battery health and per-process data are not exposed to extensions and are not shown.")
            }
        }
    }
}
