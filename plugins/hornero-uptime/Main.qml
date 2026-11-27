import QtQuick
import Hornero.PluginKit

// Uptime bar surface (primary, HorneroOS/plugins#31, #112):
// Reads System.uptimeSeconds from the shared PluginKit `system`
// provider (shell >= 1.3.10, backed by a zero-fork FileView over
// /proc/uptime inside SystemUsage). Holds one `system` lease and
// creates no subprocess or timer. Before a positive reading
// arrives, an explicit unavailable/loading state is shown; a
// fabricated zero is never displayed. Boot time is derived
// arithmetic (now minus uptime).
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

    function bootEpochMs(nowMs, uptimeSeconds) {
        return nowMs - uptimeSeconds * 1000;
    }
    // LOGIC-END

    readonly property int uptimeSeconds: {
        const value = Number(System.uptimeSeconds);
        return isFinite(value) && value > 0 ? Math.floor(value) : 0;
    }
    readonly property bool hasData: uptimeSeconds > 0

    function bootText() {
        if (!hasData)
            return i18n.tr("Unavailable");
        return i18n.formatDateTime(new Date(bootEpochMs(Date.now(), uptimeSeconds)), "yyyy-MM-dd hh:mm");
    }

    // Typed settings: defaults preserve the 1.x bar presentation
    // ("Up" prefix, visible unavailable label when no sample yet).
    readonly property bool showLabel: pluginSettings.value("showLabel", true) !== false
    readonly property bool showWhenUnavailable: pluginSettings.value("showWhenUnavailable", true) !== false
    readonly property bool shown: hasData || showWhenUnavailable
    readonly property string statusText: hasData ? (showLabel ? i18n.tr("Up %1").arg(fmt(uptimeSeconds)) : fmt(uptimeSeconds)) : i18n.tr("Uptime unavailable")

    implicitWidth: shown ? stack.implicitWidth : 0
    implicitHeight: shown ? stack.implicitHeight : 0

    Subscription {
        domain: "system"
    }

    Translations {
        id: i18n

        pluginId: "hornero-uptime"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-uptime"
    }

    UiStack {
        id: stack

        visible: root.shown
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator

            variant: "quiet"
            glyph: "clock"
            text: root.hostCompact || root.hostOrientation === "vertical" ? "" : root.statusText
            tooltipText: root.statusText
            accessibleName: i18n.tr("Uptime details")
            onClicked: popover.toggle()
        }
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Uptime details")

        Column {
            width: 300
            spacing: Theme.spacing.small

            UiText {
                role: "title"
                text: i18n.tr("Uptime")
            }

            UiState {
                visible: !root.hasData
                width: parent.width
                kind: "loading"
                message: i18n.tr("Waiting for uptime from the system provider. No value is fabricated.")
            }

            Column {
                visible: root.hasData
                width: parent.width
                spacing: Theme.spacing.small

                UiMetric {
                    size: "value"
                    label: i18n.tr("Uptime")
                    value: root.fmt(root.uptimeSeconds)
                }

                UiMetric {
                    size: "value"
                    label: i18n.tr("Booted at")
                    value: root.bootText()
                }

                UiText {
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Boot time is derived from live uptime reported by the shell.")
                }
            }
        }
    }
}
