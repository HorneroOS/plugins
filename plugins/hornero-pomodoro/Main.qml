import QtQuick
import Hornero.PluginKit

// Hornero Pomodoro 2.0 - focus timer for the bar. Compact
// indicator opening a host-owned popover with the controls.
// Timing is deadline-based (wall clock): the 1s tick only
// re-reads the remaining time from a stored deadline, so sleep
// and tick drift cannot stretch a session. The deadline and the
// paused remainder persist through PluginKit Settings (declared
// keys deadlineEpochMs/remainingSeconds), so a shell reload
// restores a running session instead of resetting it. Session
// length is the typed focusMinutes setting (default 25, the
// pre-2.0 hardcoded value). Completion flashes DONE three times
// and resets, exactly as 1.x, and now also toasts via PluginKit
// Notifications. There is deliberately no break cycle: 1.x had
// none and behaviour is preserved.
Item {
    id: root

    // Host context (opt-in): defaults keep a roomy horizontal bar.
    property string hostOrientation: "horizontal"
    property bool hostCompact: false
    property int hostAvailableWidth: 0

    property int focusMinutes: 25
    readonly property int totalSeconds: root.focusMinutes * 60
    property int remainingSeconds: 25 * 60
    property real deadlineMs: 0
    property bool running: false
    property bool finished: false
    property int flashes: 0
    property bool flashOn: true

    implicitWidth: indicator.implicitWidth
    implicitHeight: indicator.implicitHeight

    Settings {
        id: pluginSettings

        pluginId: "hornero-pomodoro"
    }

    Translations {
        id: i18n

        pluginId: "hornero-pomodoro"
    }

    function fmt(s) {
        const m = Math.floor(s / 60);
        const r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    function clampFocus(value) {
        const n = Math.round(Number(value));
        return isFinite(n) ? Math.max(1, Math.min(180, n)) : 25;
    }

    function persistState() {
        pluginSettings.setValue("deadlineEpochMs", Math.round(root.deadlineMs));
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
        root.persistState();
        Notifications.toast(i18n.tr("Pomodoro"), i18n.tr("Focus session complete."), "");
        root.flashes = 3;
        root.flashOn = true;
    }

    function resetTimer() {
        root.running = false;
        root.finished = false;
        root.flashes = 0;
        root.deadlineMs = 0;
        root.remainingSeconds = root.totalSeconds;
        root.persistState();
    }

    function toggleRunning() {
        if (root.finished || root.flashes > 0)
            root.resetTimer();
        if (root.running) {
            root.syncFromDeadline();
            root.running = false;
            root.deadlineMs = 0;
        } else {
            if (root.remainingSeconds <= 0)
                root.remainingSeconds = root.totalSeconds;
            root.deadlineMs = Date.now() + root.remainingSeconds * 1000;
            root.running = true;
        }
        root.persistState();
    }

    Component.onCompleted: {
        root.focusMinutes = root.clampFocus(pluginSettings.value("focusMinutes", 25));
        const deadline = Number(pluginSettings.value("deadlineEpochMs", 0));
        const stored = Number(pluginSettings.value("remainingSeconds", 0));
        if (isFinite(deadline) && deadline > Date.now()) {
            root.deadlineMs = deadline;
            root.running = true;
            root.syncFromDeadline();
        } else if (isFinite(deadline) && deadline > 0) {
            // Session ended while the plugin was unloaded.
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
        running: root.flashes > 0
        onTriggered: {
            root.flashOn = !root.flashOn;
            if (root.flashOn) {
                root.flashes -= 1;
                if (root.flashes <= 0)
                    root.resetTimer();
            }
        }
    }

    UiButton {
        id: indicator

        variant: "ghost"
        text: root.finished ? i18n.tr("DONE") : (root.running ? "● " : "○ ") + root.fmt(root.remainingSeconds)
        opacity: root.finished && !root.flashOn && !Theme.reducedMotion ? 0.25 : 1.0
        tooltipText: i18n.tr("Pomodoro: activate for timer controls")
        accessibleName: root.finished ? i18n.tr("Pomodoro finished") : i18n.tr("Pomodoro %1 remaining").arg(root.fmt(root.remainingSeconds))
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Pomodoro")

        Column {
            width: 280
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Pomodoro")
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
                accessibleName: i18n.tr("Session progress")
            }

            UiText {
                role: "caption"
                text: i18n.tr("Session length: %1 minutes").arg(i18n.formatNumber(root.focusMinutes))
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiButton {
                    text: root.running ? i18n.tr("Pause") : i18n.tr("Start")
                    tooltipText: root.running ? i18n.tr("Pause the focus session") : i18n.tr("Start the focus session")
                    accessibleName: root.running ? i18n.tr("Pause pomodoro") : i18n.tr("Start pomodoro")
                    onClicked: root.toggleRunning()
                }

                UiButton {
                    variant: "ghost"
                    text: i18n.tr("Reset")
                    tooltipText: i18n.tr("Reset the focus session")
                    accessibleName: i18n.tr("Reset pomodoro")
                    onClicked: root.resetTimer()
                }
            }
        }
    }
}
