import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Audio Deck (PluginKit 3, Hornero Signal): a desktop instrument over the
// shared `media`, `audio` and `spectrum` providers. The spectrum is the
// shell's real PipeWire visualiser analysis of the default output, one
// vertical VU strip per band (`vu`: phosphor, the hardware convention), so
// it moves only while sound plays and every segment is off when nothing is
// playing -- there is no idle animation and no simulated level. Beside it:
// the current track (MPRIS), the playing state and the output volume. The
// `spectrum` lease runs the shared visualiser only while this widget is
// loaded, so the `showSpectrum` setting (default on) releases it. The host
// owns frame, position, size and edit mode and suspends desktop widgets in
// the `gaming` experience. Transport and volume controls are deliberately
// absent: a desktop instrument shows state; use the shell for control.
Item {
    id: root

    // Host context: the desktop host injects the content box.
    property string hostSurface: "desktop"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Audio Deck")
    readonly property string widgetContext: Media.hasPlayer ? (Media.isPlaying ? i18n.tr("PLAYING") : i18n.tr("PAUSED")) : i18n.tr("NO PLAYER")

    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 420
    readonly property int contentHeight: hostAvailableHeight > 0 ? hostAvailableHeight : 280

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Subscription {
        domain: "media"
    }

    Subscription {
        domain: "audio"
    }

    Subscription {
        domain: "spectrum"
        enabled: root.showSpectrum
    }

    Translations {
        id: i18n

        pluginId: "hornero-audio-deck"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-audio-deck"
    }

    readonly property bool showSpectrum: pluginSettings.value("showSpectrum", true) !== false
    readonly property bool showArtist: pluginSettings.value("showArtist", true) !== false

    readonly property int bandCount: {
        const value = Math.floor(Number(pluginSettings.value("bandCount", 24)));
        return isFinite(value) ? Math.max(4, Math.min(24, value)) : 24;
    }

    // Real PipeWire bands (0-1), capped so the strips stay readable.
    // Fewer bands than the provider reports average neighbouring real
    // bands; more are never invented.
    readonly property var bands: {
        const s = Audio.spectrum;
        if (!s || s.length === undefined)
            return [];
        const source = [];
        const n = Math.min(24, s.length);
        for (let i = 0; i < n; i++)
            source.push(Math.max(0, Math.min(1, Number(s[i]) || 0)));
        const want = Math.min(root.bandCount, source.length);
        if (want >= source.length)
            return source;
        const out = [];
        for (let b = 0; b < want; b++) {
            const from = Math.floor(b * source.length / want);
            const to = Math.max(from + 1, Math.floor((b + 1) * source.length / want));
            let sum = 0;
            for (let i = from; i < to; i++)
                sum += source[i];
            out.push(sum / (to - from));
        }
        return out;
    }
    readonly property int bandWidth: bands.length > 0 ? Math.max(6, Math.min(16, Math.floor((contentWidth - (bands.length - 1) * Theme.spacing.small) / bands.length))) : 12

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller
        Accessible.name: i18n.tr("Audio Deck")

        // Spectrum well: eyebrow, then one vertical VU strip per band.
        Rectangle {
            visible: root.showSpectrum
            width: parent.width
            height: spectrumRow.implicitHeight + spectrumLabel.implicitHeight + Theme.padding.larger * 2 + Theme.spacing.small
            radius: Theme.rounding.small
            color: Theme.palette.sunken
            border.width: 1
            border.color: Theme.palette.rule

            UiText {
                id: spectrumLabel

                x: Theme.padding.larger
                y: Theme.padding.normal
                role: "eyebrow"
                text: Audio.hasSink ? i18n.tr("SPECTRUM · %1 BANDS").arg(root.bands.length) : i18n.tr("SPECTRUM")
            }

            UiText {
                visible: !Audio.hasSink
                anchors.centerIn: parent
                role: "caption"
                text: i18n.tr("No output device is available.")
            }

            Row {
                id: spectrumRow

                visible: Audio.hasSink
                x: Theme.padding.larger
                anchors.top: spectrumLabel.bottom
                anchors.topMargin: Theme.spacing.small
                spacing: Theme.spacing.small

                Repeater {
                    model: root.bands

                    delegate: UiSegmentMeter {
                        required property real modelData

                        orientation: "vertical"
                        vu: true
                        count: 12
                        segmentThickness: 4
                        segmentLength: root.bandWidth
                        value: modelData
                        threshold: 1.01
                        accessibleName: i18n.tr("Spectrum band")
                    }
                }
            }
        }

        UiText {
            width: parent.width
            role: "title"
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            text: Media.hasPlayer ? (Media.title.length > 0 ? Media.title : Media.identity) : i18n.tr("Nothing playing")
            color: Media.hasPlayer ? Theme.palette.ink : Theme.palette.inkMuted
        }

        UiText {
            visible: root.showArtist && Media.hasPlayer && Media.artist.length > 0
            width: parent.width
            role: "caption"
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            text: Media.artist + (Media.album.length > 0 ? " · " + Media.album : "")
        }

        UiMeterRow {
            width: parent.width
            label: i18n.tr("OUT")
            value: Audio.muted ? 0 : Audio.volume
            valueText: Audio.muted ? i18n.tr("Muted") : Math.round(Audio.volume * 100) + " %"
            available: Audio.hasSink
            threshold: 1.01
        }

        UiDetailRow {
            visible: Audio.hasSink && Audio.outputName.length > 0
            width: parent.width
            glyph: "device-speaker"
            label: i18n.tr("Output")
            value: Audio.outputName
        }
    }
}
