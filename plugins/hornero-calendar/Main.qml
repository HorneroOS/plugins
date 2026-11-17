import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Hornero Calendar 3.0 (PluginKit 3, Hornero Signal): desktop widget over
// the shared `time` provider. The host owns the module frame, header,
// position, size and edit mode; this entrypoint lays out content in the
// host's content box: a display clock, the full locale date and the current
// month as a square-celled grid with today in `signal`. Cells come from the
// local calendar fields of Time.date with UTC day math (DATE-LOGIC), so DST
// transitions cannot shift a cell. PluginKit has no calendar or events
// source, so the widget shows the calendar itself and nothing else: no
// fabricated events. Month and weekday names come from
// Translations.formatDateTime in the resolved locale; the locale's
// first-weekday is not exposed by the facade, so the week start is a typed
// setting rather than a guess.
Item {
    id: root

    // Host context: the desktop host injects the content box.
    property string hostSurface: "desktop"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property string hostScreenName: ""

    // Host frame header (shell docs/PLUGINS.md "Desktop widgets").
    readonly property string widgetTitle: i18n.tr("Calendar")
    readonly property string widgetContext: i18n.formatDateTime(Time.date, "MMMM yyyy")

    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 300

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Subscription {
        domain: "time"
    }

    Translations {
        id: i18n

        pluginId: "hornero-calendar"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-calendar"
    }

    readonly property bool twentyFourHour: pluginSettings.value("twentyFourHour", true) !== false
    readonly property bool showShellTime: pluginSettings.value("showShellTime", true) !== false
    readonly property bool showMonthGrid: pluginSettings.value("showMonthGrid", true) !== false
    readonly property string weekStart: {
        const value = pluginSettings.value("weekStart", "monday");
        return value === "sunday" ? "sunday" : "monday";
    }

    // DATE-LOGIC-BEGIN (pure JS on calendar fields, UTC day math)
    function daysInMonth(year, month) {
        return new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
    }
    function firstWeekday(year, month) {
        return new Date(Date.UTC(year, month, 1)).getUTCDay();
    }
    function monthCells(year, month, weekStartDay) {
        const blanks = (firstWeekday(year, month) - weekStartDay + 7) % 7;
        const total = blanks + daysInMonth(year, month);
        const cells = [];
        for (let i = 0; i < blanks; i++)
            cells.push(0);
        for (let day = 1; day <= daysInMonth(year, month); day++)
            cells.push(day);
        while (cells.length % 7 !== 0)
            cells.push(0);
        return cells;
    }
    // DATE-LOGIC-END

    readonly property int weekStartDay: weekStart === "sunday" ? 0 : 1
    readonly property var cells: monthCells(Time.date.getFullYear(), Time.date.getMonth(), weekStartDay)
    readonly property int gap: 2
    readonly property int cellWidth: Math.max(18, Math.floor((contentWidth - gap * 6) / 7))
    readonly property int cellHeight: 26

    function weekdayHeaders() {
        // 1 January 2024 was a Monday; noon local dates that week
        // format to the resolved locale's weekday abbreviations.
        const names = [];
        for (let i = 0; i < 7; i++) {
            const offset = (weekStartDay + i + 6) % 7;
            names.push(i18n.formatDateTime(new Date(2024, 0, 1 + offset, 12, 0, 0), "ddd"));
        }
        return names;
    }
    readonly property var headers: weekdayHeaders()

    // Column index (0 = first column) of Saturday and Sunday for muting.
    function isWeekend(column) {
        const day = (weekStartDay + column) % 7;
        return day === 0 || day === 6;
    }

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller
        Accessible.name: i18n.tr("Calendar: %1").arg(i18n.formatDateTime(Time.date, "dddd, d MMMM yyyy"))

        Row {
            spacing: Theme.spacing.normal

            UiText {
                anchors.verticalCenter: parent.verticalCenter
                role: "display"
                text: i18n.formatDateTime(Time.date, root.twentyFourHour ? "HH:mm" : "h:mm ap")
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                UiText {
                    role: "body"
                    text: i18n.formatDateTime(Time.date, "dddd")
                }

                UiText {
                    role: "caption"
                    text: i18n.formatDateTime(Time.date, "d MMMM yyyy")
                }

                UiText {
                    visible: root.showShellTime
                    role: "caption"
                    text: Time.timeStr
                }
            }
        }

        Grid {
            visible: root.showMonthGrid
            columns: 7
            columnSpacing: root.gap
            rowSpacing: root.gap

            Repeater {
                model: root.headers

                delegate: UiText {
                    required property string modelData
                    required property int index

                    width: root.cellWidth
                    horizontalAlignment: Text.AlignHCenter
                    role: "eyebrow"
                    color: root.isWeekend(index) ? Theme.palette.inkFaint : Theme.palette.inkMuted
                    text: modelData
                }
            }

            Repeater {
                model: root.cells

                delegate: Rectangle {
                    id: cell

                    required property int modelData
                    required property int index
                    readonly property bool today: modelData > 0 && modelData === Time.date.getDate()

                    width: root.cellWidth
                    height: root.cellHeight
                    radius: 0
                    color: today ? Theme.palette.signal : modelData > 0 ? Theme.palette.sunken : "transparent"
                    border.width: modelData > 0 && !today ? 1 : 0
                    border.color: Theme.palette.rule

                    UiText {
                        anchors.centerIn: parent
                        role: "value"
                        color: cell.today ? Theme.palette.onSignal : root.isWeekend(cell.index % 7) ? Theme.palette.inkMuted : Theme.palette.ink
                        text: cell.modelData > 0 ? i18n.formatNumber(cell.modelData) : ""
                    }
                }
            }
        }

        UiText {
            width: parent.width
            role: "caption"
            text: i18n.tr("No calendar events source is available to extensions yet; this widget shows dates only.")
        }
    }
}
