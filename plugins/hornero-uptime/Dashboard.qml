import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Uptime dashboard surface (HorneroOS/plugins#31, #112): the card
// form of the bar popover. Holds a shared `system` provider lease
// and reads System.uptimeSeconds reactively with no subprocess or
// timer. See Main.qml for the honest unavailable contract.
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

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    Subscription {
        domain: "system"
    }

    Translations {
        id: i18n

        pluginId: "hornero-uptime"
    }

    UiCard {
        id: card

        anchors.fill: parent
        title: i18n.tr("Uptime")
        channel: 9
        Accessible.name: i18n.tr("Uptime")

        Column {
            width: parent.width
            spacing: Theme.spacing.small

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

                UiStack {
                    width: parent.width
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        size: "value"
                        label: i18n.tr("Uptime")
                        value: root.fmt(root.uptimeSeconds)
                    }

                    UiMetric {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        size: "value"
                        label: i18n.tr("Booted at")
                        value: root.bootText()
                    }
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
