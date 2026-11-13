import QtQuick
import Hornero.PluginKit

// Moon Phase 2.0 bar surface (manifest v2): contextual compact
// indicator running the same labelled synodic approximation as
// the desktop widget. Compact hosts show only the illumination.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property string hostEdge: "top"
    property string hostSurface: "bar"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: indicator.implicitWidth
    implicitHeight: indicator.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-moon-phase"
    }

    property real cycleDays: 29.530588853
    property date knownNewMoon: new Date(Date.UTC(2000, 0, 6, 18, 14))
    property real ageDays: 0
    readonly property real illumination: (1 - Math.cos(2 * Math.PI * ageDays / cycleDays)) / 2
    readonly property int phaseIndex: Math.floor(((ageDays / cycleDays) * 8 + 0.5)) % 8

    function phaseName() {
        switch (phaseIndex) {
        case 0:
            return i18n.tr("New Moon");
        case 1:
            return i18n.tr("Waxing Crescent");
        case 2:
            return i18n.tr("First Quarter");
        case 3:
            return i18n.tr("Waxing Gibbous");
        case 4:
            return i18n.tr("Full Moon");
        case 5:
            return i18n.tr("Waning Gibbous");
        case 6:
            return i18n.tr("Last Quarter");
        default:
            return i18n.tr("Waning Crescent");
        }
    }

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

    UiButton {
        id: indicator

        variant: "ghost"
        text: root.hostCompact ? "~" + String(Math.round(root.illumination * 100)) + "%" : i18n.tr("Moon ~%1%").arg(String(Math.round(root.illumination * 100)))
        tooltipText: i18n.tr("Moon Phase: activate for details (approximate)")
        accessibleName: i18n.tr("Moon Phase details (approximate)")
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Moon Phase details (approximate)")

        Column {
            width: 260
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Moon Phase (approximate)")
            }

            UiText {
                role: "body"
                text: root.phaseName()
            }

            UiMetric {
                label: i18n.tr("Illumination (approximate)")
                value: "~" + String(Math.round(root.illumination * 100))
                unit: "%"
            }

            UiMetric {
                label: i18n.tr("Age (approximate)")
                value: i18n.tr("~%1 days").arg(root.ageDays.toFixed(1))
            }
        }
    }
}
