import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Network Scope (PluginKit 3, Hornero Signal): a desktop instrument over the
// shared `network` provider. Download and upload each get an oscilloscope in
// `cue` (network) drawn from the shared Telemetry history with the scale
// stated in the eyebrow (a 1/2/5 step above the window peak, 4 divisions),
// the previous window as persistence, plus current rates, peaks and shell
// session totals and, on Wi-Fi, a signal meter. The facade exposes only
// aggregate rates, totals and link state: no interface list, addresses or
// per-process traffic, so none is shown. The network name is personal data
// and stays hidden unless `showNetworkName` is on. Real telemetry only: with
// no usable rates the scopes show "unavailable", never a placeholder wave.
// The host owns frame, position, size and edit mode; this entrypoint holds
// one `network` lease and creates no timer, process or network access.
Item {
    id: root

    // Host context: the desktop host injects the content box.
    property string hostSurface: "desktop"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Network Scope")
    readonly property string widgetContext: Network.connected ? (Network.wifi ? i18n.tr("WI-FI") : i18n.tr("WIRED")) : i18n.tr("OFFLINE")

    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 420
    readonly property int contentHeight: hostAvailableHeight > 0 ? hostAvailableHeight : 300
    readonly property int scopeHeight: Math.max(56, Math.min(110, Math.round(contentHeight * 0.26)))

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Subscription {
        domain: "network"
    }

    Translations {
        id: i18n

        pluginId: "hornero-network-scope"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-network-scope"
    }

    readonly property bool showTotals: pluginSettings.value("showSessionTotals", true) !== false
    readonly property bool showNetworkName: pluginSettings.value("showNetworkName", false) === true

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

    function peakOf(samples) {
        return samples.length > 0 ? Math.max.apply(null, samples) : NaN;
    }

    function niceMax(peak) {
        if (!valid(peak) || peak <= 0)
            return 1024;
        const exp = Math.pow(10, Math.floor(Math.log(peak) / Math.LN10));
        const f = peak / exp;
        return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * exp;
    }

    readonly property real downScale: niceMax(Math.max(peakOf(downWindow) || 0, peakOf(Telemetry.previousWindow("netDown")) || 0))
    readonly property real upScale: niceMax(Math.max(peakOf(upWindow) || 0, peakOf(Telemetry.previousWindow("netUp")) || 0))
    readonly property bool ratesAvailable: valid(Network.downloadSpeed) && valid(Network.uploadSpeed)

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller
        Accessible.name: i18n.tr("Network Scope")

        UiScope {
            width: parent.width
            height: root.scopeHeight
            label: i18n.tr("DOWN") + " · " + root.fmt(root.downScale / 4) + "/s/DIV"
            context: Network.formatRate(Network.downloadSpeed)
            samples: root.downWindow
            previous: Telemetry.previousWindow("netDown")
            maximum: root.downScale
            tone: "cue"
            unavailableText: i18n.tr("Collecting samples from the shared network provider.")
        }

        UiScope {
            width: parent.width
            height: root.scopeHeight
            label: i18n.tr("UP") + " · " + root.fmt(root.upScale / 4) + "/s/DIV"
            context: Network.formatRate(Network.uploadSpeed)
            samples: root.upWindow
            previous: Telemetry.previousWindow("netUp")
            maximum: root.upScale
            tone: "cue"
            unavailableText: i18n.tr("Collecting samples from the shared network provider.")
        }

        UiMeterRow {
            visible: Network.wifi
            width: parent.width
            label: i18n.tr("WI-FI")
            labelWidth: 56
            value: Network.signalStrength / 100
            valueText: Network.signalStrength >= 0 ? Network.signalStrength + " %" : ""
            available: Network.signalStrength >= 0
            threshold: 1.01
        }

        UiDetailRow {
            visible: root.showNetworkName && Network.wifi && Network.ssid.length > 0
            width: parent.width
            glyph: "wifi"
            label: i18n.tr("Network")
            value: Network.ssid
        }

        UiStack {
            visible: root.showTotals
            width: parent.width

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("SESSION DOWN")
                value: root.fmt(Network.downloadTotal)
                available: root.ratesAvailable
            }

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("SESSION UP")
                value: root.fmt(Network.uploadTotal)
                available: root.ratesAvailable
            }
        }
    }
}
