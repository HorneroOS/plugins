import QtQuick
import "EmojiSearch.js" as Search
import Quickshell.Io
import Hornero.PluginKit

// Emoji picker card: search the bundled Unicode 16.0 table and click an
// emoji to copy it with wl-copy. The same table and ranking back the
// `>emoji` launcher provider (Launcher.qml). Nothing is recorded: no
// history, no recents, no network; the search text lives in this card only.
Item {
    id: root

    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Emoji")
    readonly property string widgetContext: root.copied !== "" ? i18n.tr("Copied %1").arg(root.copied) : ""
    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 380

    readonly property string skinTone: String(pluginSettings.value("skinTone", "default"))
    readonly property int maxResults: Math.max(6, Math.min(24, Number(pluginSettings.value("maxResults", 12)) || 12))
    readonly property bool showGroup: pluginSettings.value("showGroup", true) !== false
    readonly property var table: Search.parse(data.raw)
    readonly property var matches: Search.search(root.table, field.text, root.maxResults)

    property string copied: ""
    property string pending: ""

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-emoji"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-emoji"
    }

    EmojiData {
        id: data
    }

    function copy(text: string): void {
        root.pending = text;
        root.copied = text;
        copyProcess.running = false;
        copyProcess.running = true;
    }

    Process {
        id: copyProcess

        command: ["wl-copy", root.pending]
    }

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller

        UiTextField {
            id: field

            width: parent.width
            placeholderText: i18n.tr("Search emoji")
            accessibleName: i18n.tr("Search emoji")
        }

        Flow {
            width: parent.width
            spacing: Theme.spacing.small

            Repeater {
                model: root.matches

                delegate: UiButton {
                    required property var modelData

                    text: Search.glyphFor(modelData, root.skinTone)
                    variant: "quiet"
                    tooltipText: root.showGroup ? modelData.name + " · " + root.groupName(modelData.group) : modelData.name
                    accessibleName: modelData.name
                    onClicked: root.copy(Search.glyphFor(modelData, root.skinTone))
                }
            }
        }

        UiState {
            visible: root.matches.length === 0
            width: parent.width
            kind: "empty"
            message: i18n.tr("No emoji match that search")
            glyph: "mood-smile"
        }
    }

    function groupName(group: string): string {
        const known = {
            "smileys": i18n.tr("Smileys & emotion"),
            "people": i18n.tr("People & body"),
            "nature": i18n.tr("Animals & nature"),
            "food": i18n.tr("Food & drink"),
            "travel": i18n.tr("Travel & places"),
            "activities": i18n.tr("Activities"),
            "objects": i18n.tr("Objects"),
            "symbols": i18n.tr("Symbols"),
            "flags": i18n.tr("Flags")
        };
        return known[group] || group;
    }
}
