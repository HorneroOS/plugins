import QtQuick
import Hornero.PluginKit

// Weather 2.0 bar surface (manifest v2): contextual compact
// indicator over the same PluginKit Weather facade as the
// dashboard card. Compact hosts show only the temperature;
// the popover carries the rows the typed settings enable.
Item {
    id: root

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

    readonly property bool showHumidity: pluginSettings.value("showHumidity", true) !== false
    readonly property bool showWind: pluginSettings.value("showWind", true) !== false
    readonly property bool showSunTimes: pluginSettings.value("showSunTimes", true) !== false

    UiButton {
        id: indicator

        variant: "ghost"
        text: !Weather.locationConfigured ? i18n.tr("Weather") : Weather.ready ? (root.hostCompact ? Weather.temp : i18n.tr("Weather %1").arg(Weather.temp)) : i18n.tr("Weather")
        tooltipText: i18n.tr("Weather: activate for details")
        accessibleName: i18n.tr("Weather details")
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Weather details")

        Column {
            width: 280
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Weather")
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
                    visible: root.showHumidity
                    label: i18n.tr("Humidity")
                    value: String(Weather.humidity)
                    unit: "%"
                }

                UiMetric {
                    visible: root.showWind
                    label: i18n.tr("Wind")
                    value: i18n.formatNumber(Number(Weather.windSpeed))
                    unit: "km/h"
                }

                UiText {
                    visible: root.showSunTimes
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Sunrise: %1  Sunset: %2").arg(Weather.sunrise).arg(Weather.sunset)
                }
            }
        }
    }
}
