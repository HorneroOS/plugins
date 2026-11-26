import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Hornero.PluginKit

// Hornero Tailscale: dashboard card showing Tailscale VPN state, tailnet IP,
// active exit node, online peers, and a connect/disconnect toggle.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property int contentWidth: hostAvailableWidth > 0 ? Math.min(400, hostAvailableWidth) : 340

    implicitWidth: contentWidth
    implicitHeight: card.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-tailscale"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-tailscale"
    }

    readonly property int refreshSeconds: Math.max(5, Math.min(300, Number(pluginSettings.value("refreshSeconds", 15)) || 15))
    readonly property bool showPeers: pluginSettings.value("showPeers", true) !== false
    readonly property int maxPeers: Math.max(1, Math.min(20, Number(pluginSettings.value("maxPeers", 6)) || 6))

    property bool loaded: false
    property bool failed: false
    property bool busy: false
    property string backendState: ""
    property string selfName: ""
    property string selfIp: ""
    property string tailnetName: ""
    property string exitNodeName: ""
    property var onlinePeers: []
    property int totalPeers: 0
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
        selfName = String(self.HostName || "");
        const ips = Array.isArray(self.TailscaleIPs) ? self.TailscaleIPs : [];
        selfIp = ips.length > 0 ? String(ips[0]) : "";
        const net = data.CurrentTailnet || {};
        tailnetName = String(net.Name || "");

        let activeExit = "";
        const peers = [];
        let count = 0;
        const peerMap = data.Peer || {};
        const keys = Object.keys(peerMap);
        for (let i = 0; i < keys.length; i++) {
            const p = peerMap[keys[i]];
            if (!p)
                continue;
            count += 1;
            const pName = String(p.HostName || p.DNSName || keys[i]).replace(/\.$/, "");
            if (p.ExitNode)
                activeExit = pName;
            if (p.Online) {
                const pIps = Array.isArray(p.TailscaleIPs) ? p.TailscaleIPs : [];
                peers.push({
                    name: pName,
                    ip: pIps.length > 0 ? String(pIps[0]) : "",
                    exitNode: Boolean(p.ExitNode)
                });
            }
        }
        peers.sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
        exitNodeName = activeExit;
        onlinePeers = peers;
        totalPeers = count;
        return true;
    }

    function stateLabel() {
        if (backendState === "Running")
            return i18n.tr("Connected");
        if (backendState === "Stopped")
            return i18n.tr("Stopped");
        if (backendState === "NeedsLogin")
            return i18n.tr("Needs login");
        return i18n.tr("Offline");
    }

    function stateTone() {
        if (backendState === "Running")
            return "phosphor";
        if (backendState === "NeedsLogin")
            return "cue";
        return "neutral";
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
            if (code === 0 && root.parseStatus(root.buffer)) {
                root.failed = false;
            } else {
                root.failed = true;
            }
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

    UiCard {
        id: card

        title: i18n.tr("Tailscale")
        channel: 12
        anchors.fill: parent
        Accessible.name: i18n.tr("Tailscale")

        Column {
            width: parent.width
            spacing: Theme.spacing.small

            UiState {
                visible: !root.loaded
                width: parent.width
                kind: "loading"
                message: i18n.tr("Checking Tailscale status…")
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

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacing.small

                    UiChip {
                        text: root.stateLabel().toUpperCase()
                        tone: root.stateTone()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    UiButton {
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

                UiDetailRow {
                    width: parent.width
                    visible: root.tailnetName.length > 0
                    label: i18n.tr("Tailnet")
                    value: root.tailnetName
                }

                UiDetailRow {
                    width: parent.width
                    visible: root.selfIp.length > 0
                    label: i18n.tr("This device")
                    value: root.selfName.length > 0 ? root.selfName + " · " + root.selfIp : root.selfIp
                }

                UiDetailRow {
                    width: parent.width
                    label: i18n.tr("Exit node")
                    value: root.exitNodeName.length > 0 ? root.exitNodeName : i18n.tr("None")
                }

                UiDetailRow {
                    width: parent.width
                    label: i18n.tr("Peers online")
                    value: i18n.tr("%1 of %2").arg(root.onlinePeers.length).arg(root.totalPeers)
                }

                Repeater {
                    model: root.showPeers ? root.onlinePeers.slice(0, root.maxPeers) : []

                    delegate: UiDetailRow {
                        required property var modelData

                        width: parent.width
                        label: modelData.name + (modelData.exitNode ? " · " + i18n.tr("Exit") : "")
                        value: modelData.ip
                    }
                }
            }
        }
    }
}
