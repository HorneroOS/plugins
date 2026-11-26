import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Hornero Elsewhen: interactive world timezone converter for distributed teams.
// Compares UTC, Americas, Europe and Asia with a +/- hour scrubber and
// working-hour overlap indicators. Pure-JS DST-aware math over the shared
// PluginKit Time facade (no own timer, no processes, no network).
Item {
    id: root

    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: hostAvailableWidth > 0 ? Math.min(400, hostAvailableWidth) : 340
    implicitHeight: card.implicitHeight

    Subscription {
        domain: "time"
    }

    Translations {
        id: i18n

        pluginId: "hornero-elsewhen"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-elsewhen"
    }

    readonly property bool twentyFourHour: pluginSettings.value("twentyFourHour", true) !== false
    readonly property int workStartHour: Math.max(0, Math.min(23, Number(pluginSettings.value("workStartHour", 9)) || 9))
    readonly property int workEndHour: Math.max(1, Math.min(24, Number(pluginSettings.value("workEndHour", 18)) || 18))
    readonly property bool showOffHours: pluginSettings.value("showOffHours", true) !== false

    // Interactive offset in minutes from current time (-720..+720).
    property int offsetMinutes: 0

    readonly property var targetDate: new Date(Time.date.getTime() + offsetMinutes * 60000)

    readonly property var zones: [
        { "key": "utc", "region": "UTC", "name": "UTC", "stdMin": 0, "dstMin": 0, "rule": "fixed" },
        { "key": "los-angeles", "region": "Americas", "name": "Los Angeles", "stdMin": -480, "dstMin": -420, "rule": "us" },
        { "key": "new-york", "region": "Americas", "name": "New York", "stdMin": -300, "dstMin": -240, "rule": "us" },
        { "key": "buenos-aires", "region": "Americas", "name": "Buenos Aires", "stdMin": -180, "dstMin": -180, "rule": "fixed" },
        { "key": "london", "region": "Europe", "name": "London", "stdMin": 0, "dstMin": 60, "rule": "eu" },
        { "key": "madrid", "region": "Europe", "name": "Madrid", "stdMin": 60, "dstMin": 120, "rule": "eu" },
        { "key": "new-delhi", "region": "Asia", "name": "New Delhi", "stdMin": 330, "dstMin": 330, "rule": "fixed" },
        { "key": "tokyo", "region": "Asia", "name": "Tokyo", "stdMin": 540, "dstMin": 540, "rule": "fixed" }
    ]

    function sundayOfMonthUtcMs(year, month, nth, hourUtc) {
        if (nth > 0) {
            const first = new Date(Date.UTC(year, month, 1, hourUtc, 0, 0));
            const addDays = (7 - first.getUTCDay()) % 7 + (nth - 1) * 7;
            return first.getTime() + addDays * 86400000;
        }
        const last = new Date(Date.UTC(year, month + 1, 0, hourUtc, 0, 0));
        return last.getTime() - last.getUTCDay() * 86400000;
    }

    function isDst(date, zone) {
        const t = date.getTime();
        const y = date.getUTCFullYear();
        if (zone.rule === "eu")
            return t >= sundayOfMonthUtcMs(y, 2, -1, 1) && t < sundayOfMonthUtcMs(y, 9, -1, 1);
        if (zone.rule === "us") {
            const start = sundayOfMonthUtcMs(y, 2, 2, 2) - zone.stdMin * 60000;
            const end = sundayOfMonthUtcMs(y, 10, 1, 2) - zone.dstMin * 60000;
            return t >= start && t < end;
        }
        return false;
    }

    function zonedParts(date, zone) {
        const eff = isDst(date, zone) ? zone.dstMin : zone.stdMin;
        const shifted = new Date(date.getTime() + eff * 60000);
        return {
            "offsetMin": eff,
            "dst": eff !== zone.stdMin,
            "year": shifted.getUTCFullYear(),
            "month": shifted.getUTCMonth(),
            "day": shifted.getUTCDate(),
            "hours": shifted.getUTCHours(),
            "minutes": shifted.getUTCMinutes()
        };
    }

    function pad2(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function fmtHm(hours, minutes) {
        if (root.twentyFourHour)
            return pad2(hours) + ":" + pad2(minutes);
        const suffix = hours < 12 ? i18n.tr("AM") : i18n.tr("PM");
        const h12 = ((hours + 11) % 12) + 1;
        return h12 + ":" + pad2(minutes) + " " + suffix;
    }

    function offsetLabel(minutes) {
        const sign = minutes < 0 ? "-" : "+";
        const absMin = Math.abs(minutes);
        return "UTC" + sign + pad2(Math.floor(absMin / 60)) + ":" + pad2(absMin % 60);
    }

    function inWorkHours(hours) {
        return hours >= root.workStartHour && hours < root.workEndHour;
    }

    function shiftLabel() {
        if (root.offsetMinutes === 0)
            return i18n.tr("Now");
        const sign = root.offsetMinutes > 0 ? "+" : "-";
        const abs = Math.abs(root.offsetMinutes);
        const h = Math.floor(abs / 60);
        const m = abs % 60;
        return sign + h + "h" + (m > 0 ? " " + m + "m" : "");
    }

    function adjustOffset(deltaMin): void {
        root.offsetMinutes = Math.max(-720, Math.min(720, root.offsetMinutes + deltaMin));
    }

    UiCard {
        id: card

        title: i18n.tr("Elsewhen")
        channel: 15
        anchors.fill: parent
        Accessible.name: i18n.tr("Elsewhen")

        Column {
            width: parent.width
            spacing: Theme.spacing.small

            RowLayout {
                width: parent.width
                spacing: Theme.spacing.smaller

                UiButton {
                    variant: "quiet"
                    text: i18n.tr("-1h")
                    tooltipText: i18n.tr("Shift comparison one hour earlier")
                    accessibleName: i18n.tr("Shift comparison one hour earlier")
                    onClicked: root.adjustOffset(-60)
                }

                UiButton {
                    Layout.fillWidth: true
                    variant: root.offsetMinutes === 0 ? "quiet" : "primary"
                    text: root.shiftLabel()
                    tooltipText: i18n.tr("Reset comparison to current time")
                    accessibleName: i18n.tr("Reset comparison to current time")
                    onClicked: root.offsetMinutes = 0
                }

                UiButton {
                    variant: "quiet"
                    text: i18n.tr("+1h")
                    tooltipText: i18n.tr("Shift comparison one hour later")
                    accessibleName: i18n.tr("Shift comparison one hour later")
                    onClicked: root.adjustOffset(60)
                }
            }

            Repeater {
                model: root.zones

                delegate: UiStack {
                    required property var modelData

                    readonly property var parts: root.zonedParts(root.targetDate, modelData)
                    readonly property bool working: root.inWorkHours(parts.hours)

                    visible: root.showOffHours || working
                    width: parent.width
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiDetailRow {
                        Layout.fillWidth: true
                        label: modelData.name + " · " + root.offsetLabel(parts.offsetMin)
                        value: root.fmtHm(parts.hours, parts.minutes)
                    }

                    UiChip {
                        text: working ? i18n.tr("WORK") : i18n.tr("OFF")
                        tone: working ? "phosphor" : "neutral"
                    }
                }
            }

            UiText {
                width: parent.width
                role: "caption"
                text: i18n.tr("Compare UTC, Americas, Europe and Asia. Working hours: %1:00–%2:00.").arg(root.pad2(root.workStartHour)).arg(root.pad2(root.workEndHour))
            }
        }
    }
}
