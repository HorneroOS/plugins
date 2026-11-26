import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Hornero Pomodoro 4: a focus timer for the bar with a real break cycle and an
// optional Experience hook.
//
// Timing is deadline-based (wall clock): the 1 s tick only re-reads the
// remaining time from a stored deadline, so sleep and tick drift cannot
// stretch a session. The deadline, the paused remainder, the phase and the
// number of focus sessions finished in the current set persist through
// PluginKit Settings, so a shell reload restores a running session.
//
// Cycle: focus -> short break, repeated `cyclesBeforeLongBreak` times, then a
// long break. `autoStartNext` decides whether the next phase starts by
// itself or waits for you.
//
// Experience hook (`experienceHook` = focus, default off): while a FOCUS phase
// runs, the shell switches to the Focus experience through
// `horneroctl experience set focus` and puts back the mode you had when the
// phase ends, pauses or resets. It only restores the mode it changed: if you
// switched modes yourself in the meantime, your choice wins. The remembered
// mode lives in memory, so after a shell reload it falls back to Everyday.
Item {
    id: root

    // Host context (opt-in): defaults keep a roomy horizontal bar.
    property string hostOrientation: "horizontal"
    property bool hostCompact: false
    property int hostAvailableWidth: 0

    property int focusMinutes: 25
    property int shortMinutes: 5
    property int longMinutes: 15
    property int cycles: 4
    property bool autoStart: false
    property bool hookOn: false

    property string phase: "focus"
    property int setCount: 0
    property int remainingSeconds: 25 * 60
    property real deadlineMs: 0
    property bool running: false
    property bool finished: false
    property int flashes: 0
    property bool flashOn: true

    readonly property int totalSeconds: phaseMinutes(phase) * 60
    readonly property bool onBreak: phase !== "focus"

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

    // POMODORO-LOGIC-BEGIN
    function clampInt(value, lo, hi, fallback) {
        const n = Math.round(Number(value));
        return isFinite(n) ? Math.max(lo, Math.min(hi, n)) : fallback;
    }

    function fmt(s) {
        const m = Math.floor(s / 60);
        const r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    // After a finished phase: which phase comes next and the new set count.
    function nextPhase(phase, setCount, cycles) {
        if (phase !== "focus")
            return {
                phase: "focus",
                setCount: phase === "long" ? 0 : setCount
            };
        const done = setCount + 1;
        return done >= cycles ? {
            phase: "long",
            setCount: done
        } : {
            phase: "short",
            setCount: done
        };
    }

    function validMode(mode) {
        return ["focus", "everyday", "signal", "gaming", "studio"].indexOf(mode) >= 0;
    }
    // POMODORO-LOGIC-END

    function phaseMinutes(p) {
        return p === "focus" ? focusMinutes : p === "short" ? shortMinutes : longMinutes;
    }

    function phaseLabel(p) {
        return p === "focus" ? i18n.tr("Focus") : p === "short" ? i18n.tr("Short break") : i18n.tr("Long break");
    }

    function persistState() {
        pluginSettings.setValue("deadlineEpochMs", Math.round(root.deadlineMs));
        pluginSettings.setValue("remainingSeconds", root.running || root.finished ? 0 : root.remainingSeconds);
        pluginSettings.setValue("phase", root.phase);
        pluginSettings.setValue("setCount", root.setCount);
    }

    function syncFromDeadline() {
        root.remainingSeconds = Math.max(0, Math.ceil((root.deadlineMs - Date.now()) / 1000));
        return root.remainingSeconds;
    }

    // Experience hook: set a mode through the CLI, one call at a time.
    property string hookPrevious: "everyday"
    property bool hookHeld: false
    property string hookTarget: ""
    property string hookQueued: ""

    function hookSet(mode) {
        if (!root.validMode(mode))
            return;
        if (hookProc.running) {
            root.hookQueued = mode;
            return;
        }
        root.hookTarget = mode;
        hookProc.running = true;
    }

    function hookEngage() {
        if (!root.hookOn || root.hookHeld || Theme.experience === "focus")
            return;
        root.hookPrevious = root.validMode(Theme.experience) ? Theme.experience : "everyday";
        root.hookHeld = true;
        root.hookSet("focus");
    }

    function hookRelease() {
        if (!root.hookHeld)
            return;
        root.hookHeld = false;
        // Only undo our own switch: never override a mode the person chose.
        if (Theme.experience === "focus")
            root.hookSet(root.hookPrevious);
    }

    Process {
        id: hookProc

        command: ["horneroctl", "experience", "set", root.hookTarget]
        onExited: (code, status) => {
            if (root.hookQueued.length > 0) {
                const q = root.hookQueued;
                root.hookQueued = "";
                root.hookSet(q);
            }
        }
    }

    function startRunning() {
        if (root.remainingSeconds <= 0)
            root.remainingSeconds = root.totalSeconds;
        root.deadlineMs = Date.now() + root.remainingSeconds * 1000;
        root.running = true;
        if (root.phase === "focus")
            root.hookEngage();
        root.persistState();
    }

    function pauseRunning() {
        root.syncFromDeadline();
        root.running = false;
        root.deadlineMs = 0;
        root.hookRelease();
        root.persistState();
    }

    function advance() {
        const n = root.nextPhase(root.phase, root.setCount, root.cycles);
        root.phase = n.phase;
        root.setCount = n.setCount;
        root.remainingSeconds = root.totalSeconds;
        root.deadlineMs = 0;
        root.running = false;
        root.finished = false;
        root.flashes = 0;
        if (root.autoStart)
            root.startRunning();
        else
            root.persistState();
    }

    function complete() {
        const wasFocus = root.phase === "focus";
        root.running = false;
        root.finished = true;
        root.remainingSeconds = 0;
        root.deadlineMs = 0;
        root.hookRelease();
        root.persistState();
        Notifications.toast(i18n.tr("Pomodoro"), wasFocus ? i18n.tr("Focus session complete. Time for a break.") : i18n.tr("Break over. Ready to focus."), wasFocus ? "coffee" : "hourglass");
        root.flashes = 3;
        root.flashOn = true;
    }

    function resetTimer() {
        root.hookRelease();
        root.running = false;
        root.finished = false;
        root.flashes = 0;
        root.deadlineMs = 0;
        root.phase = "focus";
        root.setCount = 0;
        root.remainingSeconds = root.totalSeconds;
        root.persistState();
    }

    function skipPhase() {
        root.hookRelease();
        root.running = false;
        root.deadlineMs = 0;
        root.finished = false;
        root.flashes = 0;
        // Skipping a focus phase does not count as a finished session.
        if (root.phase === "focus")
            root.phase = root.setCount + 1 >= root.cycles ? "long" : "short";
        else {
            const n = root.nextPhase(root.phase, root.setCount, root.cycles);
            root.phase = n.phase;
            root.setCount = n.setCount;
        }
        root.remainingSeconds = root.totalSeconds;
        root.persistState();
    }

    function toggleRunning() {
        if (root.finished || root.flashes > 0)
            root.advance();
        else if (root.running)
            root.pauseRunning();
        else
            root.startRunning();
    }

    function loadSettings() {
        root.focusMinutes = root.clampInt(pluginSettings.value("focusMinutes", 25), 1, 180, 25);
        root.shortMinutes = root.clampInt(pluginSettings.value("shortBreakMinutes", 5), 1, 60, 5);
        root.longMinutes = root.clampInt(pluginSettings.value("longBreakMinutes", 15), 1, 120, 15);
        root.cycles = root.clampInt(pluginSettings.value("cyclesBeforeLongBreak", 4), 2, 8, 4);
        root.autoStart = pluginSettings.value("autoStartNext", false) === true;
        root.hookOn = String(pluginSettings.value("experienceHook", "off")) === "focus";
    }

    Component.onCompleted: {
        root.loadSettings();
        const p = String(pluginSettings.value("phase", "focus"));
        root.phase = p === "short" || p === "long" ? p : "focus";
        root.setCount = root.clampInt(pluginSettings.value("setCount", 0), 0, 8, 0);
        const deadline = Number(pluginSettings.value("deadlineEpochMs", 0));
        const stored = Number(pluginSettings.value("remainingSeconds", 0));
        if (isFinite(deadline) && deadline > Date.now()) {
            root.deadlineMs = deadline;
            root.running = true;
            root.syncFromDeadline();
            if (root.phase === "focus")
                root.hookEngage();
        } else if (isFinite(deadline) && deadline > 0) {
            // Session ended while the plugin was unloaded.
            root.complete();
        } else if (isFinite(stored) && stored > 0) {
            root.remainingSeconds = Math.min(Math.round(stored), root.totalSeconds);
        } else {
            root.remainingSeconds = root.totalSeconds;
        }
    }

    // Settings edited in Control Center apply to a timer that is not running.
    Timer {
        interval: 30000
        repeat: true
        running: !root.running && popover.opened
        onTriggered: {
            const before = root.totalSeconds;
            root.loadSettings();
            if (!root.finished && root.flashes === 0 && root.totalSeconds !== before)
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
        running: root.flashes > 0 && root.visible
        onTriggered: {
            root.flashOn = !root.flashOn;
            if (root.flashOn) {
                root.flashes -= 1;
                if (root.flashes <= 0)
                    root.advance();
            }
        }
    }

    UiButton {
        id: indicator

        variant: root.finished && root.flashOn && !Theme.reducedMotion ? "primary" : "quiet"
        glyph: root.finished ? "bell" : root.onBreak ? "coffee" : "hourglass"
        text: root.finished ? i18n.tr("Done") : root.fmt(root.remainingSeconds)
        tooltipText: popover.opened ? "" : i18n.tr("Pomodoro: activate for timer controls")
        accessibleName: root.finished ? i18n.tr("Pomodoro finished") : i18n.tr("Pomodoro, %1, %2 remaining").arg(root.phaseLabel(root.phase)).arg(root.fmt(root.remainingSeconds))
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Pomodoro")

        Column {
            width: 320
            spacing: Theme.spacing.normal

            Row {
                width: parent.width
                spacing: Theme.spacing.small

                UiText {
                    role: "subtitle"
                    text: i18n.tr("Pomodoro")
                }

                UiChip {
                    text: root.finished ? i18n.tr("DONE") : root.running ? i18n.tr("RUNNING") : i18n.tr("PAUSED")
                    tone: root.running ? (root.onBreak ? "cue" : "live") : "neutral"
                }
            }

            UiMetric {
                width: parent.width
                size: "display"
                label: root.phaseLabel(root.phase).toUpperCase()
                value: root.finished ? i18n.tr("DONE") : root.fmt(root.remainingSeconds)
                tone: root.onBreak ? "cue" : "signal"
            }

            UiProgress {
                width: parent.width
                value: root.totalSeconds > 0 ? Math.max(0, Math.min(1, root.remainingSeconds / root.totalSeconds)) : 0
                tone: root.onBreak ? "cue" : "signal"
                accessibleName: i18n.tr("Session progress")
            }

            UiMeterRow {
                width: parent.width
                label: i18n.tr("SET")
                labelWidth: 40
                count: root.cycles
                value: root.cycles > 0 ? root.setCount / root.cycles : 0
                valueText: root.setCount + " / " + root.cycles
                threshold: 1.01
            }

            UiText {
                width: parent.width
                role: "caption"
                wrapMode: Text.WordWrap
                text: root.hookOn ? i18n.tr("Focus phases switch the shell to the Focus experience and restore your mode afterwards.") : i18n.tr("Experience hook is off (see Settings).")
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiButton {
                    text: root.finished ? i18n.tr("Next") : root.running ? i18n.tr("Pause") : i18n.tr("Start")
                    variant: "primary"
                    accessibleName: root.running ? i18n.tr("Pause pomodoro") : i18n.tr("Start pomodoro")
                    onClicked: root.toggleRunning()
                }

                UiButton {
                    text: i18n.tr("Skip")
                    accessibleName: i18n.tr("Skip this phase")
                    onClicked: root.skipPhase()
                }

                UiButton {
                    variant: "secondary"
                    text: i18n.tr("Reset")
                    accessibleName: i18n.tr("Reset pomodoro")
                    onClicked: root.resetTimer()
                }
            }
        }
    }
}
