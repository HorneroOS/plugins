import QtQuick
import Hornero.PluginKit

// Hornero Metronome 2.0 - bar metronome with a flashing beat
// indicator. Compact indicator opening a host-owned popover
// with start/stop, a BPM slider and the 1.x minus/plus buttons.
// Beat scheduling is deadline-based (wall clock): a 50ms poll
// compares now with the next beat deadline and advances by
// whole beat intervals, so timer drift cannot accumulate and
// beats missed during sleep are skipped, never replayed as a
// burst. BPM stays the persisted typed setting "bpm" (default
// 96, now with the 40-208 bounds the 1.x clamp enforced), so
// stored values keep working unchanged. beatsPerBar (default
// 4) and accentFirstBeat (default false = the 1.x uniform
// flash) are new settings. The metronome deliberately does not
// persist its running state: a reload stops the beat.
Item {
    id: root

    // Host context (opt-in): defaults keep a roomy horizontal bar.
    property string hostOrientation: "horizontal"
    property bool hostCompact: false
    property int hostAvailableWidth: 0

    property int bpm: 96
    property int beatsPerBar: 4
    property bool accentFirstBeat: false
    property bool running: false
    property bool beatOn: false
    property bool accentBeat: false
    property real nextBeatMs: 0
    property int beatCount: 0
    readonly property real beatIntervalMs: 60000 / Math.max(1, root.bpm)

    implicitWidth: indicator.implicitWidth
    implicitHeight: indicator.implicitHeight

    Settings {
        id: pluginSettings

        pluginId: "hornero-metronome"
    }

    Translations {
        id: i18n

        pluginId: "hornero-metronome"
    }

    function clampBpm(value) {
        const n = Math.round(Number(value));
        return isFinite(n) ? Math.max(40, Math.min(208, n)) : 96;
    }

    function clampBeats(value) {
        const n = Math.round(Number(value));
        return isFinite(n) ? Math.max(1, Math.min(12, n)) : 4;
    }

    function setBpm(value) {
        root.bpm = root.clampBpm(value);
        pluginSettings.setValue("bpm", root.bpm);
        // Re-anchor so the new tempo applies from the next beat.
        if (root.running)
            root.nextBeatMs = Date.now() + root.beatIntervalMs;
    }

    function toggleRunning() {
        root.running = !root.running;
        if (root.running) {
            root.beatCount = 0;
            root.nextBeatMs = Date.now() + root.beatIntervalMs;
        } else {
            root.beatOn = false;
        }
    }

    function pollBeat() {
        const now = Date.now();
        if (root.nextBeatMs <= 0 || now < root.nextBeatMs)
            return;
        const missed = Math.floor((now - root.nextBeatMs) / root.beatIntervalMs) + 1;
        root.beatCount += missed;
        root.nextBeatMs += missed * root.beatIntervalMs;
        root.accentBeat = root.accentFirstBeat && (root.beatCount - 1) % Math.max(1, root.beatsPerBar) === 0;
        root.beatOn = true;
        flashTimer.restart();
    }

    Component.onCompleted: {
        root.bpm = root.clampBpm(pluginSettings.value("bpm", 96));
        root.beatsPerBar = root.clampBeats(pluginSettings.value("beatsPerBar", 4));
        root.accentFirstBeat = pluginSettings.value("accentFirstBeat", false) === true;
    }

    Timer {
        interval: 50
        repeat: true
        running: root.running
        onTriggered: root.pollBeat()
    }

    Timer {
        id: flashTimer

        interval: 140
        repeat: false
        onTriggered: root.beatOn = false
    }

    UiButton {
        id: indicator

        variant: "ghost"
        text: root.hostCompact ? i18n.formatNumber(root.bpm) : i18n.tr("%1 BPM").arg(i18n.formatNumber(root.bpm))
        opacity: root.beatOn ? 1.0 : 0.75
        tooltipText: i18n.tr("Metronome: activate for controls")
        accessibleName: i18n.tr("Metronome %1 beats per minute").arg(i18n.formatNumber(root.bpm))
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Metronome")

        Column {
            width: 280
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Metronome")
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: root.beatOn ? (root.accentBeat ? Theme.tertiary : Theme.primary) : Theme.surfaceContainer
                    Accessible.name: root.beatOn ? i18n.tr("Metronome beat on") : i18n.tr("Metronome beat off")
                }

                UiMetric {
                    label: i18n.tr("Tempo")
                    value: i18n.tr("%1 BPM").arg(i18n.formatNumber(root.bpm))
                }

                UiChip {
                    text: root.running ? i18n.tr("Running") : i18n.tr("Stopped")
                    tone: root.running ? "primary" : "neutral"
                }
            }

            UiSlider {
                width: parent.width
                from: 40
                to: 208
                stepSize: 1
                value: root.bpm
                tooltipText: i18n.tr("Tempo in beats per minute")
                accessibleName: i18n.tr("Tempo in beats per minute")
                onMoved: root.setBpm(value)
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiButton {
                    variant: "ghost"
                    text: "-"
                    tooltipText: i18n.tr("Decrease BPM")
                    accessibleName: i18n.tr("Decrease BPM")
                    onClicked: root.setBpm(root.bpm - 1)
                }

                UiButton {
                    variant: "ghost"
                    text: "+"
                    tooltipText: i18n.tr("Increase BPM")
                    accessibleName: i18n.tr("Increase BPM")
                    onClicked: root.setBpm(root.bpm + 1)
                }

                UiButton {
                    text: root.running ? i18n.tr("Stop") : i18n.tr("Start")
                    tooltipText: root.running ? i18n.tr("Stop the metronome") : i18n.tr("Start the metronome")
                    accessibleName: root.running ? i18n.tr("Stop metronome") : i18n.tr("Start metronome")
                    onClicked: root.toggleRunning()
                }
            }

            UiText {
                visible: root.accentFirstBeat
                role: "caption"
                text: i18n.tr("Accent on beat 1 of %1").arg(i18n.formatNumber(root.beatsPerBar))
            }
        }
    }
}
