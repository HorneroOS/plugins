import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Network Monitor 3.0 (PluginKit 3, Hornero Signal): the dashboard
// module for the shared `network` provider. A download oscilloscope in
// `cue` (network) drawn from the shared Telemetry history with its scale
// stated in the eyebrow, an upload sparkline, current speeds and session
// totals as readouts. The facade exposes only speeds and totals -- no
// interface list, IP or per-process traffic -- so none of that is shown.
// The card holds a `network` lease and reads shared values; it creates
// no timer, process or network access of its own.
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
        domain: "network"
    }

    Translations {
        id: i18n

        pluginId: "hornero-network-monitor"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-network-monitor"
    }

    readonly property bool showSessionTotals: pluginSettings.value("showSessionTotals", true) !== false
    readonly property bool showHistory: pluginSettings.value("showHistory", true) !== false

    readonly property var downWindow: Telemetry.window("netDown")
    readonly property var upWindow: Telemetry.window("netUp")

    function valid(v) {
        return v !== undefined && v !== null && isFinite(Number(v));
    }

    function fmt(bytes) {
        if (!valid(bytes))
            return "";
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let v = Math.max(0, Number(bytes) || 0);
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i];
    }

    function fmtSpeed(bytes) {
        return valid(bytes) ? fmt(bytes) + "/s" : "";
    }

    function peakOf(samples) {
        return samples.length > 0 ? Math.max.apply(null, samples) : NaN;
    }

    // Plot scale: the window peak rounded up to a 1/2/5 step so the
    // eyebrow can state a clean per-division value (4 divisions).
    function niceMax(peak) {
        if (!valid(peak) || peak <= 0)
            return 1024;
        const exp = Math.pow(10, Math.floor(Math.log(peak) / Math.LN10));
        const f = peak / exp;
        return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * exp;
    }

    readonly property real downScale: niceMax(Math.max(peakOf(downWindow) || 0, peakOf(Telemetry.previousWindow("netDown")) || 0))
    readonly property real upScale: niceMax(peakOf(upWindow))
    readonly property bool speedsAvailable: valid(Network.downloadSpeed) && valid(Network.uploadSpeed)

    UiCard {
        id: card

        anchors.fill: parent
        title: i18n.tr("Network")
        channel: 3
        context: root.speedsAvailable ? i18n.tr("Reporting") : i18n.tr("Unavailable")
        Accessible.name: i18n.tr("Network Monitor")

        Column {
            width: parent.width
            spacing: Theme.spacing.smaller

            UiState {
                visible: !root.speedsAvailable
                width: parent.width
                kind: "unavailable"
                message: i18n.tr("The Network service reported no usable speeds. The connection may be down or still starting; totals below stay as last reported.")
            }

            UiScope {
                visible: root.showHistory
                width: parent.width
                height: 92
                label: i18n.tr("DOWN") + " · " + root.fmtSpeed(root.downScale / 4) + "/DIV"
                context: Telemetry.windowSize + " " + i18n.tr("SAMPLES")
                samples: root.downWindow
                previous: Telemetry.previousWindow("netDown")
                maximum: root.downScale
                tone: "cue"
                unavailableText: i18n.tr("Collecting samples from the shared Network service.")
            }

            Row {
                visible: root.showHistory
                width: parent.width
                spacing: Theme.spacing.smaller

                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    role: "eyebrow"
                    text: i18n.tr("UP")
                }

                UiSparkline {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40 - Theme.spacing.smaller
                    height: 22
                    values: root.upWindow
                    maximum: root.upScale
                    window: Telemetry.windowSize
                    tone: "cue"
                    accessibleName: i18n.tr("Upload history")
                }
            }

            UiStack {
                width: parent.width
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {

                    Layout.fillWidth: true

                    Layout.preferredWidth: 1
                    label: i18n.tr("Download")
                    value: root.fmtSpeed(Network.downloadSpeed)
                    available: root.speedsAvailable
                    size: "value"
                }

                UiMetric {

                    Layout.fillWidth: true

                    Layout.preferredWidth: 1
                    label: i18n.tr("Upload")
                    value: root.fmtSpeed(Network.uploadSpeed)
                    available: root.speedsAvailable
                    size: "value"
                }
            }

            UiStack {
                visible: root.showSessionTotals
                width: parent.width
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {

                    Layout.fillWidth: true

                    Layout.preferredWidth: 1
                    label: i18n.tr("Session down")
                    value: root.fmt(Network.downloadTotal)
                    size: "value"
                }

                UiMetric {

                    Layout.fillWidth: true

                    Layout.preferredWidth: 1
                    label: i18n.tr("Session up")
                    value: root.fmt(Network.uploadTotal)
                    size: "value"
                }
            }

            UiStack {
                visible: root.showHistory
                width: parent.width
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {

                    Layout.fillWidth: true

                    Layout.preferredWidth: 1
                    label: i18n.tr("Peak down")
                    value: root.fmtSpeed(root.peakOf(root.downWindow))
                    size: "value"
                }

                UiMetric {

                    Layout.fillWidth: true

                    Layout.preferredWidth: 1
                    label: i18n.tr("Peak up")
                    value: root.fmtSpeed(root.peakOf(root.upWindow))
                    size: "value"
                }
            }
        }
    }
}
