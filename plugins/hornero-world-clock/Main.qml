import QtQuick
import Hornero.PluginKit

// Hornero World Clock 2.0 - dashboard card over PluginKit Time.
// PluginKit Time exposes only the local system clock (date, hours,
// minutes, seconds, timeStr, format); shell PluginKit sources have
// no IANA timezone database and no zoned-conversion call, and the
// Qt JS engine ignores the timeZone option of toLocaleString, so
// other zones are computed here in pure JS from UTC, exactly as
// 1.x did, now with a rule table: fixed-offset zones, the EU rule
// (last Sunday of March/October 01:00 UTC, the 1.x Madrid rule,
// unchanged), the US rule (second Sunday of March / first Sunday
// of November, 02:00 local) and southern-hemisphere rules for
// Sydney/Auckland. Every row is labelled with the offset actually
// applied and a DST mark when daylight time is in effect. The
// rule table is the honest limit: a government changing its DST
// law needs a code update here; no zone outside the table is
// offered. tests/test_time_logic.py checks this block against
// the system timezone database around every transition.
// Time comes from the shared Time facade behind a Subscription
// lease (event-pushed, second precision); 1.x ran its own 1s
// timer, which 2.0 drops.
Item {
    id: root

    // Host context (opt-in): defaults keep a roomy dashboard card.
    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    Subscription {
        domain: "time"
    }

    Translations {
        id: i18n

        pluginId: "hornero-world-clock"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-world-clock"
    }

    // Typed settings: every default equals the 1.x hardcoded rows
    // (Buenos Aires, Madrid, Tokyo in that order, local and UTC
    // rows shown, 24-hour times with seconds), so existing
    // installs see no change. 1.x stored no settings, so no
    // stored values migrate. Settings are read when the card
    // loads and apply from the next reload, as in the other
    // 2.0 families.
    function citySetting(key, fallback) {
        const value = pluginSettings.value(key, fallback);
        return root.zoneTable()[value] ? value : fallback;
    }
    readonly property var cityKeys: [citySetting("city1", "buenos-aires"), citySetting("city2", "madrid"), citySetting("city3", "tokyo")]
    readonly property bool showUtc: pluginSettings.value("showUtc", true) !== false
    readonly property bool showLocal: pluginSettings.value("showLocal", true) !== false
    readonly property bool showSeconds: pluginSettings.value("showSeconds", true) !== false
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

    function utcParts(date) {
        return root.zonedParts(date, root.zoneTable()["utc"]);
    }

    // Locale date for a zoned wall-clock date: a local Date at noon
    // with the same calendar fields formats through the resolved
    // locale without re-interpreting the instant in the local zone.
    function zonedDateText(parts) {
        return i18n.formatDateTime(new Date(parts.year, parts.month, parts.day, 12, 0, 0), "ddd d MMM");
    }

    function dayRelation(parts, localDate) {
        const zonedDay = Date.UTC(parts.year, parts.month, parts.day) / 86400000;
        const localDay = Date.UTC(localDate.getFullYear(), localDate.getMonth(), localDate.getDate()) / 86400000;
        if (zonedDay === localDay - 1)
            return i18n.tr("yesterday");
        if (zonedDay === localDay + 1)
            return i18n.tr("tomorrow");
        return "";
    }

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("World Clock")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("World Clock")
            }

            UiMetric {
                visible: root.showLocal
                label: i18n.tr("Local")
                value: root.localTimeText(Time.date)
            }

            UiMetric {
                visible: root.showUtc
                label: i18n.tr("UTC")
                value: {
                    const p = root.utcParts(Time.date);
                    return root.fmtHms(p.hours, p.minutes, p.seconds);
                }
            }

            Repeater {
                model: root.cityKeys

                delegate: Column {
                    required property string modelData

                    width: parent.width
                    spacing: Theme.spacingSmall

                    UiStack {
                        orientation: root.hostOrientation
                        compact: root.hostCompact

                        UiMetric {
                            label: root.cityName(modelData)
                            value: {
                                const p = root.zonedParts(Time.date, root.zoneTable()[modelData]);
                                return root.fmtHms(p.hours, p.minutes, p.seconds) + " (" + root.offsetLabel(p.offsetMin) + ")";
                            }
                        }

                        UiChip {
                            visible: root.zonedParts(Time.date, root.zoneTable()[modelData]).dst
                            text: i18n.tr("DST")
                            tone: "primary"
                        }
                    }

                    UiText {
                        role: "caption"
                        text: {
                            const p = root.zonedParts(Time.date, root.zoneTable()[modelData]);
                            const rel = root.dayRelation(p, Time.date);
                            return root.zonedDateText(p) + (rel !== "" ? " · " + rel : "");
                        }
                    }
                }
            }

            UiText {
                role: "caption"
                text: i18n.tr("Offsets follow the DST rules built into this extension; there is no system timezone database for other zones.")
            }
        }
    }
}
