import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Hornero.PluginKit

// Forge Board: CI and pull-request status for the GitHub repositories you
// name. For each repository it runs two read-only `gh` queries: the latest
// workflow run on the default branch and your open pull requests with their
// check state.
//
// Credentials: this extension stores and sees no token. It relies on the
// session of the `gh` CLI you already authenticated yourself (`gh auth
// login`), exactly as if you ran `gh` in a terminal; if `gh` is missing or
// signed out the card says so. It never writes (no comments, merges, reruns).
// Network: api.github.com through `gh`, only while the card is loaded, at the
// refresh interval you choose, and not in the Gaming experience.
Item {
    id: root

    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Forge Board")
    readonly property string widgetContext: summary
    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 380

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-forge-board"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-forge-board"
    }

    readonly property string repoSetting: String(pluginSettings.value("repositories", ""))
    readonly property int maxRepos: Math.max(1, Math.min(6, Number(pluginSettings.value("maxRepositories", 4)) || 4))
    readonly property int refreshMinutes: Math.max(2, Math.min(60, Number(pluginSettings.value("refreshMinutes", 5)) || 5))
    readonly property bool showPullRequests: pluginSettings.value("showPullRequests", true) !== false
    readonly property int maxPullRequests: Math.max(1, Math.min(5, Number(pluginSettings.value("maxPullRequests", 3)) || 3))

    property var rows: []
    property var collected: []
    property var queue: []
    property var current: null
    property string buffer: ""
    property string pendingStep: ""
    property bool loaded: false
    property bool authProblem: false
    property bool missingGh: false

    // FORGE-LOGIC-BEGIN
    function splitRepos(text, max) {
        var out = [];
        var parts = String(text).split(/[;,\n\s]+/);
        for (var i = 0; i < parts.length && out.length < max; i++) {
            var p = parts[i].trim();
            if (/^[A-Za-z0-9][A-Za-z0-9-]{0,38}\/[A-Za-z0-9._-]{1,100}$/.test(p) && out.indexOf(p) < 0)
                out.push(p);
        }
        return out;
    }

    // Latest run -> {state, title, branch}; state: pass, fail, running, none.
    function parseRun(text) {
        var arr;
        try { arr = JSON.parse(String(text)); } catch (e) { return { "state": "unknown" }; }
        if (!Array.isArray(arr) || arr.length === 0) return { "state": "none" };
        var r = arr[0];
        var state = r.status !== "completed" ? "running" : r.conclusion === "success" ? "pass" : (r.conclusion === "skipped" || r.conclusion === "neutral" || r.conclusion === "cancelled") ? "none" : "fail";
        return { "state": state, "title": String(r.displayTitle || r.name || ""), "branch": String(r.headBranch || "") };
    }

    // Roll a statusCheckRollup array up to one state.
    function checkState(rollup) {
        if (!Array.isArray(rollup) || rollup.length === 0) return "none";
        var pending = false;
        for (var i = 0; i < rollup.length; i++) {
            var c = rollup[i];
            var s = c.conclusion || c.state || "";
            if (c.status && c.status !== "COMPLETED") { pending = true; continue; }
            if (s === "FAILURE" || s === "ERROR" || s === "TIMED_OUT" || s === "ACTION_REQUIRED" || s === "STARTUP_FAILURE") return "fail";
            if (s === "PENDING" || s === "EXPECTED") pending = true;
        }
        return pending ? "running" : "pass";
    }

    function parsePrs(text, max) {
        var arr;
        try { arr = JSON.parse(String(text)); } catch (e) { return []; }
        if (!Array.isArray(arr)) return [];
        var out = [];
        for (var i = 0; i < arr.length && out.length < max; i++) {
            var p = arr[i];
            out.push({
                "number": p.number,
                "title": String(p.title || ""),
                "draft": p.isDraft === true,
                "review": String(p.reviewDecision || ""),
                "checks": checkState(p.statusCheckRollup)
            });
        }
        return out;
    }

    function worst(states) {
        var rank = { "fail": 0, "running": 1, "unknown": 2, "none": 3, "pass": 4 };
        var best = "pass";
        for (var i = 0; i < states.length; i++)
            if ((rank[states[i]] === undefined ? 2 : rank[states[i]]) < rank[best]) best = states[i];
        return best;
    }
    // FORGE-LOGIC-END

    readonly property string summary: {
        if (!loaded || rows.length === 0)
            return "";
        if (missingGh || authProblem)
            return "";
        const w = worst(rows.map(r => r.run.state));
        return w === "fail" ? i18n.tr("CI FAILING") : w === "running" ? i18n.tr("CI RUNNING") : w === "pass" ? i18n.tr("CI GREEN") : "";
    }

    function refresh(): void {
        if (queue.length > 0 || runProc.running || prProc.running)
            return;
        const repos = splitRepos(repoSetting, maxRepos);
        collected = [];
        authProblem = false;
        missingGh = false;
        if (repos.length === 0) {
            rows = [];
            loaded = true;
            return;
        }
        queue = repos;
        next();
    }

    function next(): void {
        if (queue.length === 0) {
            rows = collected;
            loaded = true;
            return;
        }
        current = {
            repo: queue[0],
            run: {
                state: "unknown"
            },
            prs: []
        };
        queue = queue.slice(1);
        buffer = "";
        pendingStep = "run";
        runProc.running = true;
    }

    function stepDone(step, code): void {
        if (pendingStep !== step || !current) {
            pendingStep = "";
            return;
        }
        pendingStep = "";
        if (step === "run") {
            if (code === 0)
                current.run = parseRun(buffer);
            else if (code === 4)
                authProblem = true;
            else if (code < 0 || code === 127)
                missingGh = true;
            if (showPullRequests && code === 0) {
                buffer = "";
                pendingStep = "pr";
                prProc.running = true;
                return;
            }
        } else if (step === "pr" && code === 0) {
            current.prs = parsePrs(buffer, maxPullRequests);
        }
        collected = collected.concat([current]);
        next();
    }

    Process {
        id: runProc

        command: ["gh", "run", "list", "-R", root.current ? root.current.repo : "none/none", "--limit", "1", "--json", "status,conclusion,displayTitle,headBranch"]
        onRunningChanged: if (!running && root.pendingStep === "run")
            lostExit.restart()

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data + "\n";
            }
        }
        onExited: (code, status) => root.stepDone("run", code)
    }

    Process {
        id: prProc

        command: ["gh", "pr", "list", "-R", root.current ? root.current.repo : "none/none", "--author", "@me", "--state", "open", "--json", "number,title,isDraft,reviewDecision,statusCheckRollup"]
        onRunningChanged: if (!running && root.pendingStep === "pr")
            lostExit.restart()

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data + "\n";
            }
        }
        onExited: (code, status) => root.stepDone("pr", code)
    }

    // A missing executable never reports an exit.
    Timer {
        id: lostExit

        interval: 500
        repeat: false
        running: false
        onTriggered: {
            if (root.pendingStep.length > 0)
                root.stepDone(root.pendingStep, -1);
        }
    }

    Timer {
        interval: root.refreshMinutes * 60000
        repeat: true
        running: root.visible && root.repoSetting.length > 0 && Theme.experience !== "gaming"
        onTriggered: root.refresh()
    }

    onRepoSettingChanged: settle.restart()
    onMaxReposChanged: settle.restart()

    Timer {
        id: settle

        interval: 1500
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    function tone(state) {
        return state === "pass" ? "phosphor" : state === "fail" ? "alert" : state === "running" ? "cue" : "neutral";
    }

    function label(state) {
        return state === "pass" ? i18n.tr("PASSING") : state === "fail" ? i18n.tr("FAILING") : state === "running" ? i18n.tr("RUNNING") : state === "none" ? i18n.tr("NO RUNS") : i18n.tr("UNKNOWN");
    }

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.small
        Accessible.name: i18n.tr("Forge Board")

        UiState {
            visible: root.loaded && root.repoSetting.trim().length === 0
            width: parent.width
            kind: "empty"
            glyph: "code"
            message: i18n.tr("Add repositories as owner/name in Settings. Nothing is requested until you do.")
        }

        UiState {
            visible: root.loaded && root.missingGh && root.rows.length > 0
            width: parent.width
            kind: "error"
            message: i18n.tr("GitHub CLI was not found. Install and sign in to GitHub CLI.")
        }

        UiState {
            visible: root.loaded && !root.missingGh && root.authProblem
            width: parent.width
            kind: "error"
            message: i18n.tr("GitHub CLI is not signed in. Sign in to GitHub CLI to view repository status.")
        }

        UiState {
            visible: !root.loaded
            width: parent.width
            kind: "loading"
            message: i18n.tr("Checking GitHub…")
        }

        Repeater {
            model: root.missingGh || root.authProblem ? [] : root.rows

            delegate: Rectangle {
                id: card

                required property var modelData
                readonly property var r: modelData

                width: column.width
                height: body.implicitHeight + Theme.padding.normal * 2
                radius: Theme.rounding.small
                color: Theme.palette.sunken
                border.width: 1
                border.color: Theme.palette.rule
                Accessible.name: i18n.tr("%1: %2").arg(r.repo).arg(root.label(r.run.state))

                ColumnLayout {
                    id: body

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.padding.normal
                        rightMargin: Theme.padding.normal
                    }
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.small

                        UiText {
                            Layout.fillWidth: true
                            role: "subtitle"
                            text: r.repo
                            elide: Text.ElideMiddle
                        }

                        UiChip {
                            text: root.label(r.run.state)
                            tone: root.tone(r.run.state)
                        }
                    }

                    UiText {
                        Layout.fillWidth: true
                        visible: r.run.title !== undefined && r.run.title.length > 0
                        role: "caption"
                        text: (r.run.branch && r.run.branch.length > 0 ? r.run.branch + " · " : "") + r.run.title
                        elide: Text.ElideRight
                        color: Theme.palette.inkMuted
                    }

                    Repeater {
                        model: r.prs

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: Theme.spacing.small

                            UiText {
                                role: "value"
                                text: "#" + modelData.number
                                color: Theme.palette.inkMuted
                            }

                            UiText {
                                Layout.fillWidth: true
                                role: "caption"
                                text: modelData.title
                                elide: Text.ElideRight
                            }

                            UiChip {
                                text: modelData.draft ? i18n.tr("DRAFT") : modelData.review === "APPROVED" ? i18n.tr("APPROVED") : modelData.review === "CHANGES_REQUESTED" ? i18n.tr("CHANGES") : root.label(modelData.checks)
                                tone: modelData.draft ? "neutral" : modelData.review === "CHANGES_REQUESTED" ? "alert" : root.tone(modelData.checks)
                            }
                        }
                    }
                }
            }
        }
    }
}
