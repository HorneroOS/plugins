import QtQuick
import Hornero.PluginKit

// Equalizer (bar surface): a live spectrum analyser in the bar, and a
// larger one in its popover. It is an ANALYSER, not an equaliser: PluginKit
// exposes the shell's real PipeWire spectrum of the default output
// (`Audio.spectrum`, the shared `spectrum` provider) and no way to filter
// or retune sound, so there are no bass/treble sliders here and none are
// faked. Bands are real data only: nothing is drawn while nothing plays,
// there is no idle animation and no interpolated level. The peak-hold ticks
// are derived from the real samples (a fixed decay per sample) and labelled
// as such.
//
// Cost control: the shared visualiser only runs while some surface holds a
// `spectrum` lease. By default (`analyseWhen: playing`) this extension holds
// it only while an MPRIS player is playing, so a silent desktop pays
// nothing; `always` also analyses sound from apps that publish no player
// (games, browsers without MPRIS) at the cost of keeping the analyser on.
Item {
    id: root

    // Host context (opt-in): defaults match the horizontal bar layout.
    property string hostOrientation: "horizontal"
    property string hostEdge: "top"
    property string hostSurface: "bar"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property int barBands: Math.max(4, Math.min(12, Math.floor(Number(pluginSettings.value("barBands", 8))) || 8))
    readonly property int popoverBands: Math.max(8, Math.min(24, Math.floor(Number(pluginSettings.value("popoverBands", 16))) || 16))
    readonly property bool peakHold: pluginSettings.value("peakHold", true) !== false
    readonly property string analyseWhen: String(pluginSettings.value("analyseWhen", "playing"))
    readonly property string whenSilent: String(pluginSettings.value("whenSilent", "glyph"))

    readonly property bool analysing: Audio.hasSink && (root.analyseWhen === "always" || (Media.hasPlayer && Media.isPlaying))
    readonly property var raw: root.analysing ? root.sanitize(Audio.spectrum) : []
    readonly property bool sounding: root.raw.some(v => v > 0.01)
    readonly property bool shown: root.whenSilent === "glyph" || root.sounding || popover.visible

    // Fixed decay of the derived peak-hold ticks, per spectrum sample.
    readonly property real peakDecay: 0.03
    property var peaks: []

    implicitWidth: shown ? stack.implicitWidth : 0
    implicitHeight: shown ? stack.implicitHeight : 0

    Subscription {
        domain: "audio"
    }

    Subscription {
        domain: "media"
    }

    Subscription {
        domain: "spectrum"
        enabled: root.analysing
    }

    Translations {
        id: i18n

        pluginId: "hornero-equalizer"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-equalizer"
    }

    function sanitize(spectrum: var): var {
        const out = [];
        if (!spectrum || spectrum.length === undefined)
            return out;
        const n = Math.min(24, spectrum.length);
        for (let i = 0; i < n; i++)
            out.push(Math.max(0, Math.min(1, Number(spectrum[i]) || 0)));
        return out;
    }

    // Real bands regrouped into `want` bands by averaging neighbours; more
    // bands than the provider reports are never invented.
    function regroup(source: var, want: int): var {
        const target = Math.min(want, source.length);
        if (target <= 0 || target >= source.length)
            return source;
        const out = [];
        for (let b = 0; b < target; b++) {
            const from = Math.floor(b * source.length / target);
            const to = Math.max(from + 1, Math.floor((b + 1) * source.length / target));
            let sum = 0;
            for (let i = from; i < to; i++)
                sum += source[i];
            out.push(sum / (to - from));
        }
        return out;
    }

    readonly property var barLevels: root.regroup(root.raw, root.barBands)
    readonly property var popoverLevels: root.regroup(root.raw, root.popoverBands)

    onPopoverLevelsChanged: {
        const next = [];
        const levels = root.popoverLevels;
        for (let i = 0; i < levels.length; i++) {
            const held = i < root.peaks.length ? root.peaks[i] : 0;
            next.push(Math.max(levels[i], held - root.peakDecay));
        }
        root.peaks = next;
    }

    readonly property string statusText: !Audio.hasSink ? i18n.tr("No output device") : root.analysing ? (root.sounding ? i18n.tr("Spectrum of the output") : i18n.tr("Silent")) : i18n.tr("Not analysing: nothing is playing")

    UiStack {
        id: stack

        visible: root.shown
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator

            variant: "quiet"
            glyph: "chart-bar"
            tooltipText: root.statusText
            accessibleName: i18n.tr("Equalizer details")
            onClicked: popover.toggle()
        }

        Row {
            visible: root.sounding && !root.hostCompact && root.hostOrientation !== "vertical"
            spacing: Theme.spacing.small

            Repeater {
                model: root.barLevels

                delegate: UiSegmentMeter {
                    required property real modelData

                    orientation: "vertical"
                    vu: true
                    count: 5
                    segmentThickness: 2
                    segmentLength: 3
                    gap: 1
                    value: modelData
                    threshold: 1.01
                    accessibleName: i18n.tr("Spectrum band")
                }
            }
        }
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Equalizer details")

        Column {
            width: 320
            spacing: Theme.spacing.small

            UiEyebrow {
                channel: 1
                text: i18n.tr("Spectrum")
                context: root.analysing ? i18n.tr("%1 bands").arg(root.popoverLevels.length) : ""
            }

            UiState {
                visible: !Audio.hasSink
                width: parent.width
                kind: "empty"
                message: i18n.tr("No output device is available, so there is nothing to analyse.")
            }

            UiState {
                visible: Audio.hasSink && !root.analysing
                width: parent.width
                kind: "empty"
                message: i18n.tr("Nothing is playing. Start a player, or set the extension to analyse always.")
            }

            Rectangle {
                visible: root.analysing
                width: parent.width
                height: 112
                radius: Theme.rounding.small
                color: Theme.palette.sunken
                border.width: 1
                border.color: Theme.palette.rule

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacing.small

                    Repeater {
                        model: root.popoverLevels

                        delegate: UiSegmentMeter {
                            id: strip

                            required property real modelData
                            required property int index

                            orientation: "vertical"
                            vu: true
                            count: 14
                            segmentThickness: 4
                            segmentLength: Math.max(6, Math.floor(280 / Math.max(1, root.popoverLevels.length)) - 4)
                            value: modelData
                            peak: root.peakHold && index < root.peaks.length ? root.peaks[index] : -1
                            threshold: 1.01
                            accessibleName: i18n.tr("Spectrum band")
                        }
                    }
                }
            }

            UiText {
                visible: root.analysing
                width: parent.width
                role: "caption"
                wrapMode: Text.WordWrap
                text: root.peakHold ? i18n.tr("Live PipeWire spectrum of %1. Ticks are the peak of recent samples.").arg(Audio.outputName) : i18n.tr("Live PipeWire spectrum of %1.").arg(Audio.outputName)
            }

            UiText {
                width: parent.width
                role: "caption"
                wrapMode: Text.WordWrap
                text: i18n.tr("This is an analyser: the shell offers extensions no way to retune sound, so there are no equalizer sliders.")
            }
        }
    }
}
