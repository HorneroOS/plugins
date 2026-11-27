import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Hornero.PluginKit

// Git Board: a read-only status board for the repositories you name.
// Per repository: branch, ahead/behind of its upstream, staged / modified /
// untracked / conflicted counts and the last commit. Data comes only from
// `git status --porcelain=v2 --branch` and `git log -1`, run one repository
// at a time with `--no-optional-locks` and `core.fsmonitor=false`, so reading
// the board never writes to a repository and never runs a repository-defined
// monitor hook. It never fetches, pulls, pushes or commits: no network.
// A path git cannot read is shown as an error row, never as "clean".
Item {
    id: root

    // Host context: dashboard cards and desktop widgets inject these.
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Git Board")
    readonly property string widgetContext: summary

    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 380

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-git-board"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-git-board"
    }

    readonly property string repoSetting: String(pluginSettings.value("repositories", ""))
    readonly property int maxRepos: Math.max(1, Math.min(8, Number(pluginSettings.value("maxRepositories", 5)) || 5))
    readonly property int refreshSeconds: Math.max(10, Math.min(600, Number(pluginSettings.value("refreshSeconds", 30)) || 30))
    readonly property bool showLastCommit: pluginSettings.value("showLastCommit", true) !== false
    readonly property string sortMode: String(pluginSettings.value("sortBy", "attention"))
    readonly property bool showClean: pluginSettings.value("showCleanDetails", true) !== false

    property var rows: []
    property var queue: []
    property var current: null
    property string buffer: ""
    property bool scanning: false

    // GIT-LOGIC-BEGIN
    function splitRepos(text, max) {
        const out = [];
        const seen = {};
        const parts = String(text).split(/[;\n]/);
        for (let i = 0; i < parts.length && out.length < max; i++) {
            let p = parts[i].trim();
            while (p.length > 1 && p.charAt(p.length - 1) === "/")
                p = p.slice(0, -1);
            if (p.length < 2 || p.charAt(0) !== "/" || /[\u0000-\u001f]/.test(p) || p.indexOf("..") >= 0)
                continue;
            if (seen[p])
                continue;
            seen[p] = true;
            out.push(p);
        }
        return out;
    }

    function baseName(path) {
        const parts = String(path).split("/");
        return parts[parts.length - 1] || String(path);
    }

    function parseStatus(text) {
        const r = {
            branch: "",
            upstream: "",
            ahead: 0,
            behind: 0,
            hasAb: false,
            staged: 0,
            modified: 0,
            untracked: 0,
            conflicted: 0
        };
        const lines = String(text).split("\n");
        for (let i = 0; i < lines.length; i++) {
            const l = lines[i];
            if (l.length === 0)
                continue;
            if (l.indexOf("# branch.head ") === 0) {
                r.branch = l.slice(14);
            } else if (l.indexOf("# branch.upstream ") === 0) {
                r.upstream = l.slice(18);
            } else if (l.indexOf("# branch.ab ") === 0) {
                const m = /^# branch\.ab \+(\d+) -(\d+)$/.exec(l);
                if (m) {
                    r.ahead = parseInt(m[1], 10);
                    r.behind = parseInt(m[2], 10);
                    r.hasAb = true;
                }
            } else if (l.charAt(0) === "1" || l.charAt(0) === "2") {
                const xy = l.slice(2, 4);
                if (xy.charAt(0) !== ".")
                    r.staged++;
                if (xy.charAt(1) !== ".")
                    r.modified++;
            } else if (l.charAt(0) === "u") {
                r.conflicted++;
            } else if (l.charAt(0) === "?") {
                r.untracked++;
            }
        }
        return r;
    }

    function dirtyCount(r) {
        return r.staged + r.modified + r.untracked + r.conflicted;
    }

    // Lower rank = needs attention sooner.
    function attentionRank(r) {
        if (r.error)
            return 0;
        if (r.conflicted > 0)
            return 1;
        if (dirtyCount(r) > 0)
            return 2;
        if (r.behind > 0 || r.ahead > 0)
            return 3;
        return 4;
    }

    function sortRows(list, mode) {
        const copy = list.slice();
        copy.sort(function (a, b) {
            if (mode === "attention") {
                const d = attentionRank(a) - attentionRank(b);
                if (d !== 0)
                    return d;
            }
            return a.path < b.path ? -1 : a.path > b.path ? 1 : 0;
        });
        return copy;
    }
    // GIT-LOGIC-END

    // A fixed-height desktop frame holds about 90 px per repository row.
    readonly property int fitRows: hostAvailableHeight > 0 ? Math.max(1, Math.floor(hostAvailableHeight / 90)) : 99
    readonly property var shownRows: sortRows(rows, sortMode).slice(0, fitRows)
    readonly property int hiddenCount: rows.length - shownRows.length

    readonly property string summary: {
        if (rows.length === 0)
            return "";
        let attention = 0;
        for (let i = 0; i < rows.length; i++)
            if (attentionRank(rows[i]) < 4)
                attention++;
        return attention === 0 ? i18n.tr("ALL TIDY") : i18n.tr("%1 NEED YOU").arg(attention);
    }

    function refresh(): void {
        if (scanning)
            return;
        const repos = splitRepos(repoSetting, maxRepos);
        if (repos.length === 0) {
            rows = [];
            return;
        }
        scanning = true;
        queue = repos;
        collected = [];
        next();
    }

    property var collected: []

    function next(): void {
        if (queue.length === 0) {
            rows = collected;
            scanning = false;
            return;
        }
        current = {
            path: queue[0]
        };
        queue = queue.slice(1);
        buffer = "";
        statusProc.running = true;
    }

    function finish(entry): void {
        collected = collected.concat([entry]);
        next();
    }

    Process {
        id: statusProc

        command: ["git", "-c", "core.fsmonitor=false", "--no-optional-locks", "-C", root.current ? root.current.path : "/", "status", "--porcelain=v2", "--branch", "--untracked-files=normal"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data + "\n";
            }
        }
        onExited: (code, status) => {
            const path = root.current.path;
            if (code !== 0) {
                const failedEntry = root.parseStatus("");
                failedEntry.path = path;
                failedEntry.name = root.baseName(path);
                failedEntry.error = true;
                failedEntry.commit = "";
                failedEntry.when = "";
                root.finish(failedEntry);
                return;
            }
            const entry = root.parseStatus(root.buffer);
            entry.path = path;
            entry.name = root.baseName(path);
            entry.error = false;
            entry.commit = "";
            entry.when = "";
            if (root.showLastCommit) {
                root.pending = entry;
                root.buffer = "";
                logProc.running = true;
            } else {
                root.finish(entry);
            }
        }
    }

    property var pending: null

    Process {
        id: logProc

        command: ["git", "-c", "core.fsmonitor=false", "--no-optional-locks", "-C", root.current ? root.current.path : "/", "log", "-1", "--format=%s%x09%cr"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data + "\n";
            }
        }
        onExited: (code, status) => {
            const entry = root.pending;
            if (code === 0) {
                const parts = root.buffer.trim().split("\t");
                entry.commit = parts[0] || "";
                entry.when = parts[1] || "";
            }
            root.finish(entry);
        }
    }

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: root.visible && root.repoSetting.length > 0 && Theme.experience !== "gaming"
        onTriggered: root.refresh()
    }

    onVisibleChanged: if (visible && root.repoSetting.length > 0 && Theme.experience !== "gaming")
        refresh()

    // Re-scan when the repository list changes.
    onRepoSettingChanged: refreshDelay.restart()
    onMaxReposChanged: refreshDelay.restart()
    onShowLastCommitChanged: refreshDelay.restart()

    Timer {
        id: refreshDelay

        interval: 1000
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    function chipTone(r) {
        return r.error ? "alert" : r.conflicted > 0 ? "alert" : dirtyCount(r) > 0 ? "signal" : (r.ahead > 0 || r.behind > 0) ? "cue" : "phosphor";
    }

    function chipText(r) {
        if (r.error)
            return i18n.tr("UNREADABLE");
        if (r.conflicted > 0)
            return i18n.tr("CONFLICT");
        if (dirtyCount(r) > 0)
            return i18n.tr("DIRTY");
        if (r.behind > 0)
            return i18n.tr("BEHIND");
        if (r.ahead > 0)
            return i18n.tr("AHEAD");
        return i18n.tr("CLEAN");
    }

    function detail(r) {
        const bits = [];
        if (r.staged > 0)
            bits.push(i18n.tr("%1 staged").arg(r.staged));
        if (r.modified > 0)
            bits.push(i18n.tr("%1 changed").arg(r.modified));
        if (r.untracked > 0)
            bits.push(i18n.tr("%1 new").arg(r.untracked));
        if (r.conflicted > 0)
            bits.push(i18n.tr("%1 conflicted").arg(r.conflicted));
        return bits.join(" · ");
    }

    function branchLine(r) {
        let s = r.branch === "(detached)" ? i18n.tr("detached HEAD") : r.branch;
        if (r.hasAb && (r.ahead > 0 || r.behind > 0))
            s += "  ↑" + r.ahead + " ↓" + r.behind;
        else if (r.upstream.length === 0 && r.branch !== "(detached)")
            s += "  " + i18n.tr("(no upstream)");
        return s;
    }

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.small
        Accessible.name: i18n.tr("Git Board")

        UiState {
            visible: root.repoSetting.trim().length === 0
            width: parent.width
            kind: "empty"
            glyph: "code"
            message: i18n.tr("Add absolute repository paths in Settings, separated by semicolons. Nothing is scanned until you do.")
        }

        UiState {
            visible: root.repoSetting.trim().length > 0 && root.rows.length === 0 && root.scanning
            width: parent.width
            kind: "loading"
            message: i18n.tr("Reading repositories…")
        }

        UiState {
            visible: root.repoSetting.trim().length > 0 && root.splitRepos(root.repoSetting, 8).length === 0
            width: parent.width
            kind: "error"
            message: i18n.tr("No usable path: use absolute paths such as /home/you/code/project.")
        }

        Repeater {
            model: root.shownRows

            delegate: Item {
                id: card

                required property var modelData
                readonly property var repo: modelData
                readonly property string detailText: root.detail(repo)

                width: column.width
                height: body.implicitHeight + Theme.padding.normal * 2
                Accessible.name: repo.error ? i18n.tr("%1: unreadable").arg(repo.name) : i18n.tr("%1 on %2, %3").arg(repo.name).arg(repo.branch).arg(root.chipText(repo))

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rounding.small
                    color: Theme.palette.sunken
                    border.width: 1
                    border.color: Theme.palette.rule
                }

                // Left accent rail carries the state colour; warm, not loud.
                Rectangle {
                    width: 2
                    radius: 1
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        margins: 6
                    }
                    color: repo.error || repo.conflicted > 0 ? Theme.palette.alert : root.dirtyCount(repo) > 0 ? Theme.palette.signal : (repo.ahead > 0 || repo.behind > 0) ? Theme.palette.cue : Theme.palette.phosphor
                    opacity: 0.85
                }

                ColumnLayout {
                    id: body

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: Theme.padding.normal + 6
                        rightMargin: Theme.padding.normal
                        topMargin: Theme.padding.normal
                    }
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.small

                        UiText {
                            Layout.fillWidth: true
                            role: "subtitle"
                            text: repo.name
                            elide: Text.ElideRight
                        }

                        UiChip {
                            text: root.chipText(repo)
                            tone: root.chipTone(repo)
                        }
                    }

                    UiText {
                        Layout.fillWidth: true
                        visible: !repo.error
                        role: "value"
                        text: root.branchLine(repo)
                        elide: Text.ElideRight
                        color: Theme.palette.inkMuted
                    }

                    UiText {
                        Layout.fillWidth: true
                        visible: repo.error
                        role: "caption"
                        text: i18n.tr("git could not read %1 (missing, not a repository, or not trusted by git).").arg(repo.path)
                        wrapMode: Text.WordWrap
                    }

                    UiText {
                        Layout.fillWidth: true
                        visible: !repo.error && card.detailText.length > 0
                        role: "caption"
                        text: card.detailText
                        elide: Text.ElideRight
                    }

                    UiText {
                        Layout.fillWidth: true
                        visible: !repo.error && root.showLastCommit && repo.commit.length > 0 && (root.showClean || card.detailText.length > 0)
                        role: "caption"
                        text: repo.commit + (repo.when.length > 0 ? " · " + repo.when : "")
                        elide: Text.ElideRight
                        color: Theme.palette.inkFaint
                    }
                }
            }
        }

        UiText {
            visible: root.rows.length > 0 && root.summary === i18n.tr("ALL TIDY")
            width: parent.width
            role: "caption"
            horizontalAlignment: Text.AlignHCenter
            text: i18n.tr("Everything is committed and in step. Cosy.")
            color: Theme.palette.inkFaint
        }

        UiText {
            visible: root.hiddenCount > 0
            width: parent.width
            role: "caption"
            horizontalAlignment: Text.AlignHCenter
            text: i18n.tr("%1 more not shown").arg(root.hiddenCount)
            color: Theme.palette.inkFaint
        }
    }
}
