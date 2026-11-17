import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// System Monitor 3.0 (PluginKit 3, Hornero Signal): the dashboard
// module for the shared `system` provider. A CPU oscilloscope drawn from
// the shared Telemetry history (real samples, previous window as
// persistence), segmented meter rows for CPU / memory / GPU / storage
// that cross to `signal` at the user's threshold, and peak / average
// readouts over the same window. The card starts no timer, process or
// file poll of its own: it holds a `system` lease and reads the shared
// facade and history.
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

    Translations {
        id: i18n

        pluginId: "hornero-system-monitor"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-system-monitor"
    }

    readonly property int warnPercent: {
        const value = Number(pluginSettings.value("warnPercent", 90));
        return isFinite(value) && value >= 50 ? Math.min(100, Math.floor(value)) : 90;
    }
    readonly property bool showTemperatures: pluginSettings.value("showTemperatures", true) !== false
    readonly property bool showHistory: pluginSettings.value("showHistory", true) !== false

    // Shared telemetry window of the CPU channel (0-1 samples).
    readonly property var cpuWindow: Telemetry.window("cpu")
    readonly property var memWindow: Telemetry.window("mem")

    function valid(v) {
        return v !== undefined && v !== null && isFinite(Number(v));
    }

    function clamp01(v) {
        return valid(v) ? Math.max(0, Math.min(1, Number(v))) : 0;
    }

    function pct(v) {
        return valid(v) ? Math.round(clamp01(v) * 100) + " %" : "—";
    }

    function peakOf(samples) {
        return samples.length > 0 ? Math.max.apply(null, samples) : NaN;
    }

    function averageOf(samples) {
        if (samples.length === 0)
            return NaN;
        let sum = 0;
        for (let i = 0; i < samples.length; i++)
            sum += samples[i];
        return sum / samples.length;
    }

    function temperature(value, available) {
        return root.showTemperatures && available && valid(value) ? "  " + Math.round(value) + " °C" : "";
    }

    readonly property bool anyHigh: (System.cpuPerc * 100 >= warnPercent)
        || (System.memPerc * 100 >= warnPercent)
        || (System.gpuAvailable && System.gpuPerc * 100 >= warnPercent)
        || (System.storageAvailable && System.storagePerc * 100 >= warnPercent)

    UiCard {
        id: card

        anchors.fill: parent
        title: i18n.tr("System")
        channel: 2
        context: root.anyHigh ? i18n.tr("High load") : ""
        Accessible.name: i18n.tr("System Monitor")

        Column {
            width: parent.width
            spacing: Theme.spacing.smaller

            UiScope {
                visible: root.showHistory
                width: parent.width
                height: 92
                label: i18n.tr("CPU") + " · 25 %/DIV"
                context: Telemetry.windowSize + " " + i18n.tr("SAMPLES")
                samples: root.cpuWindow
                previous: Telemetry.previousWindow("cpu")
                unavailableText: i18n.tr("Collecting samples from the shared System service.")
            }

            UiMeterRow {
                width: parent.width
                label: i18n.tr("CPU")
                value: System.cpuPerc
                valueText: root.pct(System.cpuPerc) + root.temperature(System.cpuTemp, System.cpuTempAvailable)
                valueWidth: 96
                threshold: root.warnPercent / 100
            }

            UiMeterRow {
                width: parent.width
                label: i18n.tr("MEM")
                value: System.memPerc
                valueText: root.pct(System.memPerc)
                available: System.memTotal > 0
                valueWidth: 96
                threshold: root.warnPercent / 100
            }

            UiMeterRow {
                width: parent.width
                label: i18n.tr("GPU")
                value: System.gpuPerc
                valueText: root.pct(System.gpuPerc) + root.temperature(System.gpuTemp, System.gpuTempAvailable)
                available: System.gpuAvailable
                valueWidth: 96
                threshold: root.warnPercent / 100
            }

            UiMeterRow {
                width: parent.width
                label: i18n.tr("DISK")
                value: System.storagePerc
                valueText: root.pct(System.storagePerc)
                available: System.storageAvailable
                valueWidth: 96
                threshold: root.warnPercent / 100
            }

            UiStack {
                visible: root.showHistory
                width: parent.width
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {

                    Layout.fillWidth: true

                    Layout.preferredWidth: 1
                    label: i18n.tr("CPU peak")
                    value: isNaN(root.peakOf(root.cpuWindow)) ? "" : Math.round(root.peakOf(root.cpuWindow) * 100).toString()
                    unit: "%"
                    size: "value"
                }

                UiMetric {

                    Layout.fillWidth: true

                    Layout.preferredWidth: 1
                    label: i18n.tr("CPU avg")
                    value: isNaN(root.averageOf(root.cpuWindow)) ? "" : Math.round(root.averageOf(root.cpuWindow) * 100).toString()
                    unit: "%"
                    size: "value"
                }

                UiMetric {

                    Layout.fillWidth: true

                    Layout.preferredWidth: 1
                    label: i18n.tr("MEM peak")
                    value: isNaN(root.peakOf(root.memWindow)) ? "" : Math.round(root.peakOf(root.memWindow) * 100).toString()
                    unit: "%"
                    size: "value"
                }
            }
        }
    }
}
