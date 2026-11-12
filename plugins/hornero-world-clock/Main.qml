import QtQuick
import Hornero.PluginKit

// Hornero World Clock - dashboard card over PluginKit Time.
// Shows local time, UTC and three fixed cities. Offsets are computed
// in pure JS (Qt V4 Date ignores toLocaleString timeZone, so that API
// is NOT used): Buenos Aires UTC-3 and Tokyo UTC+9 year-round;
// Madrid follows the EU rule (UTC+1, UTC+2 from the last Sunday of
// March 01:00 UTC to the last Sunday of October 01:00 UTC). Rows are
// labelled with the offset actually applied.
Item {
    id: root

    property var now: Time.date

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    // city, IANA zone (Madrid rule handled in effectiveOffsetMin), base offset in minutes
    readonly property var cities: [
        { "name": "Buenos Aires", "zone": "America/Argentina/Buenos_Aires", "offsetMin": -180 },
        { "name": "Madrid", "zone": "Europe/Madrid", "offsetMin": 60 },
        { "name": "Tokyo", "zone": "Asia/Tokyo", "offsetMin": 540 }
    ]

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function offsetLabel(minutes) {
        const sign = minutes < 0 ? "-" : "+";
        const absMin = Math.abs(minutes);
        return "UTC" + sign + pad(Math.floor(absMin / 60)) + ":" + pad(absMin % 60);
    }

    // Last Sunday of month (0-based) at 01:00 UTC, as epoch ms.
    function lastSundayUtcMs(year, month) {
        const last = new Date(Date.UTC(year, month + 1, 0, 1, 0, 0));
        return last.getTime() - last.getUTCDay() * 86400000;
    }

    // Madrid EU DST rule; other cities use their fixed offset.
    function effectiveOffsetMin(date, city) {
        if (city.zone !== "Europe/Madrid")
            return city.offsetMin;
        const y = date.getUTCFullYear();
        const start = lastSundayUtcMs(y, 2);
        const end = lastSundayUtcMs(y, 9);
        const t = date.getTime();
        return (t >= start && t < end) ? 120 : 60;
    }

    // Returns {text, fallback} applying the rule-based offset.
    function zonedTime(date, zone, offsetMin) {
        const city = { "zone": zone, "offsetMin": offsetMin };
        const eff = effectiveOffsetMin(date, city);
        const shifted = new Date(date.getTime() + eff * 60000);
        return { "text": pad(shifted.getUTCHours()) + ":" + pad(shifted.getUTCMinutes()) + ":" + pad(shifted.getUTCSeconds()), "fallback": false, "offsetMin": eff };
    }

    function localTime(date) {
        return pad(date.getHours()) + ":" + pad(date.getMinutes()) + ":" + pad(date.getSeconds());
    }

    function utcTime(date) {
        return pad(date.getUTCHours()) + ":" + pad(date.getUTCMinutes()) + ":" + pad(date.getUTCSeconds());
    }

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Text {
            color: Theme.onSurface
            text: "World Clock"
            font.bold: true
            font.pixelSize: 14
        }

        Text {
            color: Theme.onSurface
            text: "Local  " + root.localTime(root.now)
        }

        Text {
            color: Theme.onSurfaceVariant
            text: "UTC  " + root.utcTime(root.now)
        }

        Repeater {
            model: root.cities

            delegate: Text {
                required property var modelData

                color: Theme.onSurfaceVariant
                text: {
                    const z = root.zonedTime(root.now, modelData.zone, modelData.offsetMin);
                    return modelData.name + "  " + z.text + "  (" + root.offsetLabel(z.offsetMin) + ")";
                }
            }
        }
    }
}
