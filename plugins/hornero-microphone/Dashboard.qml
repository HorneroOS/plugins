import QtQuick
import Hornero.PluginKit

// Microphone 2.0 dashboard surface: the card form of the bar
// popover — input state, read-only level and mute over the shared
// PluginKit Audio facade, with an explicit no-input-device state.
// Mute runs only on click. Never records audio.
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

    readonly property bool showPercentage: pluginSettings.value("showPercentage", true) !== false
    readonly property int percent: Math.round(Audio.sourceVolume * 100)

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    Subscription {
        domain: "audio"
    }

    Translations {
        id: i18n

        pluginId: "hornero-microphone"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-microphone"
    }

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("Microphone")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Microphone")
            }

            UiState {
                visible: !Audio.hasSource
                width: parent.width
                kind: "empty"
                message: i18n.tr("No input device is available, so the microphone cannot be muted or unmuted here.")
            }

            Column {
                visible: Audio.hasSource
                width: parent.width
                spacing: Theme.spacingSmall

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        label: i18n.tr("Input")
                        value: Audio.sourceMuted ? i18n.tr("Muted") : root.showPercentage ? i18n.tr("%1%").arg(root.percent) : i18n.tr("Mic on")
                    }

                    UiChip {
                        text: Audio.sourceMuted ? i18n.tr("Muted") : i18n.tr("Mic on")
                        tone: Audio.sourceMuted ? "error" : "primary"
                    }
                }

                UiProgress {
                    width: parent.width
                    value: Math.max(0, Math.min(1, Audio.sourceVolume))
                }

                UiButton {
                    variant: "ghost"
                    text: Audio.sourceMuted ? i18n.tr("Unmute") : i18n.tr("Mute")
                    enabled: Audio.hasSource
                    tooltipText: Audio.sourceMuted ? i18n.tr("Unmute microphone") : i18n.tr("Mute microphone")
                    accessibleName: Audio.sourceMuted ? i18n.tr("Unmute microphone") : i18n.tr("Mute microphone")
                    onClicked: Audio.toggleSourceMute()
                }

                UiText {
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Input level and device selection are not exposed by PluginKit Audio; the level above is read-only and device switching stays in the shell audio settings.")
                }

                UiText {
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("This widget only shows muted and volume state. It never records audio.")
                }
            }
        }
    }
}
