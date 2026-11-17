import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Hornero.PluginKit

// Containers: a read-only roster of Podman and/or Docker containers. One
// `podman ps --all --format json` and/or `docker ps --all --format
// '{{json .}}'` per refresh; nothing is started, stopped, removed or pulled
// from here. When a runtime is missing or its socket is not reachable the
// card says so; it never invents an empty "all quiet" list.
// Note for Docker: access to the Docker socket is itself privileged. This card
// only reads, but the runtime you chose decides what your user may see.
Item {
    id: root

    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Containers")
    readonly property string widgetContext: loaded && !failed ? i18n.tr("%1 RUNNING").arg(runningCount) : ""
    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 380

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-containers"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-containers"
    }

    readonly property string runtimeMode: String(pluginSettings.value("runtime", "auto"))
    readonly property bool showStopped: pluginSettings.value("showStopped", true) !== false
    readonly property bool showPorts: pluginSettings.value("showPorts", true) !== false
    readonly property int maxRows: Math.max(3, Math.min(20, Number(pluginSettings.value("maxRows", 8)) || 8))
    readonly property int refreshSeconds: Math.max(5, Math.min(300, Number(pluginSettings.value("refreshSeconds", 15)) || 15))

    property var all: []
    property bool loaded: false
    property bool failed: false
    property string errorRuntime: ""
    property string buffer: ""
    property var runtimesDone: []
    property bool podmanOk: false
    property bool dockerOk: false

    // CONTAINERS-LOGIC-BEGIN
    function portsText(p) {
        if (!p)
            return "";
        if (typeof p === "string")
            return p;
        if (!Array.isArray(p))
            return "";
        const out = [];
        for (let i = 0; i < p.length && out.length < 4; i++) {
            const x = p[i];
            if (x && x.host_port && x.container_port)
                out.push(x.host_port + "→" + x.container_port);
        }
        return out.join(", ");
    }

    function normalise(o, runtime) {
        let name = o.Names;
        if (Array.isArray(name))
            name = name[0];
        return {
            name: String(name || o.Name || o.ID || "?").replace(/^\//, ""),
            image: String(o.Image || ""),
            state: String(o.State || "").toLowerCase(),
            status: String(o.Status || ""),
            ports: portsText(o.Ports),
            runtime: runtime
        };
    }

    // podman prints one JSON array; docker prints one JSON object per line.
    function parseList(text, runtime) {
        const t = String(text).trim();
        if (t.length === 0)
            return [];
        const out = [];
        if (t.charAt(0) === "[") {
            const arr = JSON.parse(t);
            for (let i = 0; i < arr.length; i++)
                out.push(normalise(arr[i], runtime));
        } else {
            const lines = t.split("\n");
            for (let i = 0; i < lines.length; i++)
                if (lines[i].trim().length > 0)
                    out.push(normalise(JSON.parse(lines[i]), runtime));
        }
        return out;
    }

    function stateRank(s) {
        return s === "running" ? 0 : (s === "restarting" || s === "paused") ? 1 : 2;
    }

    function arrange(list, showStopped, max) {
        const kept = list.filter(c => showStopped || c.state === "running" || c.state === "paused" || c.state === "restarting");
        kept.sort(function (a, b) {
            const d = stateRank(a.state) - stateRank(b.state);
            return d !== 0 ? d : a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
        });
        return kept.slice(0, max);
    }
    // CONTAINERS-LOGIC-END

    readonly property int runningCount: all.filter(c => c.state === "running").length
    readonly property int fitRows: hostAvailableHeight > 0 ? Math.max(1, Math.floor((hostAvailableHeight + 4) / 84)) : maxRows
    readonly property var shownRows: arrange(all, showStopped, Math.min(maxRows, fitRows))
    readonly property bool hidden: all.length > shownRows.length

    property var collected: []
    property int stage: 0

    function refresh(): void {
        if (podmanProc.running || dockerProc.running)
            return;
        collected = [];
        podmanOk = false;
        dockerOk = false;
        stage = 0;
        runStage();
    }

    // stage 0: podman (unless docker-only); stage 1: docker (when asked or as auto fallback); 2: done.
    function runStage(): void {
        if (stage === 0 && runtimeMode !== "docker") {
            buffer = "";
            pendingRuntime = "podman";
            podmanProc.running = true;
            return;
        }
        if (stage <= 1 && (runtimeMode === "docker" || runtimeMode === "both" || (runtimeMode === "auto" && !podmanOk))) {
            stage = 1;
            buffer = "";
            pendingRuntime = "docker";
            dockerProc.running = true;
            return;
        }
        stage = 2;
        all = collected;
        failed = !(podmanOk || dockerOk);
        loaded = true;
    }

    property string pendingRuntime: ""

    Timer {
        id: lostExit

        interval: 400
        onTriggered: {
            if (root.pendingRuntime.length > 0)
                root.consume(root.pendingRuntime, -1);
        }
    }

    function consume(runtime, code): void {
        pendingRuntime = "";
        if (code === 0) {
            try {
                collected = collected.concat(parseList(buffer, runtime));
                if (runtime === "podman")
                    podmanOk = true;
                else
                    dockerOk = true;
            } catch (e) {
            }
        }
        stage = runtime === "podman" ? 1 : 2;
        runStage();
    }

    Process {
        id: podmanProc

        command: ["podman", "ps", "--all", "--format", "json"]

        // A missing executable never reports an exit: treat a stop without
        // one as a failed run so the next runtime (or the error) is reached.
        onRunningChanged: if (!running && root.pendingRuntime === "podman")
            lostExit.restart()

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data + "\n";
            }
        }
        onExited: (code, status) => root.consume("podman", code)
    }

    Process {
        id: dockerProc

        command: ["docker", "ps", "--all", "--format", "{{json .}}"]

        onRunningChanged: if (!running && root.pendingRuntime === "docker")
            lostExit.restart()

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data + "\n";
            }
        }
        onExited: (code, status) => root.consume("docker", code)
    }

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: Theme.experience !== "gaming"
        onTriggered: root.refresh()
    }

    onRuntimeModeChanged: refresh()
    Component.onCompleted: refresh()

    function chipTone(s) {
        return s === "running" ? "phosphor" : (s === "paused" || s === "restarting") ? "cue" : s === "dead" ? "alert" : "neutral";
    }

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller
        Accessible.name: i18n.tr("Containers")

        UiState {
            visible: root.loaded && root.failed
            width: parent.width
            kind: "error"
            message: i18n.tr("No container runtime answered. Install Podman or Docker, or start its service, then pick it in Settings.")
        }

        UiState {
            visible: !root.loaded
            width: parent.width
            kind: "loading"
            message: i18n.tr("Asking the container runtime…")
        }

        UiState {
            visible: root.loaded && !root.failed && root.shownRows.length === 0
            width: parent.width
            kind: "empty"
            glyph: "server"
            message: root.all.length === 0 ? i18n.tr("No containers on this machine.") : i18n.tr("Nothing is running. Stopped containers are hidden.")
        }

        Repeater {
            model: root.failed ? [] : root.shownRows

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property var c: modelData

                width: column.width
                height: body.implicitHeight + Theme.padding.normal * 2
                radius: Theme.rounding.small
                color: Theme.palette.sunken
                border.width: 1
                border.color: Theme.palette.rule
                Accessible.name: i18n.tr("%1, %2").arg(c.name).arg(c.state)

                ColumnLayout {
                    id: body

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.padding.normal
                        rightMargin: Theme.padding.normal
                    }
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.small

                        UiText {
                            Layout.fillWidth: true
                            role: "subtitle"
                            text: c.name
                            elide: Text.ElideRight
                            color: c.state === "running" ? Theme.palette.ink : Theme.palette.inkMuted
                        }

                        UiChip {
                            text: (c.state || "?").toUpperCase()
                            tone: root.chipTone(c.state)
                        }
                    }

                    UiText {
                        Layout.fillWidth: true
                        role: "caption"
                        text: c.image + (c.status.length > 0 ? " · " + c.status : "")
                        elide: Text.ElideRight
                        color: Theme.palette.inkFaint
                    }

                    UiText {
                        Layout.fillWidth: true
                        visible: root.showPorts && c.ports.length > 0
                        role: "value"
                        text: c.ports
                        elide: Text.ElideRight
                        color: Theme.palette.inkMuted
                    }
                }
            }
        }

        UiText {
            visible: root.loaded && !root.failed && root.hidden
            width: parent.width
            role: "caption"
            horizontalAlignment: Text.AlignHCenter
            text: i18n.tr("%1 more not shown").arg(root.all.length - root.shownRows.length)
            color: Theme.palette.inkFaint
        }
    }
}
