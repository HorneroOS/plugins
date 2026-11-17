import QtQuick
import "EmojiSearch.js" as Search
import Hornero.PluginKit

// Emoji launcher provider: `>emoji <words>` lists matching emoji and
// Enter copies the one you pick (the shell copies the row text with
// wl-copy and closes the launcher). Search runs locally over the bundled
// Unicode 16.0 table; there is no network, no history and no stored query.
// Multi-row contract: the host reads `results` (shell docs/LAUNCHER.md).
Item {
    id: root

    property string query: ""
    readonly property var results: root.buildRows(root.query)

    readonly property string skinTone: String(pluginSettings.value("skinTone", "default"))
    readonly property int maxResults: Math.max(6, Math.min(24, Number(pluginSettings.value("maxResults", 12)) || 12))
    readonly property bool showGroup: pluginSettings.value("showGroup", true) !== false

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

    // Parsed once when the extension loads (about 1.9 thousand lines).
    readonly property var table: Search.parse(data.raw)

    function groupLabel(group: string): string {
        if (group === "smileys")
            return i18n.tr("Smileys & emotion");
        if (group === "people")
            return i18n.tr("People & body");
        if (group === "nature")
            return i18n.tr("Animals & nature");
        if (group === "food")
            return i18n.tr("Food & drink");
        if (group === "travel")
            return i18n.tr("Travel & places");
        if (group === "activities")
            return i18n.tr("Activities");
        if (group === "objects")
            return i18n.tr("Objects");
        if (group === "symbols")
            return i18n.tr("Symbols");
        if (group === "flags")
            return i18n.tr("Flags");
        return group;
    }

    function buildRows(text: string): var {
        return Search.rowsFor(root.table, text, root.skinTone, root.maxResults, root.showGroup, root.groupLabel);
    }
}
