import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Hornero.PluginKit

// Port Watch: what is listening on this machine, and what is free. Data is
// one `ss -H -tulnp` run per refresh (read-only socket table of the kernel).
// Rows merge IPv4/IPv6 for the same protocol and port, show how far the bind
// reaches (this machine only, one interface, or every interface) and, when
// the kernel lets an unprivileged user see it, the owning process name. A
// socket owned by another user has no process name: it is shown as such,
// never guessed. Optional watched ports stay listed as "free" when nothing
// listens, which answers "is :5173 taken?" at a glance.
Item {
    id: root

    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Port Watch")
    readonly property string widgetContext: rows.length > 0 ? i18n.tr("%1 LISTENING").arg(listeningCount) : ""
    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 380

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-port-watch"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-port-watch"
    }

    readonly property string protocolMode: String(pluginSettings.value("protocols", "tcp"))
    readonly property string scopeMode: String(pluginSettings.value("scope", "all"))
    readonly property int maxRows: Math.max(3, Math.min(30, Number(pluginSettings.value("maxRows", 10)) || 10))
    readonly property int refreshSeconds: Math.max(2, Math.min(120, Number(pluginSettings.value("refreshSeconds", 10)) || 10))
    readonly property string watchSetting: String(pluginSettings.value("watchedPorts", ""))
    readonly property bool showProcess: pluginSettings.value("showProcess", true) !== false

    property var rows: []
    property bool failed: false
    property bool loaded: false
    property string buffer: ""
    readonly property int listeningCount: rows.filter(r => r.listening).length

    // PORTS-LOGIC-BEGIN
    function splitAddr(text) {
        const i = String(text).lastIndexOf(":");
        if (i < 0)
            return null;
        let addr = text.slice(0, i);
        const port = parseInt(text.slice(i + 1), 10);
        if (!isFinite(port) || port < 1 || port > 65535)
            return null;
        const pct = addr.indexOf("%");
        if (pct >= 0)
            addr = addr.slice(0, pct) + (addr.charAt(addr.length - 1) === "]" ? "]" : "");
        return {
            addr: addr,
            port: port
        };
    }

    // 0 = this machine only, 1 = one interface, 2 = every interface.
    function reach(addr) {
        if (addr === "*" || addr === "0.0.0.0" || addr === "[::]")
            return 2;
        if (addr.indexOf("127.") === 0 || addr === "[::1]")
            return 0;
        return 1;
    }

    function parseSockets(text) {
        const map = {};
        const lines = String(text).split("\n");
        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].trim().split(/\s+/);
            if (f.length < 5)
                continue;
            const proto = f[0];
            if (proto !== "tcp" && proto !== "udp")
                continue;
            const state = f[1];
            if (proto === "tcp" && state !== "LISTEN")
                continue;
            const local = splitAddr(f[4]);
            if (!local)
                continue;
            const m = /\(\("([^"]*)",pid=(\d+)/.exec(lines[i]);
            const key = proto + ":" + local.port;
            const r = reach(local.addr);
            if (!map[key])
                map[key] = {
                    proto: proto,
                    port: local.port,
                    reach: r,
                    process: m ? m[1] : "",
                    pid: m ? parseInt(m[2], 10) : 0,
                    listening: true
                };
            else {
                if (r > map[key].reach)
                    map[key].reach = r;
                if (!map[key].process && m) {
                    map[key].process = m[1];
                    map[key].pid = parseInt(m[2], 10);
                }
            }
        }
        const out = [];
        for (const k in map)
            out.push(map[k]);
        return out;
    }

    function parseWatch(text) {
        const out = [];
        const parts = String(text).split(/[\s,;]+/);
        for (let i = 0; i < parts.length && out.length < 12; i++) {
            if (!/^\d{1,5}$/.test(parts[i]))
                continue;
            const n = parseInt(parts[i], 10);
            if (n >= 1 && n <= 65535 && out.indexOf(n) < 0)
                out.push(n);
        }
        return out;
    }

    function compose(sockets, watched, protoMode, scopeMode, max) {
        let rows = sockets.filter(function (s) {
            if (protoMode !== "both" && s.proto !== protoMode)
                return false;
            if (scopeMode === "exposed" && s.reach < 2)
                return false;
            if (scopeMode === "local" && s.reach > 0)
                return false;
            return true;
        });
        const present = {};
        for (let i = 0; i < sockets.length; i++)
            present[sockets[i].port] = true;
        for (let i = 0; i < watched.length; i++) {
            if (!present[watched[i]])
                rows.push({
                    proto: protoMode === "udp" ? "udp" : "tcp",
                    port: watched[i],
                    reach: 0,
                    process: "",
                    pid: 0,
                    listening: false
                });
        }
        rows.sort(function (a, b) {
            const wa = watched.indexOf(a.port) >= 0 ? 0 : 1;
            const wb = watched.indexOf(b.port) >= 0 ? 0 : 1;
            if (wa !== wb)
                return wa - wb;
            return a.port - b.port || (a.proto < b.proto ? -1 : 1);
        });
        return rows.slice(0, max);
    }
    // PORTS-LOGIC-END

    property var sockets: []
    readonly property var watched: parseWatch(watchSetting)
    readonly property var shownRows: compose(sockets, watched, protocolMode, scopeMode, maxRows)

    function refresh(): void {
        if (!proc.running) {
            buffer = "";
            proc.running = true;
        }
    }

    Process {
        id: proc

        command: ["ss", "-H", "-tulnp"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data + "\n";
            }
        }
        onExited: (code, status) => {
            root.loaded = true;
            if (code === 0) {
                root.sockets = root.parseSockets(root.buffer);
                root.failed = false;
            } else {
                root.failed = true;
            }
            root.rows = root.shownRows;
        }
    }

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: Theme.experience !== "gaming"
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    function reachText(r) {
        return r.reach === 2 ? i18n.tr("EXPOSED") : r.reach === 1 ? i18n.tr("LAN") : i18n.tr("LOCAL");
    }

    function reachTone(r) {
        return r.reach === 2 ? "signal" : r.reach === 1 ? "cue" : "phosphor";
    }

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller
        Accessible.name: i18n.tr("Port Watch")

        UiState {
            visible: root.failed
            width: parent.width
            kind: "error"
            message: i18n.tr("The socket table could not be read (is `ss` installed?).")
        }

        UiState {
            visible: !root.failed && !root.loaded
            width: parent.width
            kind: "loading"
            message: i18n.tr("Reading the socket table…")
        }

        UiState {
            visible: !root.failed && root.loaded && root.shownRows.length === 0
            width: parent.width
            kind: "empty"
            glyph: "plug-off"
            message: i18n.tr("Nothing is listening with these filters.")
        }

        Repeater {
            model: root.failed ? [] : root.shownRows

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property var s: modelData

                width: column.width
                height: line.implicitHeight + Theme.padding.normal * 2
                radius: Theme.rounding.small
                color: Theme.palette.sunken
                border.width: 1
                border.color: Theme.palette.rule
                Accessible.name: s.listening ? i18n.tr("Port %1 %2, %3").arg(s.port).arg(s.proto).arg(root.reachText(s)) : i18n.tr("Port %1 is free").arg(s.port)

                RowLayout {
                    id: line

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.padding.normal
                        rightMargin: Theme.padding.normal
                    }
                    spacing: Theme.spacing.normal

                    UiText {
                        Layout.preferredWidth: 64
                        role: "value"
                        text: String(s.port)
                        color: s.listening ? Theme.palette.ink : Theme.palette.inkFaint
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        UiText {
                            Layout.fillWidth: true
                            role: "body"
                            elide: Text.ElideRight
                            text: !s.listening ? i18n.tr("free") : (root.showProcess ? (s.process.length > 0 ? s.process : i18n.tr("owner not visible")) : s.proto.toUpperCase())
                            color: s.listening ? Theme.palette.ink : Theme.palette.inkFaint
                        }

                        UiText {
                            visible: s.listening
                            Layout.fillWidth: true
                            role: "caption"
                            text: s.proto + (root.showProcess && s.pid > 0 ? " · pid " + s.pid : "")
                            color: Theme.palette.inkFaint
                        }
                    }

                    UiChip {
                        visible: s.listening
                        text: root.reachText(s)
                        tone: root.reachTone(s)
                    }
                }
            }
        }
    }
}
