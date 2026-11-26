import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Shared data layer for every Dev Pulse surface. Consumes ONLY the
// normalized records from `horneroctl github ... --json` (schema v1):
// horneroctl is the single data service and gh owns authentication —
// this component never runs gh, never sees a token, never touches
// the network itself, and never invents a metric. Unknown stays
// unknown; stale data is labelled stale.
//
// The optional Agent Deck comparison consumes the same
// `horneroctl agent usage --json` records Agent Deck uses. Scopes
// are never summed together: GitHub figures are account-scope,
// AI token figures keep their own local/account scope, and the two
// are only ever shown side by side (temporal association).
Item {
    id: root

    property var statsRecords: []
    property var inboxRecords: []
    property var agentRecords: []
    property bool hasData: false
    property bool loading: false
    property bool failed: false
    property bool stale: false
    property string account: ""
    property double lastUpdatedMs: 0

    property string _statsBuffer: ""
    property string _inboxBuffer: ""
    property string _agentBuffer: ""
    property int _pending: 0
    property int _backoff: 1
    property var _prevFailing: null
    property var _prevReview: null

    Translations {
        id: i18n

        pluginId: "hornero-github-stats"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-github-stats"
    }

    readonly property int refreshSeconds: {
        const value = Number(pluginSettings.value("refreshSeconds", 300));
        return isFinite(value) && value >= 60 ? Math.min(3600, Math.floor(value)) : 300;
    }
    readonly property string orgFilter: String(pluginSettings.value("orgFilter", "") || "")
    readonly property string repoFilter: String(pluginSettings.value("repoFilter", "") || "")
    readonly property bool reactionsEnabled: String(pluginSettings.value("reactionsEnabled", true)) !== "false"

    property string statsWindow: "30"
    readonly property int statsWindowDays: statsWindow === "all" ? 365 : Number(statsWindow)

    function setStatsWindow(w: string): void {
        if (!["7", "30", "90", "365", "all"].includes(w))
            return;
        root.statsWindow = w;
        pluginSettings.setValue("statsWindow", w);
        root.refresh(true);
    }

    readonly property var calendar: {
        for (const r of root.statsRecords)
            if (r && r.kind === "stats-calendar")
                return r;
        return null;
    }
    readonly property var totals: {
        for (const r of root.statsRecords)
            if (r && r.kind === "stats-totals")
                return r;
        return null;
    }
    readonly property var repoRecords: root.statsRecords.filter(r => r && r.kind === "stats-repo")
    readonly property var inboxItems: root.inboxRecords.filter(r => r && r.kind === "inbox")
    readonly property var failingItems: root.inboxItems.filter(r => r.category === "failing")
    readonly property var mineItems: root.inboxItems.filter(r => r.category === "mine")
    readonly property var reviewItems: root.inboxItems.filter(r => r.category === "review")
    readonly property var assignedItems: root.inboxItems.filter(r => r.category === "assigned")

    function summaryTotal(category: string): double {
        for (const r of root.inboxRecords)
            if (r && r.kind === "inbox-summary" && r.category === category)
                return Number(r.total || 0);
        return -1;
    }

    function dailyEntries(record: var): var {
        if (!record || typeof record.recentDays !== "string" || record.recentDays.length === 0)
            return [];
        const out = [];
        for (const part of record.recentDays.split(",")) {
            const bits = part.split(":");
            const n = Number(bits[1]);
            if (isFinite(n) && bits[0].length === 10)
                out.push({ "date": bits[0], "count": n });
        }
        return out;
    }

    function agentDailyValues(days: int): var {
        // Temporal association only: AI daily token buckets (local
        // scope, as Agent Deck defines them) aligned by date label
        // with GitHub contribution days. Never summed with GitHub
        // counts and never presented as attribution.
        const byDate = ({});
        for (const record of root.agentRecords) {
            if (!record || record.status !== "ok" || record.scope === "account")
                continue;
            for (const e of root.dailyEntries(record))
                byDate[e.date] = (byDate[e.date] || 0) + e.count;
        }
        const dates = Object.keys(byDate).sort();
        const sliced = days > 0 ? dates.slice(-days) : dates;
        return sliced.map(d => byDate[d]);
    }

    function refresh(force: bool): void {
        if (root._pending > 0)
            return;
        root.loading = true;
        root._pending = 3;
        root._statsBuffer = "";
        root._inboxBuffer = "";
        root._agentBuffer = "";
        const days = String(Math.max(7, root.statsWindowDays));
        // Literal argv arrays only (the validator requires them);
        // empty filter values mean "no filter" to the backend.
        statsProc.command = force ? ["horneroctl", "github", "stats", "--days", days, "--org", root.orgFilter, "--repo", root.repoFilter, "--force-refresh", "--json"] : ["horneroctl", "github", "stats", "--days", days, "--org", root.orgFilter, "--repo", root.repoFilter, "--json"];
        inboxProc.command = ["horneroctl", "github", "inbox", "--org", root.orgFilter, "--repo", root.repoFilter, "--json"];
        agentProc.command = ["horneroctl", "agent", "usage", "--json"];
        statsProc.running = true;
        inboxProc.running = true;
        agentProc.running = true;
    }

    function _done(ok: bool): void {
        root._pending -= 1;
        if (root._pending > 0)
            return;
        root.loading = false;
        if (ok || root.hasData) {
            root.failed = false;
            root.stale = !ok;
            root.lastUpdatedMs = Date.now();
            root._backoff = 1;
            root._reactDiff();
        } else {
            root.failed = true;
            root._backoff = Math.min(4, root._backoff * 2);
        }
    }

    // Governed companion reactions on genuine transitions only:
    // a check newly failing, or a new review request. First sight
    // is a baseline, never a replay of history. Existing governed
    // kinds only; the shell's policy decides visibility.
    function _reactDiff(): void {
        if (!root.reactionsEnabled)
            return;
        const failing = root.failingItems.map(r => String(r.url || ""));
        const review = root.reviewItems.map(r => String(r.url || ""));
        if (root._prevFailing !== null) {
            for (const url of failing)
                if (!root._prevFailing.includes(url))
                    Companion.react("hornero-github-stats", "build.failed", i18n.tr("Checks failing on a pull request"));
        }
        if (root._prevReview !== null) {
            for (const url of review)
                if (!root._prevReview.includes(url))
                    Companion.react("hornero-github-stats", "attention", i18n.tr("Review requested on a pull request"));
        }
        root._prevFailing = failing;
        root._prevReview = review;
    }

    function _parse(text: string): var {
        try {
            const parsed = JSON.parse(text);
            const data = (parsed && parsed.data) || {};
            let recordsIn = data.records;
            if (typeof recordsIn === "string")
                recordsIn = JSON.parse(recordsIn);
            return Array.isArray(recordsIn) ? recordsIn : null;
        } catch (e) {
            return null;
        }
    }

    Component.onCompleted: {
        const stored = String(pluginSettings.value("statsWindow", "30"));
        if (["7", "30", "90", "365", "all"].includes(stored))
            root.statsWindow = stored;
        refresh(false);
    }

    Timer {
        interval: root.refreshSeconds * 1000 * root._backoff
        repeat: true
        running: true
        onTriggered: root.refresh(false)
    }

    Process {
        id: statsProc

        command: ["horneroctl", "github", "stats", "--json"]

        stdout: SplitParser {
            onRead: data => {
                root._statsBuffer += data;
            }
        }
        onExited: exitCode => {
            let ok = false;
            try {
                const recordsIn = root._parse(root._statsBuffer.trim());
                if (recordsIn && recordsIn.length > 0) {
                    root.statsRecords = recordsIn;
                    for (const r of recordsIn)
                        if (r && r.account)
                            root.account = String(r.account);
                    root.hasData = true;
                    ok = recordsIn.some(r => r && r.status === "ok");
                }
            } catch (e) {
                ok = false;
            }
            root._done(ok);
        }
    }

    Process {
        id: inboxProc

        command: ["horneroctl", "github", "inbox", "--json"]

        stdout: SplitParser {
            onRead: data => {
                root._inboxBuffer += data;
            }
        }
        onExited: exitCode => {
            let ok = false;
            try {
                const recordsIn = root._parse(root._inboxBuffer.trim());
                if (recordsIn) {
                    root.inboxRecords = recordsIn;
                    ok = true;
                }
            } catch (e) {
                ok = false;
            }
            root._done(ok);
        }
    }

    Process {
        id: agentProc

        command: ["horneroctl", "agent", "usage", "--json"]

        stdout: SplitParser {
            onRead: data => {
                root._agentBuffer += data;
            }
        }
        onExited: exitCode => {
            // Optional: Agent Deck data may be absent entirely.
            try {
                const recordsIn = root._parse(root._agentBuffer.trim());
                if (recordsIn)
                    root.agentRecords = recordsIn.filter(r => r && typeof r.provider === "string");
            } catch (e) {
                root.agentRecords = [];
            }
            root._done(true);
        }
    }
}
