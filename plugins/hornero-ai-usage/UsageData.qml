import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Shared data layer for every Agent Deck surface. Consumes ONLY the
// normalized records from `horneroctl agent usage --json` (schema v2,
// hornero#407): one record per discovered agent, each degrading
// independently. horneroctl is the single data service — its own
// short result cache collapses this component's per-surface timers
// into one backend collection, and quota probes are cached there
// too. This component never reads credentials, never touches the
// network, and never invents a quota: unknown stays unknown.
//
// Derived values never mix scopes: token totals sum machine-local
// records only (account-global figures are never added in), and the
// "tightest quota" is the single most constrained *verified* window,
// never an average across providers.
Item {
    id: root

    property var records: []
    property bool hasData: false
    property bool loading: false
    property bool failed: false
    property bool stale: false
    property string sourceKind: ""
    property int okCount: 0
    property int subCount: 0
    property int totalTokensLocal: 0
    property double worstPercent: -1
    property string worstLabel: ""
    property double nextResetUnix: 0
    property double lastUpdatedMs: 0
    readonly property bool anyOk: root.okCount > 0

    property string _agentBuffer: ""
    property string _legacyBuffer: ""
    property int _backoff: 1

    Translations {
        id: i18n

        pluginId: "hornero-ai-usage"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-ai-usage"
    }

    readonly property int refreshSeconds: {
        const value = Number(pluginSettings.value("refreshSeconds", 180));
        return isFinite(value) && value >= 30 ? Math.min(3600, Math.floor(value)) : 180;
    }

    // Activity window for daily statistics, persisted as a setting
    // ("7" | "30" | "60" | "90" | "all"). Filtering is client-side
    // over the already-collected records — changing it never costs
    // a provider call.
    property string statsWindow: "30"
    readonly property int statsWindowDays: statsWindow === "all" ? 0 : Number(statsWindow)

    function setStatsWindow(w: string): void {
        if (!["7", "30", "60", "90", "all"].includes(w))
            return;
        root.statsWindow = w;
        pluginSettings.setValue("statsWindow", w);
    }

    readonly property int warningPercent: {
        const value = Number(pluginSettings.value("warningPercent", 80));
        return isFinite(value) && value >= 50 ? Math.min(99, Math.floor(value)) : 80;
    }

    // Tightest verified quota first, then healthy without quota,
    // then unavailable/error — the order the pages lead with.
    readonly property var sortedRecords: {
        const rank = r => {
            if (r && r.status === "ok" && root.maxPercent(r) >= 0)
                return 0;
            if (r && r.status === "ok")
                return 1;
            if (r && r.status === "unavailable")
                return 2;
            return 3;
        };
        return root.records.slice().sort((a, b) => {
            const d = rank(a) - rank(b);
            return d !== 0 ? d : root.maxPercent(b) - root.maxPercent(a);
        });
    }

    function windowsOf(record: var): var {
        // Records crossing QML property boundaries lose Array
        // identity (QVariantList), so test for a numeric length —
        // Array.isArray would silently drop every real window.
        if (record && record.quotaWindows && typeof record.quotaWindows.length === "number")
            return record.quotaWindows;
        // Legacy (schema v1) single-window mirror.
        if (record && record.quota === "available")
            return [{
                "id": "quota",
                "label": "Quota",
                "usedPercent": Number(record.quotaUsedPercent || 0),
                "resetsAtUnix": Number(record.quotaResetsAtUnix || 0)
            }];
        return [];
    }

    // Real per-day token buckets from the backend's recentDays
    // ('YYYY-MM-DD:tokens,...'), oldest first. Empty when the
    // provider's source carries no timestamps — no chart then.
    function dailyEntries(record: var): var {
        if (!record || typeof record.recentDays !== "string" || record.recentDays.length === 0)
            return [];
        const out = [];
        for (const part of record.recentDays.split(",")) {
            const bits = part.split(":");
            const n = Number(bits[1]);
            const ms = Date.parse(bits[0] + "T00:00:00Z");
            if (isFinite(n) && isFinite(ms))
                out.push({ "date": bits[0], "tokens": n, "ms": ms });
        }
        return out;
    }

    function _inWindow(entries: var, days: int): var {
        if (days <= 0)
            return entries;
        const startToday = Math.floor(Date.now() / 86400000) * 86400000;
        const cutoff = startToday - (days - 1) * 86400000;
        return entries.filter(e => e.ms >= cutoff);
    }

    function dailyValues(record: var, days: int): var {
        return root._inWindow(root.dailyEntries(record), days || 0).map(e => e.tokens);
    }

    function windowTokens(record: var, days: int): double {
        let total = 0;
        for (const e of root._inWindow(root.dailyEntries(record), days || 0))
            total += e.tokens;
        return total;
    }

    // Holistic daily activity across local harnesses: same-date
    // buckets summed over machine-local records only. Account-scope
    // figures never join (they are not this machine's activity and
    // carry no daily series), and days a provider did not report
    // contribute nothing rather than an invented zero.
    function holisticSeries(days: int): var {
        const byDate = ({});
        let providers = 0;
        for (const record of root.records) {
            if (!record || record.status !== "ok" || record.scope === "account")
                continue;
            const entries = root._inWindow(root.dailyEntries(record), days || 0);
            if (entries.length === 0)
                continue;
            providers += 1;
            for (const e of entries)
                byDate[e.date] = (byDate[e.date] || 0) + e.tokens;
        }
        const dates = Object.keys(byDate).sort();
        let total = 0;
        let peak = 0;
        let peakDate = "";
        const values = dates.map(d => {
            total += byDate[d];
            if (byDate[d] > peak) {
                peak = byDate[d];
                peakDate = d;
            }
            return byDate[d];
        });
        return { "values": values, "total": total, "peak": peak, "peakDate": peakDate, "providers": providers, "activeDays": dates.length };
    }

    function maxPercent(record: var): double {
        let best = -1;
        for (const w of root.windowsOf(record))
            best = Math.max(best, Number(w.usedPercent ?? -1));
        return best;
    }

    // Joined record errors, or "" — QVariantList-safe like windowsOf.
    function errorsText(record: var): string {
        if (!record || !record.errors || typeof record.errors.length !== "number" || record.errors.length === 0)
            return "";
        const parts = [];
        for (let i = 0; i < record.errors.length; i++)
            parts.push(String(record.errors[i]));
        return parts.join("; ");
    }

    function recordName(record: var): string {
        return String((record && (record.name || record.provider)) || "");
    }

    function statusText(status: string): string {
        if (status === "ok")
            return i18n.tr("Available");
        if (status === "error")
            return i18n.tr("Error");
        return i18n.tr("Unavailable");
    }

    function freshnessText(freshness: string): string {
        if (freshness === "fresh")
            return i18n.tr("Fresh");
        if (freshness === "stale")
            return i18n.tr("Stale");
        return i18n.tr("Freshness unknown");
    }

    // "in 4h 12m" from a provider reset timestamp; "" when the
    // provider reported no reset. Pure local arithmetic.
    function resetInText(resetsAtUnix: double, nowMs: double): string {
        if (!(resetsAtUnix > 0))
            return "";
        const secs = Math.round(resetsAtUnix - nowMs / 1000);
        if (secs <= 0)
            return i18n.tr("reset due");
        if (secs < 3600)
            return i18n.tr("in %1m").arg(Math.max(1, Math.round(secs / 60)));
        if (secs < 86400)
            return i18n.tr("in %1h %2m").arg(Math.floor(secs / 3600)).arg(Math.round(secs % 3600 / 60));
        return i18n.tr("in %1d %2h").arg(Math.floor(secs / 86400)).arg(Math.round(secs % 86400 / 3600));
    }

    function refresh(force: bool): void {
        if (agentProc.running || legacyProc.running)
            return;
        root._agentBuffer = "";
        root.loading = true;
        agentProc.command = force ? ["horneroctl", "agent", "usage", "--force-refresh", "--json"] : ["horneroctl", "agent", "usage", "--json"];
        agentProc.running = true;
    }

    function _apply(recordsIn: var, kind: string): void {
        let ok = 0;
        let subs = 0;
        let total = 0;
        let worst = -1;
        let worstText = "";
        let nextReset = 0;
        const nowSec = Date.now() / 1000;
        for (const record of recordsIn) {
            if (!record || record.status !== "ok")
                continue;
            ok += 1;
            if (record.billing === "subscription")
                subs += 1;
            if (record.scope !== "account" && record.totalTokens !== undefined)
                total += Number(record.totalTokens || 0);
            for (const w of root.windowsOf(record)) {
                const pct = Number(w.usedPercent ?? -1);
                if (pct > worst) {
                    worst = pct;
                    worstText = root.recordName(record) + " · " + String(w.label || "");
                }
                const reset = Number(w.resetsAtUnix || 0);
                if (reset > nowSec && (nextReset === 0 || reset < nextReset))
                    nextReset = reset;
            }
        }
        root.records = recordsIn;
        root.okCount = ok;
        root.subCount = subs;
        root.totalTokensLocal = total;
        root.worstPercent = worst;
        root.worstLabel = worstText;
        root.nextResetUnix = nextReset;
        root.sourceKind = kind;
        root.hasData = recordsIn.length > 0;
        root.failed = false;
        root.stale = false;
        root.loading = false;
        root.lastUpdatedMs = Date.now();
        root._backoff = 1;
    }

    function _fail(): void {
        root.loading = false;
        root._backoff = Math.min(4, root._backoff * 2);
        if (root.hasData) {
            // Keep last-known-good records; say they are stale.
            root.stale = true;
        } else {
            root.records = [];
            root.okCount = 0;
            root.subCount = 0;
            root.totalTokensLocal = 0;
            root.worstPercent = -1;
            root.failed = true;
        }
    }

    function _parseNormalized(text: string): var {
        const parsed = JSON.parse(text);
        const data = (parsed && parsed.data) || {};
        let recordsIn = data.records;
        if (typeof recordsIn === "string")
            recordsIn = JSON.parse(recordsIn);
        if (!Array.isArray(recordsIn))
            return null;
        const valid = recordsIn.filter(r => r && typeof r.provider === "string" && typeof r.status === "string");
        return valid.length > 0 ? valid : null;
    }

    function _parseLegacy(text: string): var {
        const parsed = JSON.parse(text);
        if (parsed && parsed.ok === false)
            return null;
        const data = (parsed && parsed.data) || parsed || {};
        if (data.inputTokens === undefined && data.outputTokens === undefined && data.totalTokens === undefined)
            return null;
        const input = Number(data.inputTokens || 0);
        const output = Number(data.outputTokens || 0);
        const record = {
            "provider": "javi-hermes",
            "name": "Javi (Hermes)",
            "account": "unknown",
            "source": "assistant-usage-legacy",
            "status": "ok",
            "freshness": "unknown",
            "inputTokens": input,
            "outputTokens": output,
            "totalTokens": Number(data.totalTokens || (input + output)),
            "quota": "unknown",
            "balance": "unknown",
            "errors": []
        };
        if (data.sessions !== undefined)
            record["sessions"] = Number(data.sessions);
        if (data.apiCalls !== undefined)
            record["apiCalls"] = Number(data.apiCalls);
        if (typeof data.models === "string" && data.models.length > 0)
            record["models"] = data.models;
        return [record];
    }

    Component.onCompleted: {
        const stored = String(pluginSettings.value("statsWindow", "30"));
        if (["7", "30", "60", "90", "all"].includes(stored))
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
        id: agentProc

        command: ["horneroctl", "agent", "usage", "--json"]

        stdout: SplitParser {
            onRead: data => {
                root._agentBuffer += data;
            }
        }
        onExited: exitCode => {
            let recordsIn = null;
            try {
                recordsIn = root._parseNormalized(root._agentBuffer.trim());
            } catch (e) {
                recordsIn = null;
            }
            if (recordsIn) {
                root._apply(recordsIn, "normalized");
            } else {
                root._legacyBuffer = "";
                legacyProc.running = true;
            }
        }
    }

    Process {
        id: legacyProc

        command: ["horneroctl", "assistant", "usage", "--json"]

        stdout: SplitParser {
            onRead: data => {
                root._legacyBuffer += data;
            }
        }
        onExited: exitCode => {
            let recordsIn = null;
            try {
                recordsIn = root._parseLegacy(root._legacyBuffer.trim());
            } catch (e) {
                recordsIn = null;
            }
            if (recordsIn)
                root._apply(recordsIn, "legacy");
            else
                root._fail();
        }
    }
}
