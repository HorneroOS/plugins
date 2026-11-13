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

    implicitWidth: desktopVisible ? sizeClassWidth(sizeClass, hostAvailableWidth, 280) : showWidgetButton.implicitWidth
    implicitHeight: desktopVisible ? card.implicitHeight : showWidgetButton.implicitHeight

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
    readonly property string desktopSlot: normalizeSlot(Desktop.position("hornero-agenda", effectiveScreen))

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

        visible: root.desktopVisible
        anchors.fill: parent
        Accessible.name: i18n.tr("Agenda: %1").arg(i18n.formatDateTime(Time.date, "dddd, d MMMM yyyy"))

        Column {
            width: parent.width
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
                compact: root.hostCompact || root.compactClass

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
                visible: root.showYearProgress && !root.compactClass
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
                visible: !root.compactClass
                anchors.horizontalCenter: parent.horizontalCenter
                role: "caption"
                text: i18n.tr("Date facts from the system clock; extensions have no calendar events source yet.")
            }

            UiButton {
                id: desktopControlsButton

                anchors.horizontalCenter: parent.horizontalCenter
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

