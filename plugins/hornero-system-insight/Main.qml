import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// System Insight (PluginKit 3, Hornero Signal): a Rainmeter/Conky-class
// desktop instrument over the shared `system` provider. A CPU oscilloscope
// drawn from the shared Telemetry history (real samples; the previous
// window as persistence; in the Signal experience the trace gets the
// luminous accent), segmented meters for CPU / memory / GPU / storage,
// per-core load strips from the same /proc/stat sample, and temperature
// readouts. Only real telemetry is drawn: a sensor that does not exist
// shows an em dash and "unavailable", never a placeholder wave. The host
// owns the module frame, position, size and edit mode; this entrypoint
// holds one `system` lease and creates no timer, process or file poll.
Item {
    id: root

    // Host context: the desktop host injects the content box.
    property string hostSurface: "desktop"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("System Insight")
    readonly property string widgetContext: i18n.tr("%1 SAMPLES").arg(Telemetry.windowSize)

    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 520
    readonly property int contentHeight: hostAvailableHeight > 0 ? hostAvailableHeight : 330
    readonly property bool tall: contentHeight >= 330
    readonly property int scopeHeight: Math.max(72, Math.min(150, Math.round(contentHeight * (tall ? 0.34 : 0.42))))

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Subscription {
        domain: "system"
    }

    Translations {
        id: i18n

        pluginId: "hornero-system-insight"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-system-insight"
    }

    readonly property bool showCores: pluginSettings.value("showCores", true) !== false
    readonly property bool showTemperatures: pluginSettings.value("showTemperatures", true) !== false
    readonly property int warnPercent: {
        const value = Number(pluginSettings.value("warnPercent", 85));
        return isFinite(value) && value >= 50 ? Math.min(100, Math.floor(value)) : 85;
    }

    function pct(v) {
        return isFinite(Number(v)) ? Math.round(Math.max(0, Math.min(1, Number(v))) * 100) + " %" : "—";
    }

    function gib(kib) {
        return (kib / 1048576).toFixed(1);
    }

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller
        Accessible.name: i18n.tr("System Insight")

        UiScope {
            width: parent.width
            height: root.scopeHeight
            label: i18n.tr("CPU") + " · 25 %/DIV"
            context: root.pct(System.cpuPerc)
            samples: Telemetry.window("cpu")
            previous: Telemetry.previousWindow("cpu")
            unavailableText: i18n.tr("Collecting samples from the shared system provider.")
        }

        UiMeterRow {
            width: parent.width
            label: i18n.tr("CPU")
            value: System.cpuPerc
            valueText: root.pct(System.cpuPerc)
            threshold: root.warnPercent / 100
        }

        UiMeterRow {
            width: parent.width
            label: i18n.tr("MEM")
            value: System.memPerc
            valueText: root.pct(System.memPerc)
            available: System.memTotal > 0
            threshold: root.warnPercent / 100
        }

        UiMeterRow {
            width: parent.width
            label: i18n.tr("GPU")
            value: System.gpuPerc
            valueText: root.pct(System.gpuPerc)
            available: System.gpuAvailable
            threshold: root.warnPercent / 100
        }

        UiMeterRow {
            width: parent.width
            label: i18n.tr("DISK")
            value: System.storagePerc
            valueText: root.pct(System.storagePerc)
            available: System.storageAvailable
            threshold: root.warnPercent / 100
        }

        UiStack {
            visible: root.showTemperatures
            width: parent.width

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("CPU TEMP")
                value: System.cpuTempAvailable ? Math.round(System.cpuTemp).toString() : ""
                unit: "°C"
                available: System.cpuTempAvailable
            }

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("GPU TEMP")
                value: System.gpuTempAvailable ? Math.round(System.gpuTemp).toString() : ""
                unit: "°C"
                available: System.gpuTempAvailable
            }

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("MEMORY")
                value: System.memTotal > 0 ? root.gib(System.memUsed) + " / " + root.gib(System.memTotal) : ""
                unit: "GiB"
                available: System.memTotal > 0
            }
        }

        // Per-logical-CPU load from the same sample as the scope: one
        // vertical strip per core (cores are not a time series, so there
        // is no trace for them).
        Item {
            visible: root.showCores && root.tall && System.cores.length > 0
            width: parent.width
            height: coreRow.implicitHeight + coresLabel.implicitHeight + Theme.spacing.small

            UiText {
                id: coresLabel

                role: "eyebrow"
                text: i18n.tr("CORES")
            }

            Row {
                id: coreRow

                anchors.top: coresLabel.bottom
                anchors.topMargin: Theme.spacing.small
                spacing: Theme.spacing.small

                Repeater {
                    model: System.cores

                    delegate: UiSegmentMeter {
                        required property real modelData

                        orientation: "vertical"
                        count: 10
                        segmentThickness: 4
                        segmentLength: 12
                        value: modelData
                        threshold: root.warnPercent / 100
                        accessibleName: i18n.tr("Core load")
                    }
                }
            }
        }
    }
}
