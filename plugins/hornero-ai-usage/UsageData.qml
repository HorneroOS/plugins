import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Shared data layer for the AI Usage surfaces. Consumes ONLY the
// normalized records from `horneroctl agent usage --json`
// (hornero#407): one record per provider, each degrading
// independently (status ok/unavailable/error). Unavailable data is
// labelled through the record status, never shown as zeros, and
// quota/balance are surfaced only when the provider's own record
// carries them. No credentials are read here; the CLI collectors
// own all provider-specific parsing.
//
// Backward compatibility: a horneroctl too old to know `agent usage`
// (unknown command, no records) falls back to the pre-2.0
// `horneroctl assistant usage --json` aggregate, mapped to a single
// javi-hermes record marked with source "assistant-usage-legacy".
Item {
    id: root

    property var records: []
    property bool hasData: false
    property bool loading: false
    property bool failed: false
    property string sourceKind: ""
    property int okCount: 0
    property int totalTokensAll: 0
    readonly property bool anyOk: root.okCount > 0

    property string _agentBuffer: ""
    property string _legacyBuffer: ""

    Settings {
        id: pluginSettings

        pluginId: "hornero-ai-usage"
    }

    // Typed setting (manifest: integer 15..3600, default 60 — the
    // same cadence the 1.x card hardcoded, so existing installs keep
    // their behaviour). Stored out-of-range values read as the
    // declared default through the PluginKit migration path.
    readonly property int refreshSeconds: {
        const value = Number(pluginSettings.value("refreshSeconds", 60));
        return isFinite(value) && value >= 15 ? Math.min(3600, Math.floor(value)) : 60;
    }

    function refresh(): void {
        if (!agentProc.running && !legacyProc.running) {
            root._agentBuffer = "";
            root.loading = true;
            agentProc.running = true;
        }
    }

    function _apply(recordsIn: var, kind: string): void {
        let ok = 0;
        let total = 0;
        for (const record of recordsIn) {
            if (record && record.status === "ok") {
                ok += 1;
                total += Number(record.totalTokens || 0);
            }
        }
        root.records = recordsIn;
        root.okCount = ok;
        root.totalTokensAll = total;
        root.sourceKind = kind;
        root.hasData = recordsIn.length > 0;
        root.failed = false;
        root.loading = false;
    }

    function _parseNormalized(text: string): var {
        const parsed = JSON.parse(text);
        const data = (parsed && parsed.data) || {};
        let recordsIn = data.records;
        // The horneroctl envelope carries data as string values, so
        // records arrives as a JSON-encoded array string; accept a
        // real array too in case the envelope ever nests it.
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

    Component.onCompleted: refresh()

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
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
                // Exit code 1 only means "no collector produced data";
                // the per-provider records are still in the JSON and
                // stay truthful, so parse regardless of exit status.
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
            if (recordsIn) {
                root._apply(recordsIn, "legacy");
            } else {
                root.records = [];
                root.okCount = 0;
                root.totalTokensAll = 0;
                root.hasData = false;
                root.failed = true;
                root.loading = false;
            }
        }
    }
}
