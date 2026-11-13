import QtQuick
import Hornero.PluginKit

// Hornero Calendar 2.0 - desktop widget over PluginKit Time.
// Keeps the 1.x header (large time, full locale date, shell time
// line) and adds the current month as a grid with today marked,
// computed from the local calendar fields of Time.date with UTC
// day math (see the DATE-LOGIC block), so DST transitions in the
// system zone cannot shift a cell. There is no calendar or
// events source in PluginKit - no facade exposes appointments -
// so this widget shows the calendar itself and nothing else: no
// fabricated events backend, and upcoming entries would need a
// real shell data source first. Month and weekday names come
// from Translations.formatDateTime in the resolved locale; the
// locale's first-weekday is not exposed by the facade, so the
// week start is a typed setting instead of a guess.
Item {
    id: root

    // Host context (opt-in): defaults keep a desktop card.
    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "desktop"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

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

    // Typed settings: defaults keep every 1.x element visible
    // exactly as before (24-hour large clock, full date, shell
    // time line). The month grid is additive. 1.x stored no
    // settings, so no stored values migrate. Settings are read
    // when the widget loads and apply from the next reload, as
    // in the other 2.0 families.
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

    UiCard {
        id: card

        anchors.centerIn: parent
        Accessible.name: i18n.tr("Calendar: %1").arg(i18n.formatDateTime(Time.date, "dddd, d MMMM yyyy"))

        Column {
            spacing: Theme.spacingSmall

            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "title"
                text: i18n.formatDateTime(Time.date, root.twentyFourHour ? "HH:mm" : "h:mm ap")
            }

            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "body"
                text: i18n.formatDateTime(Time.date, "dddd, d MMMM yyyy")
            }

            UiText {
                visible: root.showShellTime
                anchors.horizontalCenter: parent.horizontalCenter
                role: "caption"
                text: Time.timeStr
            }

            Column {
                visible: root.showMonthGrid
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingSmall

                UiText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "body"
                    text: i18n.formatDateTime(Time.date, "MMMM yyyy")
                }

                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 7
                    columnSpacing: 2
                    rowSpacing: 2

                    Repeater {
                        model: root.headers

                        delegate: Text {
                            required property string modelData

                            width: 30
                            height: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.onSurfaceVariant
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            text: modelData
                        }
                    }

                    Repeater {
                        model: root.cells

                        delegate: Rectangle {
                            required property int modelData

                            width: 30
                            height: 22
                            radius: Theme.roundingSmall
                            color: modelData === Time.date.getDate() ? Theme.primaryContainer : Theme.surface

                            Text {
                                anchors.centerIn: parent
                                color: modelData === Time.date.getDate() ? Theme.onPrimaryContainer : Theme.onSurface
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: modelData === Time.date.getDate()
                                text: modelData > 0 ? i18n.formatNumber(modelData) : ""
                            }
                        }
                    }
                }
            }

            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "caption"
                text: i18n.tr("No calendar events source is available to extensions yet; this widget shows dates only.")
            }
        }
    }
}
