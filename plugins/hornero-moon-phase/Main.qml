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

    implicitWidth: desktopVisible ? sizeClassWidth(sizeClass, hostAvailableWidth, 300) : showWidgetButton.implicitWidth
    implicitHeight: desktopVisible ? card.implicitHeight : showWidgetButton.implicitHeight

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
    readonly property bool compactDensity: dataDensity === "compact" || hostCompact || compactClass
    readonly property bool detailedDensity: dataDensity === "detailed"
    // DESKTOP-LOGIC-BEGIN (pure JS: slot and size-class normalization)
    function desktopSlots() {
        return ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"];
    }
    function normalizeSlot(slot) {
        return desktopSlots().indexOf(slot) >= 0 ? slot : "bottom-right";
    }
    function normalizeSizeClass(value) {
        return (value === "compact" || value === "wide") ? value : "standard";
    }
    function nextSizeClass(value) {
        const current = normalizeSizeClass(value);
        return current === "compact" ? "standard" : current === "standard" ? "wide" : "compact";
    }
    function sizeClassWidth(value, hostCap, standardWidth) {
        const limit = hostCap > 0 ? hostCap : 300;
        const current = normalizeSizeClass(value);
        if (current === "compact")
            return Math.min(220, limit);
        if (current === "wide")
            return limit;
        return Math.min(standardWidth, limit);
    }
    function sizeClassCompact(value) {
        return normalizeSizeClass(value) === "compact";
    }
    // DESKTOP-LOGIC-END

    // Desktop Widgets 2.0 (#32): the shell owns the canonical slot
    // (Desktop.position is read-only; users move widgets in Control
    // Center), so this widget only reads its slot for the current
    // display and persists its own size class and visibility as
    // typed Settings. Unknown or malformed stored values normalize
    // to the defaults above, and the hidden state always leaves a
    // visible restore button, so content can never be trapped
    // without a recovery path.
    property string sizeClass: normalizeSizeClass(String(pluginSettings.value("sizeClass", "standard")))
    property bool desktopVisible: pluginSettings.value("showOnDesktop", true) !== false
    readonly property bool compactClass: sizeClassCompact(sizeClass)
    readonly property string effectiveScreen: hostScreenName !== "" ? hostScreenName : Screen.name
    readonly property string desktopSlot: normalizeSlot(Desktop.position("hornero-moon-phase", effectiveScreen))

    function applySizeClass(value) {
        const normalized = normalizeSizeClass(value);
        sizeClass = normalized;
        pluginSettings.setValue("sizeClass", normalized);
    }
    function applyDesktopVisible(value) {
        desktopVisible = value;
        pluginSettings.setValue("showOnDesktop", value);
    }
    function resetDesktopLayout() {
        pluginSettings.resetValue("sizeClass");
        pluginSettings.resetValue("showOnDesktop");
        sizeClass = "standard";
        desktopVisible = true;
        Notifications.toast(i18n.tr("Desktop widget"), i18n.tr("Size and visibility reset to defaults."), "");
    }
    function slotLabel(slot) {
        switch (normalizeSlot(slot)) {
        case "top-left":
            return i18n.tr("Top left");
        case "top-center":
            return i18n.tr("Top center");
        case "top-right":
            return i18n.tr("Top right");
        case "middle-left":
            return i18n.tr("Middle left");
        case "middle-center":
            return i18n.tr("Middle center");
        case "middle-right":
            return i18n.tr("Middle right");
        case "bottom-left":
            return i18n.tr("Bottom left");
        case "bottom-center":
            return i18n.tr("Bottom center");
        default:
            return i18n.tr("Bottom right");
        }
    }
    function sizeClassLabel() {
        return sizeClass === "compact" ? i18n.tr("Compact") : sizeClass === "wide" ? i18n.tr("Wide") : i18n.tr("Standard");
    }

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

        visible: root.desktopVisible
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

            UiButton {
                id: desktopControlsButton

                variant: "ghost"
                text: i18n.tr("Placement & size")
                tooltipText: i18n.tr("Placement, size and visibility")
                accessibleName: i18n.tr("Desktop widget placement and size")
                onClicked: desktopPopover.toggle()
            }
        }
    }

    UiButton {
        id: showWidgetButton

        visible: !root.desktopVisible
        anchors.centerIn: parent
        variant: "ghost"
        text: i18n.tr("Show widget")
        tooltipText: i18n.tr("Show hidden desktop widget")
        accessibleName: i18n.tr("Show hidden desktop widget")
        onClicked: root.applyDesktopVisible(true)
    }

    UiPopover {
        id: desktopPopover

        target: desktopControlsButton
        accessibleName: i18n.tr("Desktop widget placement and size")

        Column {
            width: 260
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Desktop widget")
            }

            UiMetric {
                label: i18n.tr("Display")
                value: root.effectiveScreen !== "" ? root.effectiveScreen : i18n.tr("Unknown display")
            }

            UiMetric {
                label: i18n.tr("Slot")
                value: root.slotLabel(root.desktopSlot)
            }

            UiText {
                width: parent.width
                role: "caption"
                text: i18n.tr("Move this widget from Control Center, Extensions. Extensions cannot move themselves; the saved slot is kept per display and a new or unknown display uses Bottom right.")
            }

            UiMetric {
                label: i18n.tr("Size class")
                value: root.sizeClassLabel()
            }

            UiButton {
                text: i18n.tr("Use next size class")
                tooltipText: i18n.tr("Use next size class")
                accessibleName: i18n.tr("Use next size class")
                onClicked: root.applySizeClass(nextSizeClass(root.sizeClass))
            }

            UiButton {
                text: i18n.tr("Hide widget content")
                tooltipText: i18n.tr("Hide widget content")
                accessibleName: i18n.tr("Hide widget content")
                onClicked: {
                    root.applyDesktopVisible(false);
                    desktopPopover.close();
                }
            }

            UiButton {
                text: i18n.tr("Reset size and visibility")
                tooltipText: i18n.tr("Reset size and visibility")
                accessibleName: i18n.tr("Reset size and visibility")
                onClicked: root.resetDesktopLayout()
            }
        }
    }
}

