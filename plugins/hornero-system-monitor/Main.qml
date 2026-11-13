import QtQuick
import Hornero.PluginKit

// System Monitor 2.0: dashboard card over the shared PluginKit
// System facade, adding what the native Performance view does not
// keep for extensions: an in-card session history (samples of the
// facade values taken while this card is loaded), peak/average
// readouts and a high-load alert chip. The 1.x CPU/memory/GPU/
// storage bars and temperature readouts are unchanged. History is
// sampled from the shared singleton behind Subscription; this
// card starts no timer, process or file poll of its own beyond
// reading the already-live facade values on its sample tick.
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

    // Typed settings: defaults keep every 1.x row visible exactly
    // as before (temperatures shown when reported). History and
    // the alert chip are additive; the plugin stored no settings
    // before 2.0, so no stored values migrate.
    readonly property int warnPercent: {
        const value = Number(pluginSettings.value("warnPercent", 90));
        return isFinite(value) && value >= 50 ? Math.min(100, Math.floor(value)) : 90;
    }
    readonly property bool showTemperatures: pluginSettings.value("showTemperatures", true) !== false
    readonly property bool showHistory: pluginSettings.value("showHistory", true) !== false
    readonly property int sampleSeconds: {
        const value = Number(pluginSettings.value("sampleSeconds", 5));
        return isFinite(value) && value >= 1 ? Math.min(60, Math.floor(value)) : 5;
    }
    readonly property int maxSamples: 30

    // Session history: fractions sampled from the facade while
    // this card instance is loaded. Not persisted and not a
    // shell-wide record; the label says so in the UI.
    property var cpuHistory: []
    property var memHistory: []

    function valid(v) {
        return v !== undefined && v !== null && isFinite(Number(v));
    }

    function clamp01(v) {
        return valid(v) ? Math.max(0, Math.min(1, Number(v))) : 0;
    }

    function pct(v) {
        return valid(v) ? Math.round(clamp01(v) * 100) + "%" : i18n.tr("Unavailable");
    }

    function peakOf(samples) {
        let peak = 0;
        for (let i = 0; i < samples.length; i++)
            peak = Math.max(peak, samples[i]);
        return peak;
    }

    function averageOf(samples) {
        if (samples.length === 0)
            return 0;
        let sum = 0;
        for (let i = 0; i < samples.length; i++)
            sum += samples[i];
        return sum / samples.length;
    }

    function pushSample(samples, value) {
        const next = samples.slice();
        next.push(value);
        while (next.length > root.maxSamples)
            next.shift();
        return next;
    }

    function sample() {
        if (valid(System.cpuPerc))
            cpuHistory = pushSample(cpuHistory, clamp01(System.cpuPerc));
        if (valid(System.memPerc))
            memHistory = pushSample(memHistory, clamp01(System.memPerc));
        spark.requestPaint();
    }

    function clearHistory() {
        cpuHistory = [];
        memHistory = [];
        spark.requestPaint();
    }

    readonly property bool anyHigh: (valid(System.cpuPerc) && clamp01(System.cpuPerc) * 100 >= warnPercent)
        || (valid(System.memPerc) && clamp01(System.memPerc) * 100 >= warnPercent)
        || (valid(System.gpuPerc) && clamp01(System.gpuPerc) * 100 >= warnPercent)
        || (valid(System.storagePerc) && clamp01(System.storagePerc) * 100 >= warnPercent)

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
        Accessible.name: i18n.tr("System Monitor")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiText {
                    role: "title"
                    text: i18n.tr("System")
                }

                UiChip {
                    visible: root.anyHigh
                    text: i18n.tr("High load")
                    tone: "error"
                }
            }

            Repeater {
                model: [
                    { "label": i18n.tr("CPU"), "value": System.cpuPerc, "detail": root.pct(System.cpuPerc) + (root.showTemperatures && root.valid(System.cpuTemp) && System.cpuTemp > 0 ? "  " + Math.round(System.cpuTemp) + " C" : "") },
                    { "label": i18n.tr("Memory"), "value": System.memPerc, "detail": root.pct(System.memPerc) },
                    { "label": i18n.tr("GPU"), "value": System.gpuPerc, "detail": root.pct(System.gpuPerc) + (root.showTemperatures && root.valid(System.gpuTemp) && System.gpuTemp > 0 ? "  " + Math.round(System.gpuTemp) + " C" : "") },
                    { "label": i18n.tr("Storage"), "value": System.storagePerc, "detail": root.pct(System.storagePerc) }
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
                            visible: root.valid(modelData.value) && root.clamp01(modelData.value) * 100 >= root.warnPercent
                            text: i18n.tr("High")
                            tone: "error"
                        }
                    }

                    UiProgress {
                        width: parent.width
                        value: root.valid(modelData.value) ? root.clamp01(modelData.value) : 0
                        accessibleName: modelData.label
                    }
                }
            }

            Column {
                visible: root.showHistory
                width: parent.width
                spacing: Theme.spacingSmall

                UiText {
                    role: "caption"
                    text: i18n.tr("CPU history since this card loaded (not persisted)")
                }

                UiState {
                    visible: root.cpuHistory.length < 2
                    width: parent.width
                    kind: "loading"
                    message: i18n.tr("Collecting samples from the shared System service.")
                }

                Canvas {
                    id: spark

                    visible: root.cpuHistory.length >= 2
                    width: parent.width
                    height: 36
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const samples = root.cpuHistory;
                        if (samples.length < 2 || width <= 0)
                            return;
                        ctx.strokeStyle = Theme.primary;
                        ctx.lineWidth = 2;
                        ctx.beginPath();
                        for (let i = 0; i < samples.length; i++) {
                            const x = width * i / (samples.length - 1);
                            const y = height - 2 - samples[i] * (height - 4);
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
                        label: i18n.tr("CPU peak")
                        value: root.cpuHistory.length > 0 ? root.pct(root.peakOf(root.cpuHistory)) : i18n.tr("Unavailable")
                    }

                    UiMetric {
                        label: i18n.tr("CPU average")
                        value: root.cpuHistory.length > 0 ? root.pct(root.averageOf(root.cpuHistory)) : i18n.tr("Unavailable")
                    }

                    UiMetric {
                        label: i18n.tr("Memory peak")
                        value: root.memHistory.length > 0 ? root.pct(root.peakOf(root.memHistory)) : i18n.tr("Unavailable")
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
