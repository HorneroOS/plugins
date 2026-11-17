import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Hornero Agenda 3.0 (PluginKit 3, Hornero Signal): desktop widget of date
// facts over the shared `time` provider. The host owns the module frame,
// position and size; this entrypoint lays out content: the day as a display
// readout, ISO week / quarter / day of year as readouts, days remaining as
// detail rows and the year as a partition bar with a dimension line. All
// math is UTC day arithmetic on the local calendar fields (DATE-LOGIC), so
// DST transitions cannot drift a count; the ISO week keeps the Thursday rule
// and reports the Thursday's year, which is the ISO week-year around new
// year. PluginKit has no calendar or events source, so "upcoming" means
// computed date milestones (month end, year end), never invented
// appointments.
Item {
    id: root

    // Host context: the desktop host injects the content box.
    property string hostSurface: "desktop"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Agenda")
    readonly property string widgetContext: i18n.formatDateTime(Time.date, "yyyy")

    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 300

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

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

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller
        Accessible.name: i18n.tr("Agenda: %1").arg(i18n.formatDateTime(Time.date, "dddd, d MMMM yyyy"))

        Row {
            spacing: Theme.spacing.normal

            UiText {
                anchors.verticalCenter: parent.verticalCenter
                role: "display"
                text: i18n.formatNumber(root.localDay)
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                UiText {
                    role: "body"
                    text: i18n.formatDateTime(Time.date, "dddd")
                }

                UiText {
                    role: "caption"
                    text: i18n.formatDateTime(Time.date, "MMMM yyyy")
                }
            }
        }

        UiStack {
            width: parent.width
            orientation: "horizontal"

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                visible: root.showIsoWeek
                size: "value"
                label: i18n.tr("Week")
                value: i18n.formatNumber(root.iso.week)
            }

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Quarter")
                value: i18n.tr("Q%1").arg(i18n.formatNumber(quarterOf(root.localMonth)))
            }

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                visible: root.showDayOfYear
                size: "value"
                label: i18n.tr("Year day")
                value: i18n.formatNumber(root.doy)
            }
        }

        UiDetailRow {
            visible: root.showIsoWeek && root.iso.weekYear !== root.localYear
            width: parent.width
            label: i18n.tr("ISO week-year")
            value: String(root.iso.weekYear)
        }

        UiDetailRow {
            width: parent.width
            label: i18n.tr("Days remaining in month")
            value: i18n.formatNumber(daysInMonth(root.localYear, root.localMonth) - root.localDay)
        }

        UiDetailRow {
            width: parent.width
            label: i18n.tr("Days remaining in year")
            value: i18n.formatNumber(root.diy - root.doy)
        }

        UiPartition {
            visible: root.showYearProgress
            width: parent.width
            total: root.diy
            used: root.doy
            usedLabel: i18n.tr("%1% of the year elapsed").arg(i18n.formatNumber(Math.round(100 * root.doy / root.diy)))
            Accessible.name: i18n.tr("Year progress")
        }

        UiText {
            width: parent.width
            role: "caption"
            text: i18n.tr("Date facts from the system clock; extensions have no calendar events source yet.")
        }
    }
}
