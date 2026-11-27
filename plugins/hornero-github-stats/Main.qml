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
        id: pulse

        active: root.visible
    }

    UiCard {
        id: card

        width: parent.width
        title: i18n.tr("Dev Pulse")

        Column {
            width: parent.width
            spacing: Theme.spacing.small

            UiMetric {
                visible: pulse.calendar !== null
                size: "value"
                label: i18n.tr("Contributions (window)")
                value: pulse.calendar ? i18n.formatNumber(Number(pulse.calendar.totalContributions || 0)) : ""
            }

            UiMetric {
                visible: pulse.totals !== null && pulse.totals.prsMerged !== undefined
                size: "value"
                label: i18n.tr("PRs merged (window)")
                value: pulse.totals ? i18n.formatNumber(Number(pulse.totals.prsMerged || 0)) : ""
            }

            UiMetric {
                size: "value"
                label: i18n.tr("Failing checks")
                value: i18n.formatNumber(pulse.failingItems.length)
            }

            UiText {
                visible: pulse.failed
                width: parent.width
                role: "caption"
                text: i18n.tr("GitHub unavailable.")
            }

            UiActionRow {
                width: parent.width
                glyph: "refresh"
                text: i18n.tr("Refresh")
                accessibleName: i18n.tr("Refresh GitHub activity")
                onClicked: pulse.refresh(true)
            }
        }
    }
}
