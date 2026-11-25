import QtQuick
import Hornero.PluginKit

// Dev Pulse dashboard card: the compact overview that accompanies
// the full Dev Pulse tab. Same data, same honesty rules.
Item {
    id: root

    implicitWidth: 360
    implicitHeight: card.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-github-stats"
    }

    GithubData {
        id: data
    }

    UiCard {
        id: card

        width: parent.width
        title: i18n.tr("Dev Pulse")

        Column {
            width: parent.width
            spacing: Theme.spacing.small

            UiMetric {
                visible: data.calendar !== null
                size: "value"
                label: i18n.tr("Contributions (window)")
                value: data.calendar ? i18n.formatNumber(Number(data.calendar.totalContributions || 0)) : ""
            }

            UiMetric {
                visible: data.totals !== null && data.totals.prsMerged !== undefined
                size: "value"
                label: i18n.tr("PRs merged (window)")
                value: data.totals ? i18n.formatNumber(Number(data.totals.prsMerged || 0)) : ""
            }

            UiMetric {
                size: "value"
                label: i18n.tr("Failing checks")
                value: i18n.formatNumber(data.failingItems.length)
            }

            UiText {
                visible: data.failed
                width: parent.width
                role: "caption"
                text: i18n.tr("GitHub unavailable via gh.")
            }

            UiActionRow {
                width: parent.width
                glyph: "refresh"
                text: i18n.tr("Refresh")
                accessibleName: i18n.tr("Refresh GitHub activity")
                onClicked: data.refresh(true)
            }
        }
    }
}
