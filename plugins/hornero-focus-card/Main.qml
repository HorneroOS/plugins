import QtQuick
import Hornero.PluginKit

// Hornero Focus Card 2.0 - dashboard card with the date and a
// rotating original one-line focus reminder. It is the third,
// read-mostly member of the notes family: unlike Quick Notes it
// stores no note you type in the card, and unlike Quiet Notes
// its line is not yours to erase by closing the shell - the
// built-in lines ship with the extension. The only stored
// values are typed preferences: rotateSeconds (30, the 1.x
// cadence), showDate and an optional customLine (empty in 1.x
// terms: built-in lines only) that, when set in settings, leads
// the rotation. 1.x advanced only on a card-wide mouse click,
// used palette.windowText and a hard-coded Spanish date layout
// ("dddd d 'de' MMMM", whatever the locale); 2.0 adds Previous/
// Next UiButtons and a pause toggle (keyboard-operable), uses
// Ui primitives/Theme tokens, and formats the date in the
// resolved locale from the shared PluginKit Time facade behind
// a Subscription lease. The un-translated locale token "de" is
// dropped, so non-Spanish locales now read natively; Spanish
// still renders the same weekday/day/month order. Pausing and
// the current line are in-memory state, deliberately not
// settings: 1.x kept them in memory too and a reload restarts
// the rotation, exactly as before.
Item {
    id: root

    // Host context (opt-in): defaults keep a dashboard card.
    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    property int lineIndex: 0
    property bool paused: false

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Subscription {
        domain: "time"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-focus-card"
    }

    Translations {
        id: i18n

        pluginId: "hornero-focus-card"
    }

    // Typed settings: defaults reproduce 1.x exactly (date
    // shown, 30 s rotation, built-in lines only). 1.x stored no
    // settings, so no stored values migrate. Settings are read
    // when the card loads and apply from the next reload, as in
    // the other 2.0 families.
    readonly property int rotateSeconds: {
        const n = Math.round(Number(pluginSettings.value("rotateSeconds", 30)));
        return isFinite(n) ? Math.max(5, Math.min(600, n)) : 30;
    }
    readonly property bool showDate: pluginSettings.value("showDate", true) !== false
    readonly property string customLine: {
        const value = pluginSettings.value("customLine", "");
        return value ? String(value).trim() : "";
    }

    // FOCUS-LOGIC-BEGIN (pure JS: no QML types)
    function nextIndex(index, count) {
        return count > 0 ? (index + 1) % count : 0;
    }
    function previousIndex(index, count) {
        return count > 0 ? (index - 1 + count) % count : 0;
    }
    function effectiveLineCount(customLine, builtInCount) {
        const custom = customLine === undefined || customLine === null ? "" : String(customLine).trim();
        return builtInCount + (custom === "" ? 0 : 1);
    }
    function wrappedIndex(index, count) {
        if (count <= 0)
            return 0;
        return ((index % count) + count) % count;
    }
    // FOCUS-LOGIC-END

    readonly property var builtInLines: [
        i18n.tr("El futuro se construye acá."),
        i18n.tr("One thing at a time, done well."),
        i18n.tr("Build the nest before the storm."),
        i18n.tr("Small commits, honest releases."),
        i18n.tr("Measure twice, ship once.")
    ]
    readonly property var lines: root.customLine === "" ? root.builtInLines : [root.customLine].concat(root.builtInLines)
    readonly property int currentIndex: root.wrappedIndex(root.lineIndex, root.lines.length)
    readonly property string currentLine: root.lines.length > 0 ? root.lines[root.currentIndex] : ""

    Timer {
        interval: root.rotateSeconds * 1000
        repeat: true
        running: !root.paused && root.lines.length > 1
        onTriggered: root.lineIndex = root.nextIndex(root.currentIndex, root.lines.length)
    }

    UiCard {
        id: card

        anchors.centerIn: parent
        width: root.hostAvailableWidth > 0 ? Math.min(root.hostAvailableWidth, 320) : 320
        Accessible.name: i18n.tr("Focus: %1").arg(root.currentLine)

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText {
                visible: root.showDate
                role: "title"
                text: i18n.formatDateTime(Time.date, "dddd, d MMMM")
            }

            UiChip {
                text: i18n.tr("Focus reminder — nothing to save")
                tone: "neutral"
            }

            UiText {
                role: "body"
                width: parent.width
                text: root.currentLine
            }

            UiText {
                role: "caption"
                text: i18n.tr("Line %1 of %2").arg(i18n.formatNumber(root.currentIndex + 1)).arg(i18n.formatNumber(root.lines.length)) + (root.customLine !== "" && root.currentIndex === 0 ? " · " + i18n.tr("your line") : "")
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiButton {
                    variant: "ghost"
                    text: i18n.tr("Previous")
                    tooltipText: i18n.tr("Show the previous focus line")
                    accessibleName: i18n.tr("Previous focus line")
                    onClicked: root.lineIndex = root.previousIndex(root.currentIndex, root.lines.length)
                }

                UiButton {
                    text: i18n.tr("Next")
                    tooltipText: i18n.tr("Show the next focus line")
                    accessibleName: i18n.tr("Next focus line")
                    onClicked: root.lineIndex = root.nextIndex(root.currentIndex, root.lines.length)
                }

                UiToggle {
                    text: i18n.tr("Pause rotation")
                    tooltipText: i18n.tr("Keep the current line instead of rotating")
                    accessibleName: i18n.tr("Pause rotation")
                    value: root.paused
                    onToggled: root.paused = checked
                }
            }
        }
    }
}
