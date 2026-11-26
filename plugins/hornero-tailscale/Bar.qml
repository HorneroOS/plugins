import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Hornero.PluginKit

// Hornero Tailscale bar pill: compact VPN status indicator with a popover for
// active exit node, tailnet IP, peer summary, and connect/disconnect toggle.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property string hostEdge: "top"
    property string hostSurface: "bar"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: indicator.implicitWidth
    implicitHeight: indicator.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-tailscale"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-tailscale"
    }

    readonly property int refreshSeconds: Math.max(5, Math.min(300, Number(pluginSettings.value("refreshSeconds", 15)) || 15))

    property bool loaded: false
    property bool failed: false
    property bool busy: false
    property string backendState: ""
    property string selfIp: ""
    property string exitNodeName: ""
    property int onlineCount: 0
    property int totalCount: 0
    property string buffer: ""

    readonly property bool isConnected: backendState === "Running"

    function parseStatus(text) {
        const raw = String(text || "").trim();
        if (raw.length === 0)
            return false;
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            return false;
        }
        if (!data || typeof data !== "object")
            return false;

        backendState = String(data.BackendState || "Unknown");
        const self = data.Self || {};
        const ips = Array.isArray(self.TailscaleIPs) ? self.TailscaleIPs : [];
        selfIp = ips.length > 0 ? String(ips[0]) : "";

        let activeExit = "";
        let online = 0;
        let total = 0;
        const peerMap = data.Peer || {};
        const keys = Object.keys(peerMap);
        for (let i = 0; i < keys.length; i++) {
            const p = peerMap[keys[i]];
            if (!p)
                continue;
            total += 1;
            if (p.Online)
                online += 1;
            if (p.ExitNode)
                activeExit = String(p.HostName || p.DNSName || keys[i]).replace(/\.$/, "");
        }
        exitNodeName = activeExit;
        onlineCount = online;
        totalCount = total;
        return true;
    }

    function refresh(): void {
        if (statusProc.running || toggleProc.running)
            return;
        buffer = "";
        statusProc.running = true;
    }

    function toggleConnection(): void {
        if (toggleProc.running || failed)
            return;
        busy = true;
        toggleProc.command = isConnected ? ["tailscale", "down"] : ["tailscale", "up"];
        toggleProc.running = true;
    }

    Process {
        id: statusProc

        command: ["tailscale", "status", "--json"]
        stdout: SplitParser {
            onRead: data => {
                root.buffer += data + "\n";
            }
        }
        onExited: (code, status) => {
            root.failed = !(code === 0 && root.parseStatus(root.buffer));
            root.loaded = true;
        }
    }

    Process {
        id: toggleProc

        command: ["tailscale", "up"]
        onExited: (code, status) => {
            root.busy = false;
            root.refresh();
        }
    }

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: Theme.experience !== "gaming"
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    UiButton {
        id: indicator

        variant: "quiet"
        glyph: root.isConnected ? "shield-lock" : "shield"
        text: root.hostCompact ? "" : (root.failed ? i18n.tr("VPN") : root.isConnected ? (root.exitNodeName.length > 0 ? root.exitNodeName : i18n.tr("VPN On")) : i18n.tr("VPN Off"))
        tooltipText: popover.opened ? "" : (root.isConnected ? i18n.tr("Tailscale connected") : i18n.tr("Tailscale disconnected"))
        accessibleName: root.isConnected ? i18n.tr("Tailscale connected") : i18n.tr("Tailscale disconnected")
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Tailscale")

        Column {
            width: 300
            spacing: Theme.spacing.normal

            UiText {
                role: "subtitle"
                text: i18n.tr("Tailscale")
            }

            UiState {
                visible: root.loaded && root.failed
                width: parent.width
                kind: "error"
                message: i18n.tr("Tailscale did not answer. Install tailscale and start tailscaled.")
            }

            Column {
                visible: root.loaded && !root.failed
                width: parent.width
                spacing: Theme.spacing.small

                UiDetailRow {
                    width: parent.width
                    label: i18n.tr("Status")
                    value: root.isConnected ? i18n.tr("Connected") : i18n.tr("Disconnected")
                }

                UiDetailRow {
                    width: parent.width
                    visible: root.selfIp.length > 0
                    label: i18n.tr("Tailscale IP")
                    value: root.selfIp
                }

                UiDetailRow {
                    width: parent.width
                    label: i18n.tr("Exit node")
                    value: root.exitNodeName.length > 0 ? root.exitNodeName : i18n.tr("None")
                }

                UiDetailRow {
                    width: parent.width
                    label: i18n.tr("Peers online")
                    value: i18n.tr("%1 of %2").arg(root.onlineCount).arg(root.totalCount)
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacing.small

                    UiButton {
                        Layout.fillWidth: true
                        variant: root.isConnected ? "quiet" : "primary"
                        text: root.isConnected ? i18n.tr("Disconnect") : i18n.tr("Connect")
                        enabled: !root.busy
                        tooltipText: root.isConnected ? i18n.tr("Disconnect from Tailscale") : i18n.tr("Connect to Tailscale")
                        accessibleName: root.isConnected ? i18n.tr("Disconnect from Tailscale") : i18n.tr("Connect to Tailscale")
                        onClicked: root.toggleConnection()
                    }

                    UiButton {
                        variant: "quiet"
                        glyph: "refresh"
                        tooltipText: i18n.tr("Refresh Tailscale status")
                        accessibleName: i18n.tr("Refresh Tailscale status")
                        onClicked: root.refresh()
                    }
                }
            }
        }
    }
}
