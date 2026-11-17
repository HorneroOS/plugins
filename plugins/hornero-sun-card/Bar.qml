import QtQuick
import Hornero.PluginKit

// Sun Card 2.0 bar surface (manifest v2): contextual compact
// indicator over PluginKit Weather sunrise/sunset. Compact hosts
// show only the label; the popover carries both times.
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

        pluginId: "hornero-sun-card"
    }

    UiButton {
        id: indicator

        variant: "quiet"
        glyph: "sunset"
        // Times only when there is data and room; the glyph carries the rest.
        text: Weather.ready && !root.hostCompact ? i18n.tr("%1 / %2").arg(Weather.sunrise).arg(Weather.sunset) : ""
        tooltipText: i18n.tr("Sun Card: activate for sunrise and sunset")
        accessibleName: i18n.tr("Sun Card details")
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Sun Card details")

        Column {
            width: 260
            spacing: Theme.spacing.small

            UiText {
                role: "title"
                text: i18n.tr("Sun Card")
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
                spacing: Theme.spacing.small

                UiMetric {
                    size: "value"
                    label: i18n.tr("Sunrise")
                    value: Weather.sunrise
                }

                UiMetric {
                    size: "value"
                    label: i18n.tr("Sunset")
                    value: Weather.sunset
                }
            }
        }
    }
}
