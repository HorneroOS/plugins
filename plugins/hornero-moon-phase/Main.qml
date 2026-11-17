import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Hornero Moon Phase 3.0 (PluginKit 3, Hornero Signal): desktop widget
// keeping the 1.x pure-JS synodic approximation unchanged: age since the
// known new moon 2000-01-06 18:14 UTC modulo the 29.530588853-day cycle,
// with illumination (1 - cos(2*pi*age/cycle)) / 2. Days to the next
// new/full moon are derived from the same age. No PluginKit facade exposes
// lunar data (Weather has no moon fields), so every value stays labelled
// approximate and nothing claims ephemeris accuracy. The disc is drawn from
// the same computed illumination, one scanline per pixel row (northern
// hemisphere orientation). Refresh keeps the hourly timer; it only
// recomputes local arithmetic, no process or network. The host owns the
// module frame, position and size.
Item {
    id: root

    // Host context: the desktop host injects the content box.
    property string hostSurface: "desktop"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Moon Phase")
    readonly property string widgetContext: i18n.tr("Approximate")

    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 300

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

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

    readonly property bool waxing: ageDays < cycleDays / 2
    readonly property int discSize: 96

    onIlluminationChanged: disc.requestPaint()
    onWaxingChanged: disc.requestPaint()

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller

        Row {
            spacing: Theme.spacing.normal

            Canvas {
                id: disc

                width: root.discSize
                height: root.discSize
                Accessible.name: i18n.tr("Moon phase %1, approximately %2 percent illuminated").arg(root.phaseName()).arg(String(Math.round(root.illumination * 100)))
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const r = width / 2 - 1;
                    const cx = width / 2;
                    const cy = height / 2;
                    // Unlit disc.
                    ctx.fillStyle = Theme.palette.sunken;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.fill();
                    // Lit part: one scanline per row between the limb and the
                    // terminator (k = 1 - 2f: -1 full, 0 half, 1 new).
                    const f = root.illumination;
                    const k = 1 - 2 * f;
                    ctx.fillStyle = Theme.palette.ink;
                    for (let y = -r; y <= r; y++) {
                        const w = Math.sqrt(Math.max(0, r * r - y * y));
                        const t = w * k;
                        const x0 = root.waxing ? t : -w;
                        const x1 = root.waxing ? w : -t;
                        if (x1 > x0)
                            ctx.fillRect(cx + x0, cy + y, x1 - x0, 1);
                    }
                    ctx.strokeStyle = Theme.palette.ruleStrong;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.stroke();
                }
                Component.onCompleted: requestPaint()
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                UiText {
                    role: "subtitle"
                    text: root.phaseName()
                }

                UiText {
                    visible: root.showIllumination && !root.compactDensity
                    role: "readout"
                    text: "~" + String(Math.round(root.illumination * 100)) + " %"
                }

                UiText {
                    visible: root.showIllumination && !root.compactDensity
                    role: "caption"
                    text: i18n.tr("Illumination (approximate)")
                }
            }
        }

        UiDetailRow {
            visible: !root.compactDensity && root.showAge
            width: parent.width
            label: i18n.tr("Age")
            value: i18n.tr("~%1 days").arg(root.ageDays.toFixed(1))
        }

        UiDetailRow {
            visible: !root.compactDensity && root.showNextPhases
            width: parent.width
            label: i18n.tr("Next full")
            value: i18n.tr("in ~%1 days").arg(root.daysToFull.toFixed(1))
        }

        UiDetailRow {
            visible: !root.compactDensity && root.showNextPhases
            width: parent.width
            label: i18n.tr("Next new")
            value: i18n.tr("in ~%1 days").arg(root.daysToNew.toFixed(1))
        }

        UiText {
            visible: root.detailedDensity
            width: parent.width
            role: "caption"
            text: i18n.tr("Synodic approximation from the 2000-01-06 new moon; it ignores orbital perturbation. No PluginKit facade exposes lunar data, moonrise/moonset or an ephemeris, so those are unavailable here.")
        }
    }
}
