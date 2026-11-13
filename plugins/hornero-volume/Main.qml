import QtQuick
import Hornero.PluginKit

// Volume 2.0 bar surface (primary): a compact indicator over the
// shared PluginKit Audio facade (event-pushed from PipeWire by the
// shell service). Detail and controls live in a host-owned popover:
// a slider over Audio.setVolume plus decrease/increase and mute.
// Every control calls Audio only from a user handler; nothing
// changes volume on load. No PipeWire object is touched here.
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

    readonly property bool showPercentage: pluginSettings.value("showPercentage", true) !== false
    readonly property bool showWhenNoSink: pluginSettings.value("showWhenNoSink", true) !== false
    readonly property bool shown: Audio.hasSink || showWhenNoSink
    readonly property int percent: Math.round(Audio.volume * 100)
    readonly property string statusText: !Audio.hasSink ? i18n.tr("No output device") : Audio.muted ? i18n.tr("Muted") : showPercentage ? i18n.tr("Volume %1%").arg(percent) : i18n.tr("Volume")

    implicitWidth: shown ? stack.implicitWidth : 0
    implicitHeight: shown ? stack.implicitHeight : 0

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

    UiStack {
        id: stack

        visible: root.shown
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator

            variant: "ghost"
            text: !Audio.hasSink ? "✕" : Audio.muted || Audio.volume === 0 ? "🔇" : Audio.volume < 0.5 ? "🔉" : "🔊"
            tooltipText: root.statusText
            accessibleName: i18n.tr("Volume details")
            onClicked: popover.toggle()
        }

        UiText {
            visible: !root.hostCompact && root.hostOrientation !== "vertical"
            role: "body"
            text: root.statusText
        }
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Volume details")

        Column {
            width: 300
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
                        value: Audio.muted ? i18n.tr("Muted") : i18n.tr("%1%").arg(root.percent)
                    }

                    UiChip {
                        text: Audio.muted ? i18n.tr("Muted") : i18n.tr("Sound on")
                        tone: Audio.muted ? "error" : "primary"
                    }
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
