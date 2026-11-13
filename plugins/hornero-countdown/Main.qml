import QtQuick
import Hornero.PluginKit

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
        interval: 600
        repeat: true
        running: root.finished
        onTriggered: root.flashOn = !root.flashOn
    }

    UiButton {
        id: indicator

        variant: "ghost"
        text: root.finished ? i18n.tr("DONE") : root.fmt(root.remainingSeconds)
        opacity: root.finished && !root.flashOn && !Theme.reducedMotion ? 0.25 : 1.0
        tooltipText: i18n.tr("Countdown: activate for timer controls")
        accessibleName: root.finished ? i18n.tr("Countdown finished") : i18n.tr("Countdown %1 remaining").arg(root.fmt(root.remainingSeconds))
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Countdown")

        Column {
            width: 280
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Countdown")
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {
                    label: i18n.tr("Remaining")
                    value: root.finished ? i18n.tr("DONE") : root.fmt(root.remainingSeconds)
                }

                UiChip {
                    text: root.finished ? i18n.tr("Finished") : root.running ? i18n.tr("Running") : i18n.tr("Paused")
                    tone: root.finished ? "error" : root.running ? "primary" : "neutral"
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

                        variant: "ghost"
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
                    variant: "ghost"
                    text: i18n.tr("Reset")
                    tooltipText: i18n.tr("Reset the countdown")
                    accessibleName: i18n.tr("Reset countdown")
                    onClicked: root.setPreset(Math.max(1, Math.round(root.totalSeconds / 60)))
                }
            }
        }
    }
}
