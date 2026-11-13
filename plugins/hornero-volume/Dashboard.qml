import QtQuick
import Hornero.PluginKit

// Volume 2.0 dashboard surface: the card form of the bar popover —
// output state, slider and step/mute controls over the shared
// PluginKit Audio facade, with an explicit no-output-device state.
// Controls call Audio only from user handlers.
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
    readonly property int percent: Math.round(Audio.volume * 100)

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    Subscription {
        domain: "audio"
    }

    Translations {
        id: i18n

        pluginId: "hornero-volume"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-volume"
    }

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("Volume")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Volume")
            }

            UiState {
                visible: !Audio.hasSink
                width: parent.width
                kind: "empty"
                message: i18n.tr("No output device is available, so volume cannot be adjusted.")
            }

            Column {
                visible: Audio.hasSink
                width: parent.width
                spacing: Theme.spacingSmall

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        label: i18n.tr("Output")
                        value: Audio.muted ? i18n.tr("Muted") : root.showPercentage ? i18n.tr("%1%").arg(root.percent) : i18n.tr("Sound on")
                    }

                    UiChip {
                        text: Audio.muted ? i18n.tr("Muted") : i18n.tr("Sound on")
                        tone: Audio.muted ? "error" : "primary"
                    }
                }

                UiProgress {
                    width: parent.width
                    value: Math.max(0, Math.min(1, Audio.volume))
                }

                UiSlider {
                    width: parent.width
                    from: 0
                    to: 1
                    value: Audio.volume
                    enabled: Audio.hasSink
                    tooltipText: i18n.tr("Output volume")
                    accessibleName: i18n.tr("Output volume")
                    onMoved: Audio.setVolume(value)
                }

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiButton {
                        variant: "ghost"
                        text: "−"
                        enabled: Audio.hasSink
                        tooltipText: i18n.tr("Decrease volume")
                        accessibleName: i18n.tr("Decrease volume")
                        onClicked: Audio.decrementVolume()
                    }

                    UiButton {
                        variant: "ghost"
                        text: Audio.muted ? i18n.tr("Unmute") : i18n.tr("Mute")
                        enabled: Audio.hasSink
                        tooltipText: Audio.muted ? i18n.tr("Unmute output") : i18n.tr("Mute output")
                        accessibleName: Audio.muted ? i18n.tr("Unmute output") : i18n.tr("Mute output")
                        onClicked: Audio.toggleMute()
                    }

                    UiButton {
                        variant: "ghost"
                        text: "+"
                        enabled: Audio.hasSink
                        tooltipText: i18n.tr("Increase volume")
                        accessibleName: i18n.tr("Increase volume")
                        onClicked: Audio.incrementVolume()
                    }
                }

                UiText {
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Output device selection is not exposed by PluginKit Audio; use the shell audio settings to switch devices.")
                }
            }
        }
    }
}
