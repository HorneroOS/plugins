import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Hornero Countdown 3.0 (absorbs Stopwatch): a countdown and a stopwatch behind
// one bar indicator; the popover switches between them. The stopwatch keeps the
// anchor-based timing of Stopwatch 2.x (elapsed = accumulated + now - started,
// so sleep and tick drift lose nothing) and its stored keys (accumulatedMs,
// startedEpochMs), so an existing stopwatch resumes. Below is the 2.0 countdown
// note, unchanged.
// Hornero Countdown 2.0 - bar countdown with 5/10/25 minute
// presets. Compact indicator opening a host-owned popover with
// presets, start/pause, reset and a progress bar (the 1.x ring,
// now a PluginKit UiProgress). Timing is deadline-based (wall
// clock): the 1s tick only re-reads the remaining time from a
// stored deadline, so sleep and tick drift cannot stretch the
// countdown. Deadline, total and paused remainder persist
// through PluginKit Settings (declared keys deadlineEpochMs,
// totalSeconds, remainingSeconds), so a shell reload restores a
// running countdown. The starting length is the typed
// defaultMinutes setting (default 5, the pre-2.0 initial
// preset). At zero the indicator flashes DONE, exactly as 1.x,
// and now also toasts via PluginKit Notifications. No sound.
Item {
    id: root

    // Host context (opt-in): defaults keep a roomy horizontal bar.
    property string hostOrientation: "horizontal"
    property bool hostCompact: false
    property int hostAvailableWidth: 0

    property int defaultMinutes: 5
    property int totalSeconds: 5 * 60
    property int remainingSeconds: 5 * 60
    property real deadlineMs: 0
    property bool running: false
    property bool finished: false
    property bool flashOn: true

    // Stopwatch state (anchor-based wall clock).
    property string mode: "countdown"
    property bool showTenths: true
    property real swAccumulatedMs: 0
    property real swStartedMs: 0
    property real swElapsedMs: 0
    property bool swRunning: false

    implicitWidth: indicator.implicitWidth
    implicitHeight: indicator.implicitHeight

    Settings {
        id: pluginSettings

        pluginId: "hornero-countdown"
    }

    Translations {
        id: i18n

        pluginId: "hornero-countdown"
    }

    function fmt(s) {
        const m = Math.floor(s / 60);
        const r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    function clampMinutes(value) {
        const n = Math.round(Number(value));
        return isFinite(n) ? Math.max(1, Math.min(180, n)) : 5;
    }

    function swFmt(ms, tenths) {
        const totalTenths = Math.floor(ms / 100);
        const tenth = totalTenths % 10;
        const totalSeconds = Math.floor(totalTenths / 10);
        const seconds = totalSeconds % 60;
        const minutes = Math.floor(totalSeconds / 60);
        const base = (minutes < 10 ? "0" : "") + minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
        return tenths ? base + "." + tenth : base;
    }

    function swSync() {
        root.swElapsedMs = root.swAccumulatedMs + (root.swStartedMs > 0 ? Math.max(0, Date.now() - root.swStartedMs) : 0);
    }

    function swPersist() {
        pluginSettings.setValue("accumulatedMs", Math.round(root.swAccumulatedMs));
        pluginSettings.setValue("startedEpochMs", Math.round(root.swStartedMs));
    }

    function swToggle() {
        if (root.swRunning) {
            root.swSync();
            root.swAccumulatedMs = root.swElapsedMs;
            root.swStartedMs = 0;
            root.swRunning = false;
        } else {
            root.swStartedMs = Date.now();
            root.swRunning = true;
            root.swSync();
        }
        root.swPersist();
    }

    function swReset() {
        root.swRunning = false;
        root.swStartedMs = 0;
        root.swAccumulatedMs = 0;
        root.swElapsedMs = 0;
        root.swPersist();
    }

    // The indicator follows what is running: the countdown first, then the
    // stopwatch, otherwise the mode chosen in the popover.
    readonly property bool showStopwatch: root.running ? false : root.swRunning ? true : root.mode === "stopwatch"

    function persistState() {
        pluginSettings.setValue("deadlineEpochMs", Math.round(root.deadlineMs));
        pluginSettings.setValue("totalSeconds", root.totalSeconds);
        pluginSettings.setValue("remainingSeconds", root.running || root.finished ? 0 : root.remainingSeconds);
    }

    function syncFromDeadline() {
        root.remainingSeconds = Math.max(0, Math.ceil((root.deadlineMs - Date.now()) / 1000));
        return root.remainingSeconds;
    }

    function complete() {
        root.running = false;
        root.finished = true;
        root.remainingSeconds = 0;
        root.deadlineMs = 0;
        root.flashOn = true;
        root.persistState();
        Notifications.toast(i18n.tr("Countdown"), i18n.tr("Countdown finished."), "");
    }

    function setPreset(minutes) {
        root.running = false;
        root.finished = false;
        root.deadlineMs = 0;
        root.totalSeconds = minutes * 60;
        root.remainingSeconds = root.totalSeconds;
        root.persistState();
    }

    function toggleRunning() {
        if (root.finished || root.remainingSeconds <= 0)
            root.setPreset(Math.max(1, Math.round(root.totalSeconds / 60)));
        if (root.running) {
            root.syncFromDeadline();
            root.running = false;
            root.deadlineMs = 0;
        } else {
            root.deadlineMs = Date.now() + root.remainingSeconds * 1000;
            root.running = true;
        }
        root.persistState();
    }

    Component.onCompleted: {
        root.defaultMinutes = root.clampMinutes(pluginSettings.value("defaultMinutes", 5));
        root.showTenths = pluginSettings.value("showTenths", true) !== false;
        root.mode = String(pluginSettings.value("defaultMode", "countdown")) === "stopwatch" ? "stopwatch" : "countdown";
        const swAcc = Number(pluginSettings.value("accumulatedMs", 0));
        const swStart = Number(pluginSettings.value("startedEpochMs", 0));
        root.swAccumulatedMs = isFinite(swAcc) && swAcc > 0 ? swAcc : 0;
        root.swStartedMs = isFinite(swStart) && swStart > 0 ? swStart : 0;
        root.swRunning = root.swStartedMs > 0;
        root.swSync();
        const deadline = Number(pluginSettings.value("deadlineEpochMs", 0));
        const total = Number(pluginSettings.value("totalSeconds", 0));
        const stored = Number(pluginSettings.value("remainingSeconds", 0));
        root.totalSeconds = isFinite(total) && Math.round(total) > 0 ? Math.min(10800, Math.round(total)) : root.defaultMinutes * 60;
        if (isFinite(deadline) && deadline > Date.now()) {
            root.deadlineMs = deadline;
            root.running = true;
            root.syncFromDeadline();
        } else if (isFinite(deadline) && deadline > 0) {
            // Countdown ended while the plugin was unloaded.
            root.complete();
        } else if (isFinite(stored) && stored > 0) {
            root.remainingSeconds = Math.min(Math.round(stored), root.totalSeconds);
        } else {
            root.remainingSeconds = root.totalSeconds;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (root.syncFromDeadline() <= 0)
                root.complete();
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: root.swRunning && (root.visible || popover.opened)
        onTriggered: root.swSync()
    }

    Timer {
        interval: 600
        repeat: true
        running: root.finished && root.visible && !Theme.reducedMotion
        onTriggered: root.flashOn = !root.flashOn
    }

    UiButton {
        id: indicator

        variant: root.finished && root.flashOn && !Theme.reducedMotion ? "primary" : "quiet"
        glyph: root.showStopwatch ? "clock" : "hourglass"
        text: root.showStopwatch ? root.swFmt(root.swElapsedMs, root.showTenths && !root.hostCompact) : root.finished ? i18n.tr("DONE") : root.fmt(root.remainingSeconds)
        tooltipText: popover.opened ? "" : i18n.tr("Timers: activate for countdown and stopwatch")
        accessibleName: root.showStopwatch ? i18n.tr("Stopwatch %1").arg(root.swFmt(root.swElapsedMs, root.showTenths)) : root.finished ? i18n.tr("Countdown finished") : i18n.tr("Countdown %1 remaining").arg(root.fmt(root.remainingSeconds))
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Countdown")

        Column {
            width: 280
            spacing: Theme.spacing.small

            Row {
                spacing: Theme.spacing.smaller

                UiButton {
                    text: i18n.tr("Countdown")
                    variant: root.mode === "countdown" ? "primary" : "quiet"
                    accessibleName: i18n.tr("Show the countdown")
                    onClicked: root.mode = "countdown"
                }

                UiButton {
                    text: i18n.tr("Stopwatch")
                    variant: root.mode === "stopwatch" ? "primary" : "quiet"
                    accessibleName: i18n.tr("Show the stopwatch")
                    onClicked: root.mode = "stopwatch"
                }
            }

            Column {
            visible: root.mode === "countdown"
            width: parent.width
            spacing: Theme.spacing.small

            UiStack {
                width: parent.width
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    size: "value"
                    label: i18n.tr("Remaining")
                    value: root.finished ? i18n.tr("DONE") : root.fmt(root.remainingSeconds)
                }

                UiChip {
                    text: root.finished ? i18n.tr("Finished") : root.running ? i18n.tr("Running") : i18n.tr("Paused")
                    tone: root.finished ? "alert" : root.running ? "signal" : "neutral"
                }
            }

            UiProgress {
                width: parent.width
                value: root.totalSeconds > 0 ? Math.max(0, Math.min(1, root.remainingSeconds / root.totalSeconds)) : 0
                accessibleName: i18n.tr("Countdown progress")
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                Repeater {
                    model: [5, 10, 25]

                    UiButton {
                        required property var modelData

                        variant: "quiet"
                        text: i18n.tr("%1m").arg(i18n.formatNumber(Number(modelData)))
                        tooltipText: i18n.tr("Set countdown to %1 minutes").arg(i18n.formatNumber(Number(modelData)))
                        accessibleName: i18n.tr("Set countdown to %1 minutes").arg(i18n.formatNumber(Number(modelData)))
                        onClicked: root.setPreset(Number(modelData))
                    }
                }
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiButton {
                    text: root.running ? i18n.tr("Pause") : i18n.tr("Start")
                    tooltipText: root.running ? i18n.tr("Pause the countdown") : i18n.tr("Start the countdown")
                    accessibleName: root.running ? i18n.tr("Pause countdown") : i18n.tr("Start countdown")
                    onClicked: root.toggleRunning()
                }

                UiButton {
                    variant: "quiet"
                    text: i18n.tr("Reset")
                    tooltipText: i18n.tr("Reset the countdown")
                    accessibleName: i18n.tr("Reset countdown")
                    onClicked: root.setPreset(Math.max(1, Math.round(root.totalSeconds / 60)))
                }
            }
            }

            Column {
                visible: root.mode === "stopwatch"
                width: parent.width
                spacing: Theme.spacing.small

                UiStack {
                    width: parent.width
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        size: "value"
                        label: i18n.tr("Elapsed")
                        value: root.swFmt(root.swElapsedMs, root.showTenths)
                    }

                    UiChip {
                        text: root.swRunning ? i18n.tr("Running") : i18n.tr("Paused")
                        tone: root.swRunning ? "signal" : "neutral"
                    }
                }

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiButton {
                        text: root.swRunning ? i18n.tr("Pause") : root.swElapsedMs > 0 ? i18n.tr("Resume") : i18n.tr("Start")
                        tooltipText: root.swRunning ? i18n.tr("Pause the stopwatch") : i18n.tr("Start the stopwatch")
                        accessibleName: root.swRunning ? i18n.tr("Pause stopwatch") : i18n.tr("Start stopwatch")
                        onClicked: root.swToggle()
                    }

                    UiButton {
                        variant: "quiet"
                        enabled: root.swElapsedMs > 0 || root.swRunning
                        text: i18n.tr("Reset")
                        tooltipText: i18n.tr("Reset the stopwatch")
                        accessibleName: i18n.tr("Reset stopwatch")
                        onClicked: root.swReset()
                    }
                }
            }
        }
    }
}
