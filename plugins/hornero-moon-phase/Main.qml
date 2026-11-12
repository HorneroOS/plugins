import QtQuick
import Hornero.PluginKit

// Hornero Moon Phase - desktop widget, pure-JS synodic
// approximation: age since the known new moon 2000-01-06 18:14 UTC
// modulo the 29.530588853-day synodic cycle. Illumination is
// (1 - cos(2*pi*age/cycle)) / 2. Always labelled approximate.
Item {
    id: root

    implicitWidth: content.implicitWidth + 24
    implicitHeight: content.implicitHeight + 24

    property real cycleDays: 29.530588853
    property date knownNewMoon: new Date(Date.UTC(2000, 0, 6, 18, 14))
    property var names: ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"]

    property real ageDays: 0
    property real illumination: (1 - Math.cos(2 * Math.PI * ageDays / cycleDays)) / 2
    property string phaseName: names[Math.floor(((ageDays / cycleDays) * 8 + 0.5)) % 8]

    function refresh() {
        var days = (Date.now() - knownNewMoon.getTime()) / 86400000;
        ageDays = ((days % cycleDays) + cycleDays) % cycleDays;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 3600000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Column {
        id: content

        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurface
            font.pixelSize: 14
            font.bold: true
            text: "Moon Phase (approximate)"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurface
            font.pixelSize: 16
            Accessible.name: "Moon phase " + root.phaseName + ", approximately " + Math.round(root.illumination * 100) + " percent illuminated"
            text: root.phaseName
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
            text: "Illumination: ~" + Math.round(root.illumination * 100) + "% (approximate)"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
            text: "Age: ~" + root.ageDays.toFixed(1) + " days (approximate)"
        }
    }
}
