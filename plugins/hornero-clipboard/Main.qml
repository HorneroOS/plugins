import QtQuick
import "History.js" as History
import Hornero.PluginKit

// Clipboard history card: the honest state of the recorder (recording or
// paused, how many entries are held, how long they are kept) with the two
// actions that matter, Pause/Resume and Clear. It never lists clipboard
// contents: search them from the launcher (`>clipboard`), which only you can
// open. History is in memory only and is erased when the shell restarts.
Item {
    id: root

    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Clipboard history")
    readonly property string widgetContext: root.recording ? i18n.tr("Recording") : i18n.tr("Paused")
    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 380

    readonly property bool recording: pluginSettings.value("recording", true) !== false
    readonly property int retentionMinutes: Math.max(0, Math.min(1440, Math.floor(Number(pluginSettings.value("retentionMinutes", 60))) || 0))
    property int held: History.count()

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-clipboard"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-clipboard"
    }

    // The history is a shared module without change signals: re-read the
    // count every two seconds, only while the card is on screen.
    Timer {
        interval: 2000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.held = History.count()
    }

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller

        UiChip {
            text: root.recording ? i18n.tr("Recording text only") : i18n.tr("Paused: nothing is recorded")
            glyph: "clipboard"
            tone: root.recording ? "live" : "neutral"
        }

        UiDetailRow {
            width: parent.width
            label: i18n.tr("Held now")
            value: i18n.tr("%1 entries").arg(root.held)
        }

        UiDetailRow {
            width: parent.width
            label: i18n.tr("Kept for")
            value: root.retentionMinutes > 0 ? i18n.tr("%1 min").arg(root.retentionMinutes) : i18n.tr("until the shell restarts")
        }

        UiText {
            width: parent.width
            role: "caption"
            wrapMode: Text.WordWrap
            text: i18n.tr("In memory only: never written to disk, erased when the shell restarts. Search it from the launcher with >clipboard.")
        }

        Row {
            spacing: Theme.spacing.smaller

            UiButton {
                glyph: root.recording ? "player-pause" : "player-play"
                text: root.recording ? i18n.tr("Pause") : i18n.tr("Resume")
                tooltipText: root.recording ? i18n.tr("Stop recording the clipboard") : i18n.tr("Start recording the clipboard")
                accessibleName: root.recording ? i18n.tr("Pause clipboard recording") : i18n.tr("Resume clipboard recording")
                onClicked: pluginSettings.setValue("recording", !root.recording)
            }

            UiButton {
                glyph: "trash"
                text: i18n.tr("Clear")
                variant: "danger"
                tooltipText: i18n.tr("Erase the held clipboard history now")
                accessibleName: i18n.tr("Clear clipboard history")
                onClicked: {
                    History.clear();
                    root.held = 0;
                }
            }
        }
    }
}
