import QtQuick
import Hornero.PluginKit

// Weather 2.0: dashboard card complementing the native Weather
// view, over the read-only PluginKit Weather facade only.
// The facade exposes temp (shell-formatted string), description,
// humidity, windSpeed (km/h as the native view labels it), sunrise,
// sunset (formatted strings), lastError and forecast entries with
// date/minTempC/maxTempC/minTempF/maxTempF/weatherCode/icon.
// It exposes no city/location name, no unit preference, no
// feels-like, no hourly forecast, no official alerts and no
// multi-location data: those are labelled unavailable, never
// fabricated. The high-wind chip is a local threshold on the
// reported windSpeed, not an official alert.
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

    Translations {
        id: i18n

        pluginId: "hornero-weather"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-weather"
    }

    readonly property int forecastDays: {
        const value = Number(pluginSettings.value("forecastDays", 3));
        return isFinite(value) && value >= 0 ? Math.min(7, Math.floor(value)) : 3;
    }
    readonly property bool showHumidity: pluginSettings.value("showHumidity", true) !== false
    readonly property bool showWind: pluginSettings.value("showWind", true) !== false
    readonly property bool showSunTimes: pluginSettings.value("showSunTimes", true) !== false
    readonly property string dataDensity: {
        const value = String(pluginSettings.value("dataDensity", "standard"));
        return (value === "compact" || value === "detailed") ? value : "standard";
    }
    readonly property int windAlertKmh: {
        const value = Number(pluginSettings.value("windAlertKmh", 50));
        return isFinite(value) && value >= 1 ? Math.min(200, Math.floor(value)) : 50;
    }
    readonly property bool compactDensity: dataDensity === "compact" || hostCompact
    readonly property bool detailedDensity: dataDensity === "detailed"
    readonly property bool windHigh: Weather.ready && isFinite(Number(Weather.windSpeed)) && Number(Weather.windSpeed) >= windAlertKmh

    function forecastLine(entry) {
        if (!entry)
            return "";
        const parts = [];
        if (entry.date)
            parts.push(String(entry.date));
        if (entry.minTempC !== undefined && entry.maxTempC !== undefined)
            parts.push(String(entry.minTempC) + "°C / " + String(entry.maxTempC) + "°C");
        return parts.join("  ");
    }

    function forecastRange() {
        const entries = Weather.forecast || [];
        const count = Math.min(root.forecastDays, entries.length);
        let low = null;
        let high = null;
        for (let i = 0; i < count; i++) {
            const entry = entries[i];
            if (!entry)
                continue;
            if (entry.minTempC !== undefined && isFinite(Number(entry.minTempC)))
                low = low === null ? Number(entry.minTempC) : Math.min(low, Number(entry.minTempC));
            if (entry.maxTempC !== undefined && isFinite(Number(entry.maxTempC)))
                high = high === null ? Number(entry.maxTempC) : Math.max(high, Number(entry.maxTempC));
        }
        if (low === null || high === null)
            return i18n.tr("Unavailable");
        return String(low) + "°C / " + String(high) + "°C";
    }

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("Weather")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiText {
                    role: "title"
                    text: i18n.tr("Weather")
                }

                UiChip {
                    visible: root.windHigh
                    text: i18n.tr("High wind")
                    tone: "error"
                }
            }

            UiState {
                visible: !Weather.locationConfigured
                width: parent.width
                kind: "empty"
                message: i18n.tr("Weather location not configured. Set a location in the shell settings to see conditions here.")
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
                    label: i18n.tr("Temperature")
                    value: Weather.temp
                }

                UiText {
                    visible: Weather.description.length > 0
                    role: "body"
                    text: Weather.description
                }

                UiMetric {
                    visible: !root.compactDensity && root.showHumidity
                    label: i18n.tr("Humidity")
                    value: String(Weather.humidity)
                    unit: "%"
                }

                UiMetric {
                    visible: !root.compactDensity && root.showWind
                    label: i18n.tr("Wind")
                    value: i18n.formatNumber(Number(Weather.windSpeed))
                    unit: "km/h"
                }

                UiText {
                    visible: !root.compactDensity && root.showSunTimes
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Sunrise: %1  Sunset: %2").arg(Weather.sunrise).arg(Weather.sunset)
                }

                UiText {
                    visible: root.windHigh
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Local alert: wind at or above your %1 km/h threshold. Not an official weather alert.").arg(String(root.windAlertKmh))
                }

                Repeater {
                    model: !root.compactDensity && Weather.forecast ? Math.min(root.forecastDays, Weather.forecast.length) : 0

                    delegate: UiText {
                        required property int index

                        role: "caption"
                        text: root.forecastLine(Weather.forecast[index])
                    }
                }

                UiMetric {
                    visible: root.detailedDensity && !root.compactDensity
                    label: i18n.tr("Forecast range (derived)")
                    value: root.forecastRange()
                }

                UiText {
                    visible: root.detailedDensity
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Unavailable from the Weather facade: official alerts, multiple locations, feels-like, UV and precipitation. The single configured location only is shown; its name is not exposed to extensions.")
                }
            }
        }
    }
}
