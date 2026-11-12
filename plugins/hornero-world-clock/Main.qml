import QtQuick
import Hornero.PluginKit

// Hornero World Clock - dashboard card over PluginKit Time.
// Shows local time, UTC and three fixed cities. City times are
// computed by round-tripping a JS Date through
// toLocaleString('en-US', {timeZone}) so daylight-saving rules of
// the named zone apply when the JS engine supports timeZone. When
// that conversion is unavailable or yields an invalid date, a
// fixed UTC offset is used instead and the row is labelled with
// that offset (e.g. "UTC-03:00"); no DST behaviour is claimed for
// the fallback path.
Item {
    id: root

    property var now: Time.date

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    // city, IANA zone, fallback fixed offset in minutes
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

    // Returns {text, fallback} for a zone at instant `date`.
    function zonedTime(date, zone, offsetMin) {
        try {
            const rendered = date.toLocaleString("en-US", { "timeZone": zone });
            const zoned = new Date(rendered);
            if (!isNaN(zoned.getTime()))
                return { "text": pad(zoned.getHours()) + ":" + pad(zoned.getMinutes()) + ":" + pad(zoned.getSeconds()), "fallback": false };
        } catch (e) {
            // fall through to fixed offset
        }
        const shifted = new Date(date.getTime() + offsetMin * 60000);
        return { "text": pad(shifted.getUTCHours()) + ":" + pad(shifted.getUTCMinutes()) + ":" + pad(shifted.getUTCSeconds()), "fallback": true };
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
                    return modelData.name + "  " + z.text + (z.fallback ? "  (" + root.offsetLabel(modelData.offsetMin) + ")" : "");
                }
            }
        }
    }
}
