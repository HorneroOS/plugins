import QtQuick
import Hornero.PluginKit

// Now Playing 2.0 bar surface (primary): a compact indicator over
// the shared PluginKit Media facade (MPRIS, event-pushed). Unlike
// the shell's native bar media component — which keeps transport
// inline and collapses when idle — this indicator takes one button
// of bar space, stays labelled in the no-player state (unless the
// user turns that off), and puts identity/state detail plus
// transport in a host-owned popover. Transport runs only on click.
Item {
    id: root

    // Host context (opt-in): defaults match the 1.x roomy
    // horizontal bar layout when no host values are injected.
    property string hostOrientation: "horizontal"
    property string hostEdge: "top"
    property string hostSurface: "bar"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property bool shown: Media.hasPlayer || showWhenNoPlayer
    readonly property string titleText: Media.title.length > 0 ? Media.title : Media.identity
    readonly property bool idlePlayer: Media.hasPlayer && Media.title.length === 0 && Media.artist.length === 0

    implicitWidth: shown ? stack.implicitWidth : 0
    implicitHeight: shown ? stack.implicitHeight : 0

    Subscription {
        domain: "media"
    }

    Translations {
        id: i18n

        pluginId: "hornero-now-playing"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-now-playing"
    }

    // Typed settings: every default equals the 1.x hardcoded
    // behaviour (artist shown, widget visible with no player,
    // 180px title), so existing installs see no change.
    readonly property bool showArtist: pluginSettings.value("showArtist", true) !== false
    readonly property bool showWhenNoPlayer: pluginSettings.value("showWhenNoPlayer", true) !== false
    readonly property int maxTitleWidth: {
        const value = Number(pluginSettings.value("maxTitleWidth", 180));
        return isFinite(value) && value >= 80 ? Math.min(240, Math.floor(value)) : 180;
    }
    readonly property int titleWidth: hostAvailableWidth > 0 ? Math.max(80, Math.min(maxTitleWidth, hostAvailableWidth - 64)) : maxTitleWidth

    UiStack {
        id: stack

        visible: root.shown
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator

            variant: "ghost"
            text: Media.isPlaying ? "⏸" : "♪"
            tooltipText: Media.hasPlayer ? i18n.tr("Now playing: activate for track details and controls") : i18n.tr("No media player is active")
            accessibleName: i18n.tr("Now playing details")
            onClicked: popover.toggle()
        }

        Column {
            visible: !root.hostCompact && root.hostOrientation !== "vertical"
            spacing: 0

            UiText {
                width: root.titleWidth
                role: "body"
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                text: Media.hasPlayer ? root.titleText : i18n.tr("No player")
            }

            UiText {
                visible: root.showArtist && Media.hasPlayer && Media.artist.length > 0
                width: root.titleWidth
                role: "caption"
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                text: Media.artist
            }
        }
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Now playing details")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Now Playing")
            }

            UiState {
                visible: !Media.hasPlayer
                width: parent.width
                kind: "empty"
                message: i18n.tr("No media player is active. Start playback in a media app and it will appear here.")
            }

            UiState {
                visible: root.idlePlayer
                width: parent.width
                kind: "empty"
                message: i18n.tr("The player reported no track information. It may be idle or stale.")
            }

            Column {
                visible: Media.hasPlayer
                width: parent.width
                spacing: Theme.spacingSmall

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        label: i18n.tr("Player")
                        value: Media.identity
                    }

                    UiChip {
                        text: Media.isPlaying ? i18n.tr("Playing") : i18n.tr("Paused")
                        tone: Media.isPlaying ? "primary" : "neutral"
                    }
                }

                UiMetric {
                    visible: Media.title.length > 0
                    label: i18n.tr("Track")
                    value: Media.title
                }

                UiMetric {
                    visible: root.showArtist && Media.artist.length > 0
                    label: i18n.tr("Artist")
                    value: Media.artist
                }

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiButton {
                        variant: "ghost"
                        text: "⏮"
                        tooltipText: i18n.tr("Previous track")
                        accessibleName: i18n.tr("Previous track")
                        onClicked: Media.previous()
                    }

                    UiButton {
                        text: Media.isPlaying ? "⏸" : "▶"
                        tooltipText: Media.isPlaying ? i18n.tr("Pause") : i18n.tr("Play")
                        accessibleName: Media.isPlaying ? i18n.tr("Pause") : i18n.tr("Play")
                        onClicked: Media.playPause()
                    }

                    UiButton {
                        variant: "ghost"
                        text: "⏭"
                        tooltipText: i18n.tr("Next track")
                        accessibleName: i18n.tr("Next track")
                        onClicked: Media.next()
                    }
                }
            }
        }
    }
}
