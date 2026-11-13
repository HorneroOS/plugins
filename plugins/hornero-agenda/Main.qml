import QtQuick
import Hornero.PluginKit

// Hornero Agenda 2.0 - desktop widget of date facts over
// PluginKit Time. Keeps every 1.x figure (weekday/day/month,
// ISO week, day of year, days remaining in the year) and adds
// facts that are equally derived from the system clock alone:
// ISO week-year, quarter, days remaining in the month and the
// elapsed fraction of the year. All math is UTC day arithmetic
// on the local calendar fields (see the DATE-LOGIC block), so
// DST transitions cannot drift a count; the ISO week keeps the
// Thursday rule from 1.x and now also reports the Thursday's
// year, which is the ISO week-year around new year. There is
// no calendar or events source in PluginKit, so "upcoming"
// here means computed date milestones (month end, year end),
// never invented appointments.
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

        pluginId: "hornero-agenda"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-agenda"
    }

    // Typed settings: defaults keep every 1.x row visible exactly
    // as before; the year-progress bar is additive. 1.x stored no
    // settings, so no stored values migrate. Settings are read
    // when the widget loads and apply from the next reload, as
    // in the other 2.0 families.
    readonly property bool showIsoWeek: pluginSettings.value("showIsoWeek", true) !== false
    readonly property bool showDayOfYear: pluginSettings.value("showDayOfYear", true) !== false
    readonly property bool showYearProgress: pluginSettings.value("showYearProgress", true) !== false

    // DATE-LOGIC-BEGIN (pure JS on calendar fields, UTC day math)
    function isLeap(year) { return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0; }
    function daysInYearFields(year) { return isLeap(year) ? 366 : 365; }
    function daysInMonth(year, month) {
        return new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
    }
    function dayOfYearFields(year, month, day) {
        return Math.floor((Date.UTC(year, month, day) - Date.UTC(year, 0, 1)) / 86400000) + 1;
    }
    function isoWeekFields(year, month, day) {
        const date = new Date(Date.UTC(year, month, day));
        const dayNum = date.getUTCDay() || 7;
        date.setUTCDate(date.getUTCDate() + 4 - dayNum);
        const weekYear = date.getUTCFullYear();
        const week = Math.ceil(((date.getTime() - Date.UTC(weekYear, 0, 1)) / 86400000 + 1) / 7);
        return { "week": week, "weekYear": weekYear };
    }
    function quarterOf(month) { return Math.floor(month / 3) + 1; }
    // DATE-LOGIC-END

    readonly property int localYear: Time.date.getFullYear()
    readonly property int localMonth: Time.date.getMonth()
    readonly property int localDay: Time.date.getDate()
    readonly property int doy: dayOfYearFields(localYear, localMonth, localDay)
    readonly property int diy: daysInYearFields(localYear)
    readonly property var iso: isoWeekFields(localYear, localMonth, localDay)

    UiCard {
        id: card

        anchors.centerIn: parent
        Accessible.name: i18n.tr("Agenda: %1").arg(i18n.formatDateTime(Time.date, "dddd, d MMMM yyyy"))

        Column {
            spacing: Theme.spacingSmall

            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "title"
                text: i18n.tr("Agenda")
            }

            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "body"
                text: i18n.formatDateTime(Time.date, "dddd, d MMMM yyyy")
            }

            UiStack {
                anchors.horizontalCenter: parent.horizontalCenter
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {
                    label: i18n.tr("Weekday")
                    value: i18n.formatDateTime(Time.date, "dddd")
                }

                UiMetric {
                    label: i18n.tr("Day")
                    value: i18n.formatNumber(root.localDay)
                }

                UiMetric {
                    label: i18n.tr("Month")
                    value: i18n.formatDateTime(Time.date, "MMMM")
                }

                UiMetric {
                    label: i18n.tr("Quarter")
                    value: i18n.tr("Q%1").arg(i18n.formatNumber(quarterOf(root.localMonth)))
                }
            }

            UiMetric {
                visible: root.showIsoWeek
                anchors.horizontalCenter: parent.horizontalCenter
                label: i18n.tr("ISO week")
                value: i18n.tr("%1 of %2").arg(i18n.formatNumber(root.iso.week)).arg(i18n.formatNumber(root.iso.weekYear))
            }

            UiMetric {
                visible: root.showDayOfYear
                anchors.horizontalCenter: parent.horizontalCenter
                label: i18n.tr("Day of year")
                value: i18n.formatNumber(root.doy)
            }

            UiMetric {
                anchors.horizontalCenter: parent.horizontalCenter
                label: i18n.tr("Days remaining in month")
                value: i18n.formatNumber(daysInMonth(root.localYear, root.localMonth) - root.localDay)
            }

            UiMetric {
                anchors.horizontalCenter: parent.horizontalCenter
                label: i18n.tr("Days remaining in year")
                value: i18n.formatNumber(root.diy - root.doy)
            }

            Column {
                visible: root.showYearProgress
                width: parent.width
                spacing: Theme.spacingSmall

                UiProgress {
                    width: parent.width
                    value: root.diy > 0 ? root.doy / root.diy : 0
                    accessibleName: i18n.tr("Year progress")
                }

                UiText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "caption"
                    text: i18n.tr("%1% of the year elapsed").arg(i18n.formatNumber(Math.round(100 * root.doy / root.diy)))
                }
            }

            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "caption"
                text: i18n.tr("Date facts from the system clock; extensions have no calendar events source yet.")
            }
        }
    }
}
