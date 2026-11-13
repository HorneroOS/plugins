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

    implicitWidth: desktopVisible ? sizeClassWidth(sizeClass, hostAvailableWidth, 260) : showWidgetButton.implicitWidth
    implicitHeight: desktopVisible ? card.implicitHeight : showWidgetButton.implicitHeight

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
    readonly property string desktopSlot: normalizeSlot(Desktop.position("hornero-calendar", effectiveScreen))

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

    readonly property int cellWidth: compactClass ? 24 : sizeClass === "wide" ? 34 : 30
    readonly property int cellHeight: compactClass ? 18 : sizeClass === "wide" ? 26 : 22

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

        visible: root.desktopVisible
        anchors.fill: parent
        Accessible.name: i18n.tr("Calendar: %1").arg(i18n.formatDateTime(Time.date, "dddd, d MMMM yyyy"))

        Column {
            width: parent.width
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
                visible: root.showShellTime && !root.compactClass
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

                            width: root.cellWidth
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

                            width: root.cellWidth
                            height: root.cellHeight
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
                visible: !root.compactClass
                anchors.horizontalCenter: parent.horizontalCenter
                role: "caption"
                text: i18n.tr("No calendar events source is available to extensions yet; this widget shows dates only.")
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

