import QtQuick
import Hornero.PluginKit

// Microphone 2.0 bar surface (primary): a compact indicator over
// the shared PluginKit Audio facade (source state, event-pushed).
// The host-owned popover shows the input level and the one safe
// control the facade offers for sources, mute. Privacy: displays
// only muted/volume state; it never records, captures or
// transmits audio, and no PipeWire object is touched here.
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
    readonly property bool showWhenNoSource: pluginSettings.value("showWhenNoSource", true) !== false
    readonly property bool shown: Audio.hasSource || showWhenNoSource
    readonly property int percent: Math.round(Audio.sourceVolume * 100)
    readonly property string statusText: !Audio.hasSource ? i18n.tr("No input device") : Audio.sourceMuted ? (showPercentage ? i18n.tr("Mic muted %1%").arg(percent) : i18n.tr("Mic muted")) : (showPercentage ? i18n.tr("Mic %1%").arg(percent) : i18n.tr("Mic on"))

    implicitWidth: shown ? stack.implicitWidth : 0
    implicitHeight: shown ? stack.implicitHeight : 0

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

    UiStack {
        id: stack

        visible: root.shown
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator

            variant: "ghost"
            text: !Audio.hasSource ? "✕" : Audio.sourceMuted ? "🚫" : "🎤"
            tooltipText: root.statusText
            accessibleName: i18n.tr("Microphone details")
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
        accessibleName: i18n.tr("Microphone details")

        Column {
            width: 300
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
                        value: Audio.sourceMuted ? i18n.tr("Muted") : i18n.tr("%1%").arg(root.percent)
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
