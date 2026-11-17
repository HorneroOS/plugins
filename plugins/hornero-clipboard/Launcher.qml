import QtQuick
import "History.js" as History
import Quickshell.Io
import Hornero.PluginKit

// Clipboard history launcher provider (`>clipboard <words>`) and the
// recorder behind it.
//
// Privacy contract (README.md): history lives in memory only (History.js),
// never on disk, never logged, and is erased on shell restart, on disable
// and by the Clear command. Recording is event-driven: `wl-paste --watch`
// wakes the extension on a clipboard change; the extension then reads the
// offer's type list first and records text only, skipping offers that a
// password manager marks secret and anything over your length limit or
// containing one of your excluded words. Pausing stops the watcher process
// entirely. The host's launcher contract copies the row you pick with
// wl-copy (docs/LAUNCHER.md "Several rows").
//
// This entrypoint is loaded for as long as the extension is enabled and
// owns the watcher, so one recorder serves the launcher, the card and the
// commands.
Item {
    id: root

    property string query: ""
    readonly property var results: root.buildRows(root.query, root.tick)

    readonly property bool recording: pluginSettings.value("recording", true) !== false
    readonly property int maxEntries: Math.max(5, Math.min(100, Math.floor(Number(pluginSettings.value("maxEntries", 25))) || 25))
    readonly property int retentionMinutes: Math.max(0, Math.min(1440, Math.floor(Number(pluginSettings.value("retentionMinutes", 60))) || 0))
    readonly property int maxChars: Math.max(50, Math.min(20000, Math.floor(Number(pluginSettings.value("maxChars", 2000))) || 2000))
    readonly property string excludeWords: String(pluginSettings.value("excludeWords", ""))
    readonly property bool skipSensitive: pluginSettings.value("skipSensitive", true) !== false

    // Bumped by the purge timer so relative ages and retention re-evaluate.
    property int tick: 0
    property real startedAt: 0
    // 0 idle, 1 listing the offer's types, 2 reading the text.
    property int step: 0
    property bool again: false

    Translations {
        id: i18n

        pluginId: "hornero-clipboard"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-clipboard"
    }

    function buildRows(text: string, ignored: int): var {
        const now = Date.now();
        return History.search(text, 24).map(item => {
            const age = History.ageLabelParts(now, item.at);
            const when = age.unit === "now" ? i18n.tr("just now") : age.unit === "min" ? i18n.tr("%1 min ago").arg(age.n) : i18n.tr("%1 h ago").arg(age.n);
            return {
                "text": item.text,
                "subtitle": i18n.tr("%1 · %2 characters").arg(when).arg(item.text.length),
                "glyph": "clipboard"
            };
        });
    }

    // A change event: debounce, then read the offer once at a time.
    function changed(): void {
        // wl-paste --watch also fires once for whatever was already on the
        // clipboard when the watcher started (it may predate your consent
        // to record): ignore the first half second.
        if (!root.recording || Date.now() - root.startedAt < 500)
            return;
        debounce.restart();
    }

    function readOffer(): void {
        if (root.step !== 0) {
            root.again = true;
            return;
        }
        root.step = 1;
        typesProcess.running = true;
    }

    function finish(): void {
        root.step = 0;
        if (root.again) {
            root.again = false;
            root.readOffer();
        }
    }

    function record(text: string): void {
        if (History.acceptable(text, root.maxChars, root.excludeWords)) {
            History.add(text, Date.now(), root.maxEntries);
            History.purge(Date.now(), root.retentionMinutes);
            root.tick++;
        }
    }

    onMaxEntriesChanged: History.trim(root.maxEntries)
    onRetentionMinutesChanged: History.purge(Date.now(), root.retentionMinutes)

    Process {
        id: watcher

        running: root.recording
        command: ["wl-paste", "--watch", "echo", "changed"]
        onRunningChanged: if (running)
            root.startedAt = Date.now()

        stdout: SplitParser {
            onRead: root.changed()
        }
    }

    Timer {
        id: debounce

        interval: 80
        onTriggered: root.readOffer()
    }

    Process {
        id: typesProcess

        command: ["wl-paste", "--list-types"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.step !== 1)
                    return;
                if (History.offerDecision(text, root.skipSensitive) === "ok") {
                    root.step = 2;
                    readProcess.running = true;
                } else {
                    root.finish();
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && root.step === 1)
                root.finish();
        }
    }

    Process {
        id: readProcess

        command: ["wl-paste", "--no-newline", "--type", "text"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.step !== 2)
                    return;
                root.record(text);
                root.finish();
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && root.step === 2)
                root.finish();
        }
    }

    // Retention and the relative ages tick once a minute, only while there
    // is something to age.
    Timer {
        interval: 60000
        repeat: true
        running: History.count() > 0
        onTriggered: {
            History.purge(Date.now(), root.retentionMinutes);
            root.tick++;
        }
    }
}
