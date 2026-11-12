import QtQuick
import Hornero.PluginKit

// Hornero Agenda - desktop widget, pure Date math over
// PluginKit Time (date). ISO week uses the Thursday rule:
// shift to the Thursday of the current week, then count
// weeks from 1 January of that Thursday's year.
Item {
    id: root

    implicitWidth: content.implicitWidth + 24
    implicitHeight: content.implicitHeight + 24

    function isLeap(year) { return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0; }
    function dayOfYear(d) {
        var start = Date.UTC(d.getFullYear(), 0, 1);
        var current = Date.UTC(d.getFullYear(), d.getMonth(), d.getDate());
        return Math.floor((current - start) / 86400000) + 1;
    }
    function isoWeek(d) {
        var date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        var dayNum = date.getUTCDay() || 7;
        date.setUTCDate(date.getUTCDate() + 4 - dayNum);
        var yearStart = Date.UTC(date.getUTCFullYear(), 0, 1);
        return Math.ceil(((date.getTime() - yearStart) / 86400000 + 1) / 7);
    }
    function daysInYear(d) { return isLeap(d.getFullYear()) ? 366 : 365; }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurface
            font.pixelSize: 14
            font.bold: true
            text: "Agenda"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurface
            font.pixelSize: 16
            Accessible.name: "Today is " + Qt.formatDateTime(Time.date, "dddd, d MMMM yyyy")
            text: Qt.formatDateTime(Time.date, "dddd, d MMMM yyyy")
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
            text: "Weekday: " + Qt.formatDateTime(Time.date, "dddd") + "  Day: " + Qt.formatDateTime(Time.date, "d") + "  Month: " + Qt.formatDateTime(Time.date, "MMMM")
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
            text: "ISO week: " + root.isoWeek(Time.date)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
            text: "Day of year: " + root.dayOfYear(Time.date)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
            text: "Days remaining in year: " + (root.daysInYear(Time.date) - root.dayOfYear(Time.date))
        }
    }
}
