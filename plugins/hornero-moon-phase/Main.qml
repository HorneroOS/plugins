import QtQuick
import Hornero.PluginKit

// Moon Phase 2.0: desktop widget keeping the 1.x pure-JS synodic
// approximation unchanged: age since the known new moon
// 2000-01-06 18:14 UTC modulo the 29.530588853-day cycle, with
// illumination (1 - cos(2*pi*age/cycle)) / 2. Days to the next
// new/full moon are derived from the same age. No PluginKit
// facade exposes lunar data (Weather has no moon fields), so
// every value stays labelled approximate and nothing claims
// ephemeris accuracy. Refresh keeps the 1.x hourly timer; it
// only recomputes local arithmetic, no process or network.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "desktop"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: hostAvailableWidth > 0 ? Math.min(300, hostAvailableWidth) : 260
    implicitHeight: card.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-moon-phase"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-moon-phase"
    }

    readonly property bool showIllumination: pluginSettings.value("showIllumination", true) !== false
    readonly property bool showAge: pluginSettings.value("showAge", true) !== false
    readonly property bool showNextPhases: pluginSettings.value("showNextPhases", true) !== false
    readonly property string dataDensity: {
        const value = String(pluginSettings.value("dataDensity", "standard"));
        return (value === "compact" || value === "detailed") ? value : "standard";
    }
    readonly property bool compactDensity: dataDensity === "compact" || hostCompact
    readonly property bool detailedDensity: dataDensity === "detailed"

    property real cycleDays: 29.530588853
    property date knownNewMoon: new Date(Date.UTC(2000, 0, 6, 18, 14))
    property real ageDays: 0
    readonly property real illumination: (1 - Math.cos(2 * Math.PI * ageDays / cycleDays)) / 2
    readonly property int phaseIndex: Math.floor(((ageDays / cycleDays) * 8 + 0.5)) % 8
    readonly property real daysToNew: cycleDays - ageDays
    readonly property real daysToFull: ((cycleDays / 2 - ageDays) % cycleDays + cycleDays) % cycleDays

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

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("Moon Phase (approximate)")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiText {
                    role: "title"
                    text: i18n.tr("Moon Phase (approximate)")
                }

                UiChip {
                    text: i18n.tr("Approximate")
                    tone: "neutral"
                }
            }

            UiText {
                role: "body"
                Accessible.name: i18n.tr("Moon phase %1, approximately %2 percent illuminated").arg(root.phaseName()).arg(String(Math.round(root.illumination * 100)))
                text: root.phaseName()
            }

            Column {
                visible: !root.compactDensity && root.showIllumination
                width: parent.width
                spacing: Theme.spacingSmall

                UiMetric {
                    label: i18n.tr("Illumination (approximate)")
                    value: "~" + String(Math.round(root.illumination * 100))
                    unit: "%"
                }

                UiProgress {
                    width: parent.width
                    value: Math.max(0, Math.min(1, root.illumination))
                    accessibleName: i18n.tr("Illumination (approximate)")
                }
            }

            UiMetric {
                visible: !root.compactDensity && root.showAge
                label: i18n.tr("Age (approximate)")
                value: i18n.tr("~%1 days").arg(root.ageDays.toFixed(1))
            }

            Column {
                visible: !root.compactDensity && root.showNextPhases
                width: parent.width
                spacing: Theme.spacingSmall

                UiMetric {
                    label: i18n.tr("Next full moon (approximate)")
                    value: i18n.tr("in ~%1 days").arg(root.daysToFull.toFixed(1))
                }

                UiMetric {
                    label: i18n.tr("Next new moon (approximate)")
                    value: i18n.tr("in ~%1 days").arg(root.daysToNew.toFixed(1))
                }
            }

            UiText {
                visible: root.detailedDensity
                width: parent.width
                role: "caption"
                text: i18n.tr("Synodic approximation from the 2000-01-06 new moon; it ignores orbital perturbation. No PluginKit facade exposes lunar data, moonrise/moonset or an ephemeris, so those are unavailable here.")
            }
        }
    }
}
