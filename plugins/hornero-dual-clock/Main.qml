import QtQuick
import Hornero.PluginKit

// Hornero Dual Clock 2.0 - local time and a second zone side by
// side in the bar. Compact indicator opening a host-owned
// popover with locale dates, applied offsets and the offset
// difference. Time comes from the shared PluginKit Time facade
// behind a Subscription lease; 1.x ran its own 1s timer and used
// the raw palette colour, both replaced here. The second zone
// defaults to UTC, so the default two-line label is byte-for-byte
// the 1.x one. PluginKit has no timezone database or zoned
// conversion (see the World Clock README), so non-UTC zones use
// the same pure-JS rule table as World Clock, kept verbatim in
// the TZ-LOGIC block below and checked by
// tests/test_time_logic.py.
Item {
    id: root

    // Host context (opt-in): defaults keep a roomy horizontal bar.
    property string hostOrientation: "horizontal"
    property string hostEdge: "top"
    property string hostSurface: "bar"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: indicator.implicitWidth
    implicitHeight: indicator.implicitHeight

    Subscription {
        domain: "time"
    }

    Translations {
        id: i18n

        pluginId: "hornero-dual-clock"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-dual-clock"
    }

    // Typed settings: every default equals the 1.x hardcoded
    // label (local HH:mm over UTC HH:mm UTC, 24-hour, no
    // seconds), so existing installs see no change. 1.x stored
    // no settings, so no stored values migrate. Settings are
    // read when the indicator loads and apply from the next
    // reload, as in the other 2.0 families.
    readonly property string secondZone: {
        const value = pluginSettings.value("secondZone", "utc");
        return root.zoneTable()[value] ? value : "utc";
    }
    readonly property bool showSeconds: pluginSettings.value("showSeconds", false) === true
    readonly property bool twentyFourHour: pluginSettings.value("twentyFourHour", true) !== false

    // TZ-LOGIC-BEGIN (pure JS: no QML types, UTC field math only)
    function zoneTable() {
        return {
            "utc": { "name": "UTC", "stdMin": 0, "dstMin": 0, "rule": "fixed" },
            "buenos-aires": { "name": "Buenos Aires", "stdMin": -180, "dstMin": -180, "rule": "fixed" },
            "new-york": { "name": "New York", "stdMin": -300, "dstMin": -240, "rule": "us" },
            "chicago": { "name": "Chicago", "stdMin": -360, "dstMin": -300, "rule": "us" },
            "los-angeles": { "name": "Los Angeles", "stdMin": -480, "dstMin": -420, "rule": "us" },
            "london": { "name": "London", "stdMin": 0, "dstMin": 60, "rule": "eu" },
            "madrid": { "name": "Madrid", "stdMin": 60, "dstMin": 120, "rule": "eu" },
            "berlin": { "name": "Berlin", "stdMin": 60, "dstMin": 120, "rule": "eu" },
            "new-delhi": { "name": "New Delhi", "stdMin": 330, "dstMin": 330, "rule": "fixed" },
            "tokyo": { "name": "Tokyo", "stdMin": 540, "dstMin": 540, "rule": "fixed" },
            "sydney": { "name": "Sydney", "stdMin": 600, "dstMin": 660, "rule": "south", "startMonth": 9, "startNth": 1 },
            "auckland": { "name": "Auckland", "stdMin": 720, "dstMin": 780, "rule": "south", "startMonth": 8, "startNth": -1 }
        };
    }
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
        if (zone.rule === "eu") {
            return t >= sundayOfMonthUtcMs(y, 2, -1, 1) && t < sundayOfMonthUtcMs(y, 9, -1, 1);
        }
        if (zone.rule === "us") {
            const start = sundayOfMonthUtcMs(y, 2, 2, 2) - zone.stdMin * 60000;
            const end = sundayOfMonthUtcMs(y, 10, 1, 2) - zone.dstMin * 60000;
            return t >= start && t < end;
        }
        if (zone.rule === "south") {
            const start = sundayOfMonthUtcMs(y, zone.startMonth, zone.startNth, 2) - zone.stdMin * 60000;
            const end = sundayOfMonthUtcMs(y, 3, 1, 3) - zone.dstMin * 60000;
            return t >= start || t < end;
        }
        return false;
    }
    function effectiveOffsetMin(date, zone) {
        return isDst(date, zone) ? zone.dstMin : zone.stdMin;
    }
    function zonedParts(date, zone) {
        const eff = effectiveOffsetMin(date, zone);
        const shifted = new Date(date.getTime() + eff * 60000);
        return {
            "offsetMin": eff, "dst": eff !== zone.stdMin,
            "year": shifted.getUTCFullYear(), "month": shifted.getUTCMonth(),
            "day": shifted.getUTCDate(), "weekday": shifted.getUTCDay(),
            "hours": shifted.getUTCHours(), "minutes": shifted.getUTCMinutes(),
            "seconds": shifted.getUTCSeconds()
        };
    }
    function pad2(n) {
        return (n < 10 ? "0" : "") + n;
    }
    function offsetLabel(minutes) {
        const sign = minutes < 0 ? "-" : "+";
        const absMin = Math.abs(minutes);
        return "UTC" + sign + pad2(Math.floor(absMin / 60)) + ":" + pad2(absMin % 60);
    }
    // TZ-LOGIC-END

    function cityName(key) {
        if (key === "utc")
            return i18n.tr("UTC");
        if (key === "buenos-aires")
            return i18n.tr("Buenos Aires");
        if (key === "new-york")
            return i18n.tr("New York");
        if (key === "chicago")
            return i18n.tr("Chicago");
        if (key === "los-angeles")
            return i18n.tr("Los Angeles");
        if (key === "london")
            return i18n.tr("London");
        if (key === "madrid")
            return i18n.tr("Madrid");
        if (key === "berlin")
            return i18n.tr("Berlin");
        if (key === "new-delhi")
            return i18n.tr("New Delhi");
        if (key === "tokyo")
            return i18n.tr("Tokyo");
        if (key === "sydney")
            return i18n.tr("Sydney");
        if (key === "auckland")
            return i18n.tr("Auckland");
        return key;
    }

    function fmtHms(hours, minutes, seconds) {
        if (root.twentyFourHour)
            return pad2(hours) + ":" + pad2(minutes) + (root.showSeconds ? ":" + pad2(seconds) : "");
        const suffix = hours < 12 ? i18n.tr("AM") : i18n.tr("PM");
        const h12 = ((hours + 11) % 12) + 1;
        return h12 + ":" + pad2(minutes) + (root.showSeconds ? ":" + pad2(seconds) : "") + " " + suffix;
    }

    function localTimeText(date) {
        return root.fmtHms(date.getHours(), date.getMinutes(), date.getSeconds());
    }

    function secondParts(date) {
        return root.zonedParts(date, root.zoneTable()[root.secondZone]);
    }

    function secondSuffix(parts) {
        return root.secondZone === "utc" ? i18n.tr("UTC") : root.offsetLabel(parts.offsetMin);
    }

    function zonedDateText(parts) {
        return i18n.formatDateTime(new Date(parts.year, parts.month, parts.day, 12, 0, 0), "dddd, d MMMM yyyy");
    }

    function differenceText(date, parts) {
        const diffMin = parts.offsetMin - (-date.getTimezoneOffset());
        if (diffMin === 0)
            return i18n.tr("Same offset as local time");
        const sign = diffMin > 0 ? "+" : "-";
        const absMin = Math.abs(diffMin);
        const hours = Math.floor(absMin / 60);
        const mins = absMin % 60;
        return sign + i18n.formatNumber(hours) + ":" + pad2(mins) + " " + (diffMin > 0 ? i18n.tr("ahead of local time") : i18n.tr("behind local time"));
    }

    UiButton {
        id: indicator

        variant: "ghost"
        text: {
            const p = root.secondParts(Time.date);
            return root.localTimeText(Time.date) + "\n" + root.fmtHms(p.hours, p.minutes, p.seconds) + " " + root.secondSuffix(p);
        }
        tooltipText: i18n.tr("Dual clock: activate for time zone details")
        accessibleName: {
            const p = root.secondParts(Time.date);
            return i18n.tr("Local time %1, %2 time %3").arg(root.localTimeText(Time.date)).arg(root.cityName(root.secondZone)).arg(root.fmtHms(p.hours, p.minutes, p.seconds));
        }
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Dual Clock")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Dual Clock")
            }

            UiMetric {
                label: i18n.tr("Local")
                value: root.localTimeText(Time.date) + " (" + root.offsetLabel(-Time.date.getTimezoneOffset()) + ")"
            }

            UiText {
                role: "caption"
                text: i18n.formatDateTime(Time.date, "dddd, d MMMM yyyy")
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {
                    label: root.cityName(root.secondZone)
                    value: {
                        const p = root.secondParts(Time.date);
                        return root.fmtHms(p.hours, p.minutes, p.seconds) + " (" + root.offsetLabel(p.offsetMin) + ")";
                    }
                }

                UiChip {
                    visible: root.secondParts(Time.date).dst
                    text: i18n.tr("DST")
                    tone: "primary"
                }
            }

            UiText {
                role: "caption"
                text: root.zonedDateText(root.secondParts(Time.date))
            }

            UiText {
                role: "caption"
                text: root.differenceText(Time.date, root.secondParts(Time.date))
            }

            UiText {
                role: "caption"
                text: i18n.tr("Other zones follow the DST rules built into this extension; there is no system timezone database for zones outside its table.")
            }
        }
    }
}
