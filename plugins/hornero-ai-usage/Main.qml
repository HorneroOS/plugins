import QtQuick
import Hornero.PluginKit

// AI Usage 2.0 dashboard surface (primary): one block per provider
// from the normalized horneroctl agent usage records. Providers
// degrade independently — an unavailable or failed collector is
// labelled as such beside the healthy ones. Quota is shown only
// when the provider's own record carries an official snapshot.
Item {
    id: root

    // Host context (opt-in): defaults keep the roomy 1.x dashboard
    // layout when no host values are injected.
    property string hostOrientation: "horizontal"
    property bool hostCompact: false
    property int hostAvailableWidth: 0

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-ai-usage"
    }

    UsageData {
        id: usage
    }

    function statusText(status: string): string {
        if (status === "ok")
            return i18n.tr("Available");
        if (status === "error")
            return i18n.tr("Error");
        return i18n.tr("Unavailable");
    }

    function freshnessText(freshness: string): string {
        if (freshness === "fresh")
            return i18n.tr("Fresh");
        if (freshness === "stale")
            return i18n.tr("Stale");
        return i18n.tr("Freshness unknown");
    }

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("AI Usage")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("AI Usage")
            }

            UiState {
                visible: usage.loading && !usage.hasData
                width: parent.width
                kind: "loading"
                message: i18n.tr("Loading AI usage...")
            }

            UiState {
                visible: usage.failed
                width: parent.width
                kind: "error"
                message: i18n.tr("AI usage unavailable: horneroctl returned no usable data.")
            }

            Repeater {
                model: usage.records

                Column {
                    required property var modelData

                    width: parent.width
                    spacing: Theme.spacingSmall

                    UiStack {
                        orientation: root.hostOrientation
                        compact: root.hostCompact

                        UiText {
                            role: "body"
                            text: modelData.provider
                        }

                        UiChip {
                            text: root.statusText(String(modelData.status || ""))
                            tone: modelData.status === "ok" ? "primary" : modelData.status === "error" ? "error" : "neutral"
                        }

                        UiChip {
                            visible: modelData.status === "ok"
                            text: root.freshnessText(String(modelData.freshness || ""))
                        }
                    }

                    UiStack {
                        visible: modelData.status === "ok"
                        orientation: root.hostOrientation
                        compact: root.hostCompact

                        UiMetric {
                            label: i18n.tr("Total tokens")
                            value: i18n.formatNumber(Number(modelData.totalTokens || 0))
                        }

                        UiMetric {
                            visible: !root.hostCompact
                            label: i18n.tr("Input tokens")
                            value: i18n.formatNumber(Number(modelData.inputTokens || 0))
                        }

                        UiMetric {
                            visible: !root.hostCompact
                            label: i18n.tr("Output tokens")
                            value: i18n.formatNumber(Number(modelData.outputTokens || 0))
                        }
                    }

                    UiText {
                        visible: modelData.status === "ok" && modelData.sessions !== undefined
                        role: "caption"
                        text: i18n.tr("Sessions: %1").arg(i18n.formatNumber(Number(modelData.sessions || 0)))
                    }

                    UiText {
                        visible: modelData.status === "ok" && modelData.apiCalls !== undefined
                        role: "caption"
                        text: i18n.tr("API calls: %1").arg(i18n.formatNumber(Number(modelData.apiCalls || 0)))
                    }

                    UiText {
                        visible: modelData.status === "ok" && typeof modelData.models === "string" && modelData.models.length > 0
                        width: parent.width
                        role: "caption"
                        text: i18n.tr("Models: %1").arg(String(modelData.models || ""))
                    }

                    UiText {
                        visible: modelData.status === "ok" && typeof modelData.periodStart === "string" && modelData.periodStart.length > 0
                        width: parent.width
                        role: "caption"
                        text: i18n.tr("Period: %1 to %2").arg(String(modelData.periodStart || "")).arg(String(modelData.periodEnd || ""))
                    }

                    Column {
                        visible: modelData.status === "ok" && modelData.quota === "available"
                        width: parent.width
                        spacing: Theme.spacingSmall

                        UiText {
                            role: "caption"
                            text: i18n.tr("Quota used: %1%").arg(i18n.formatNumber(Math.round(Number(modelData.quotaUsedPercent || 0))))
                        }

                        UiProgress {
                            width: parent.width
                            value: Math.max(0, Math.min(1, Number(modelData.quotaUsedPercent || 0) / 100))
                        }

                        UiText {
                            visible: Number(modelData.quotaResetsAtUnix || 0) > 0
                            role: "caption"
                            text: i18n.tr("Quota resets: %1").arg(i18n.formatDateTime(new Date(Number(modelData.quotaResetsAtUnix || 0) * 1000), "yyyy-MM-dd HH:mm"))
                        }
                    }

                    UiText {
                        visible: modelData.status === "ok" && modelData.quota !== "available"
                        width: parent.width
                        role: "caption"
                        text: i18n.tr("Quota: unknown - the provider does not expose a limit.")
                    }

                    UiText {
                        visible: modelData.status === "ok" && typeof modelData.balance === "string" && modelData.balance !== "unknown" && modelData.balance.length > 0
                        role: "caption"
                        text: i18n.tr("Balance: %1").arg(String(modelData.balance || ""))
                    }

                    UiText {
                        visible: modelData.status !== "ok"
                        width: parent.width
                        role: "caption"
                        text: i18n.tr("Unavailable: %1").arg(Array.isArray(modelData.errors) && modelData.errors.length > 0 ? modelData.errors.join("; ") : root.statusText(String(modelData.status || "")))
                    }
                }
            }

            UiButton {
                text: i18n.tr("Refresh")
                variant: "ghost"
                tooltipText: i18n.tr("Reload AI usage from horneroctl")
                accessibleName: i18n.tr("Refresh AI usage")
                onClicked: usage.refresh()
            }
        }
    }
}
