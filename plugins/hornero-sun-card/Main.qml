import QtQuick
import Hornero.PluginKit

// Sun Card 2.0: astronomy dashboard card over PluginKit Weather
// (sunrise/sunset formatted strings, temp, description, humidity)
// plus PluginKit Time for the current time. Day length, sun
// progress and the next sun event are derived here from those
// strings and labelled derived; if a string is the "--:--"
// placeholder or otherwise unparseable the derived rows read
// Unavailable. The facade reports today's sunrise/sunset only,
// so after sunset the next event is unavailable, not guessed.
// It exposes no solar noon, twilight phases, moonrise/moonset,
// location name or multi-location data.
Item {
    id: root

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
        domain: "weather"
    }

    Subscription {
        domain: "time"
    }

    Translations {
        id: i18n

        pluginId: "hornero-sun-card"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-sun-card"
    }

    readonly property bool showTemperature: pluginSettings.value("showTemperature", true) !== false
    readonly property bool showHumidity: pluginSettings.value("showHumidity", true) !== false
    readonly property bool showAstronomy: pluginSettings.value("showAstronomy", true) !== false
    readonly property string dataDensity: {
        const value = String(pluginSettings.value("dataDensity", "standard"));
        return (value === "compact" || value === "detailed") ? value : "standard";
    }
    readonly property bool compactDensity: dataDensity === "compact" || hostCompact
    readonly property bool detailedDensity: dataDensity === "detailed"

    function parseMinutes(value) {
        const match = /^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$/i.exec(String(value || "").trim());
        if (!match)
            return -1;
        let hours = Number(match[1]);
        const minutes = Number(match[2]);
        const marker = match[3] ? match[3].toUpperCase() : "";
        if (minutes < 0 || minutes > 59)
            return -1;
        if (marker === "AM") {
            if (hours < 1 || hours > 12)
                return -1;
            if (hours === 12)
                hours = 0;
        } else if (marker === "PM") {
            if (hours < 1 || hours > 12)
                return -1;
            if (hours !== 12)
                hours += 12;
        } else if (hours < 0 || hours > 23) {
            return -1;
        }
        return hours * 60 + minutes;
    }

    readonly property int sunriseMinutes: parseMinutes(Weather.sunrise)
    readonly property int sunsetMinutes: parseMinutes(Weather.sunset)
    readonly property int nowMinutes: Time.hours * 60 + Time.minutes
    readonly property bool sunTimesValid: sunriseMinutes >= 0 && sunsetMinutes > sunriseMinutes
    readonly property int dayLengthMinutes: sunTimesValid ? sunsetMinutes - sunriseMinutes : -1
    readonly property real sunProgress: sunTimesValid ? Math.max(0, Math.min(1, (nowMinutes - sunriseMinutes) / (sunsetMinutes - sunriseMinutes))) : 0
    readonly property bool sunUp: sunTimesValid && nowMinutes >= sunriseMinutes && nowMinutes < sunsetMinutes

    function durationText(totalMinutes) {
        if (totalMinutes < 0)
            return i18n.tr("Unavailable");
        return i18n.tr("%1 h %2 min").arg(String(Math.floor(totalMinutes / 60))).arg(String(totalMinutes % 60));
    }

    function nextEventText() {
        if (!sunTimesValid)
            return i18n.tr("Unavailable");
        if (nowMinutes < sunriseMinutes)
            return i18n.tr("Sunrise in %1").arg(durationText(sunriseMinutes - nowMinutes));
        if (nowMinutes < sunsetMinutes)
            return i18n.tr("Sunset in %1").arg(durationText(sunsetMinutes - nowMinutes));
        return i18n.tr("Unavailable (the facade reports today only)");
    }

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("Sun Card")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiText {
                    role: "title"
                    text: i18n.tr("Sun Card")
                }

                UiChip {
                    visible: Weather.ready && root.sunTimesValid
                    text: root.sunUp ? i18n.tr("Daytime (derived)") : i18n.tr("Night (derived)")
                    tone: root.sunUp ? "primary" : "neutral"
                }
            }

            UiState {
                visible: !Weather.locationConfigured
                width: parent.width
                kind: "empty"
                message: i18n.tr("Weather location not configured. Set a location in the shell settings to see sunrise and sunset here.")
            }

            UiState {
                visible: Weather.locationConfigured && Weather.lastError.length > 0 && !Weather.ready
                width: parent.width
                kind: "error"
                message: i18n.tr("Weather unavailable: %1").arg(Weather.lastError)
            }

            UiState {
                visible: Weather.locationConfigured && Weather.lastError.length === 0 && !Weather.ready
                width: parent.width
                kind: "loading"
                message: i18n.tr("Loading weather...")
            }

            Column {
                visible: Weather.ready
                width: parent.width
                spacing: Theme.spacingSmall

                UiMetric {
                    visible: !root.compactDensity && root.showTemperature
                    label: i18n.tr("Temperature")
                    value: Weather.temp
                }

                UiText {
                    visible: !root.compactDensity && root.showTemperature && Weather.description.length > 0
                    role: "body"
                    text: Weather.description
                }

                UiMetric {
                    label: i18n.tr("Sunrise")
                    value: Weather.sunrise
                }

                UiMetric {
                    label: i18n.tr("Sunset")
                    value: Weather.sunset
                }

                UiMetric {
                    visible: !root.compactDensity && root.showHumidity
                    label: i18n.tr("Humidity")
                    value: String(Weather.humidity)
                    unit: "%"
                }

                Column {
                    visible: root.showAstronomy
                    width: parent.width
                    spacing: Theme.spacingSmall

                    UiMetric {
                        label: i18n.tr("Day length (derived)")
                        value: root.durationText(root.dayLengthMinutes)
                    }

                    UiMetric {
                        label: i18n.tr("Next sun event (derived)")
                        value: root.nextEventText()
                    }

                    UiText {
                        role: "caption"
                        text: i18n.tr("Sun progress (derived)")
                    }

                    UiProgress {
                        width: parent.width
                        value: root.sunProgress
                        accessibleName: i18n.tr("Sun progress (derived)")
                    }
                }

                UiText {
                    visible: root.detailedDensity
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Unavailable from the Weather facade: solar noon, twilight, moonrise/moonset, the location name and multiple locations. Derived rows come only from today's sunrise/sunset strings and the current time.")
                }
            }
        }
    }
}
