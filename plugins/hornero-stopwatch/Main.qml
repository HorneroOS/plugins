import QtQuick
import Hornero.PluginKit

// Hornero Stopwatch 2.0 - bar stopwatch. Compact indicator
// opening a host-owned popover with start/pause/resume and
// reset. Timing is anchor-based (wall clock): elapsed time is
// accumulatedMs plus, while running, now minus startedEpochMs;
// the 100ms tick only re-reads that sum (tenths need the
// cadence), so sleep and tick drift no longer lose time the
// way the 1.x += 100 counter did. Both anchors persist through
// PluginKit Settings (declared keys accumulatedMs and
// startedEpochMs), so a shell reload restores a running
// stopwatch. showTenths (default true, the 1.x display) is the
// only user-facing setting. No laps: 1.x had none.
Item {
    id: root

    // Host context (opt-in): defaults keep a roomy horizontal bar.
    property string hostOrientation: "horizontal"
    property bool hostCompact: false
    property int hostAvailableWidth: 0

    property bool showTenths: true
    property real accumulatedMs: 0
    property real startedMs: 0
    property real elapsedMs: 0
    property bool running: false

    implicitWidth: indicator.implicitWidth
    implicitHeight: indicator.implicitHeight

    Settings {
        id: pluginSettings

        pluginId: "hornero-stopwatch"
    }

    Translations {
        id: i18n

        pluginId: "hornero-stopwatch"
    }

    function fmt(ms, tenths) {
        const totalTenths = Math.floor(ms / 100);
        const tenth = totalTenths % 10;
        const totalSeconds = Math.floor(totalTenths / 10);
        const seconds = totalSeconds % 60;
        const minutes = Math.floor(totalSeconds / 60);
        const base = (minutes < 10 ? "0" : "") + minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
        return tenths ? base + "." + tenth : base;
    }

    function persistState() {
        pluginSettings.setValue("accumulatedMs", Math.round(root.accumulatedMs));
        pluginSettings.setValue("startedEpochMs", Math.round(root.startedMs));
    }

    function syncElapsed() {
        root.elapsedMs = root.accumulatedMs + (root.startedMs > 0 ? Math.max(0, Date.now() - root.startedMs) : 0);
    }

    function toggleRunning() {
        if (root.running) {
            root.syncElapsed();
            root.accumulatedMs = root.elapsedMs;
            root.startedMs = 0;
            root.running = false;
        } else {
            root.startedMs = Date.now();
            root.running = true;
            root.syncElapsed();
        }
        root.persistState();
    }

    function resetTimer() {
        root.running = false;
        root.startedMs = 0;
        root.accumulatedMs = 0;
        root.elapsedMs = 0;
        root.persistState();
    }

    Component.onCompleted: {
        root.showTenths = pluginSettings.value("showTenths", true) !== false;
        const accumulated = Number(pluginSettings.value("accumulatedMs", 0));
        const started = Number(pluginSettings.value("startedEpochMs", 0));
        root.accumulatedMs = isFinite(accumulated) && accumulated > 0 ? accumulated : 0;
        root.startedMs = isFinite(started) && started > 0 ? started : 0;
        root.running = root.startedMs > 0;
        root.syncElapsed();
    }

    Timer {
        interval: 100
        repeat: true
        running: root.running
        onTriggered: root.syncElapsed()
    }

    UiButton {
        id: indicator

        variant: "ghost"
        text: root.fmt(root.elapsedMs, root.showTenths && !root.hostCompact)
        tooltipText: i18n.tr("Stopwatch: activate for controls")
        accessibleName: i18n.tr("Stopwatch %1").arg(root.fmt(root.elapsedMs, root.showTenths))
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Stopwatch")

        Column {
            width: 280
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Stopwatch")
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {
                    label: i18n.tr("Elapsed")
                    value: root.fmt(root.elapsedMs, root.showTenths)
                }

                UiChip {
                    text: root.running ? i18n.tr("Running") : i18n.tr("Paused")
                    tone: root.running ? "primary" : "neutral"
                }
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiButton {
                    text: root.running ? i18n.tr("Pause") : root.elapsedMs > 0 ? i18n.tr("Resume") : i18n.tr("Start")
                    tooltipText: root.running ? i18n.tr("Pause the stopwatch") : i18n.tr("Start the stopwatch")
                    accessibleName: root.running ? i18n.tr("Pause stopwatch") : i18n.tr("Start stopwatch")
                    onClicked: root.toggleRunning()
                }

                UiButton {
                    variant: "ghost"
                    enabled: root.elapsedMs > 0 || root.running
                    text: i18n.tr("Reset")
                    tooltipText: i18n.tr("Reset the stopwatch")
                    accessibleName: i18n.tr("Reset stopwatch")
                    onClicked: root.resetTimer()
                }
            }
        }
    }
}
