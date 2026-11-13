import QtQuick
import Hornero.PluginKit

// Network Monitor 2.0: dashboard card over the shared PluginKit
// Network facade, adding an in-card session history (speed
// samples taken while this card is loaded) with peak readouts on
// top of the 1.x current speeds and session totals. The PluginKit
// facade exposes only speeds and totals -- no interface list, IP
// or per-process traffic -- so none of that is shown. Sampling
// reads the already-live shared singleton behind Subscription; no
// extra network access or polling of its own is created.
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

    // Typed settings: defaults keep every 1.x row visible (speeds
    // and session totals). History is additive; the plugin stored
    // no settings before 2.0, so no stored values migrate.
    readonly property bool showSessionTotals: pluginSettings.value("showSessionTotals", true) !== false
    readonly property bool showHistory: pluginSettings.value("showHistory", true) !== false
    readonly property int sampleSeconds: {
        const value = Number(pluginSettings.value("sampleSeconds", 5));
        return isFinite(value) && value >= 1 ? Math.min(60, Math.floor(value)) : 5;
    }
    readonly property int maxSamples: 30

    property var downHistory: []
    property var upHistory: []

    function valid(v) {
        return v !== undefined && v !== null && isFinite(Number(v));
    }

    function fmt(bytes) {
        if (!valid(bytes))
            return i18n.tr("Unavailable");
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
        return valid(bytes) ? fmt(bytes) + "/s" : i18n.tr("Unavailable");
    }

    function peakOf(samples) {
        let peak = 0;
        for (let i = 0; i < samples.length; i++)
            peak = Math.max(peak, samples[i]);
        return peak;
    }

    function pushSample(samples, value) {
        const next = samples.slice();
        next.push(value);
        while (next.length > root.maxSamples)
            next.shift();
        return next;
    }

    function sample() {
        if (valid(Network.downloadSpeed))
            downHistory = pushSample(downHistory, Math.max(0, Number(Network.downloadSpeed)));
        if (valid(Network.uploadSpeed))
            upHistory = pushSample(upHistory, Math.max(0, Number(Network.uploadSpeed)));
        spark.requestPaint();
    }

    function clearHistory() {
        downHistory = [];
        upHistory = [];
        spark.requestPaint();
    }

    readonly property bool speedsAvailable: valid(Network.downloadSpeed) && valid(Network.uploadSpeed)
    readonly property real downPeak: peakOf(downHistory)
    readonly property real upPeak: peakOf(upHistory)

    Timer {
        interval: root.sampleSeconds * 1000
        running: root.showHistory
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("Network Monitor")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiText {
                    role: "title"
                    text: i18n.tr("Network")
                }

                UiChip {
                    text: root.speedsAvailable ? i18n.tr("Reporting") : i18n.tr("Unavailable")
                    tone: root.speedsAvailable ? "primary" : "neutral"
                }
            }

            UiState {
                visible: !root.speedsAvailable
                width: parent.width
                kind: "empty"
                message: i18n.tr("The Network service reported no usable speeds. The connection may be down or still starting; totals below stay as last reported.")
            }

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
            }

            UiStack {
                visible: root.showSessionTotals
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {
                    label: i18n.tr("Downloaded (session)")
                    value: root.fmt(Network.downloadTotal)
                }

                UiMetric {
                    label: i18n.tr("Uploaded (session)")
                    value: root.fmt(Network.uploadTotal)
                }
            }

            Column {
                visible: root.showHistory
                width: parent.width
                spacing: Theme.spacingSmall

                UiText {
                    role: "caption"
                    text: i18n.tr("Download history since this card loaded (not persisted)")
                }

                UiState {
                    visible: root.downHistory.length < 2
                    width: parent.width
                    kind: "loading"
                    message: i18n.tr("Collecting samples from the shared Network service.")
                }

                Canvas {
                    id: spark

                    visible: root.downHistory.length >= 2
                    width: parent.width
                    height: 36
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const samples = root.downHistory;
                        const peak = root.downPeak;
                        if (samples.length < 2 || width <= 0 || peak <= 0)
                            return;
                        ctx.strokeStyle = Theme.primary;
                        ctx.lineWidth = 2;
                        ctx.beginPath();
                        for (let i = 0; i < samples.length; i++) {
                            const x = width * i / (samples.length - 1);
                            const y = height - 2 - (samples[i] / peak) * (height - 4);
                            if (i === 0)
                                ctx.moveTo(x, y);
                            else
                                ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                    }
                }

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        label: i18n.tr("Download peak")
                        value: root.downHistory.length > 0 ? root.fmtSpeed(root.downPeak) : i18n.tr("Unavailable")
                    }

                    UiMetric {
                        label: i18n.tr("Upload peak")
                        value: root.upHistory.length > 0 ? root.fmtSpeed(root.upPeak) : i18n.tr("Unavailable")
                    }
                }

                UiButton {
                    variant: "ghost"
                    text: i18n.tr("Clear history")
                    tooltipText: i18n.tr("Forget the samples collected since this card loaded")
                    accessibleName: i18n.tr("Clear history")
                    onClicked: root.clearHistory()
                }
            }
        }
    }
}
