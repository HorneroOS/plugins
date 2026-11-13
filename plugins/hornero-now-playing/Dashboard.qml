import QtQuick
import Hornero.PluginKit

// Now Playing 2.0 dashboard surface: the rich card the bar popover
// summarises — player identity, track, artist and playing state
// from the shared PluginKit Media facade, with transport that runs
// only on click and explicit no-player / idle-player states.
Item {
    id: root

    // Host context (opt-in): defaults keep a roomy dashboard card.
    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property bool idlePlayer: Media.hasPlayer && Media.title.length === 0 && Media.artist.length === 0

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

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

    readonly property bool showArtist: pluginSettings.value("showArtist", true) !== false

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("Now Playing")

        Column {
            width: parent.width
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
