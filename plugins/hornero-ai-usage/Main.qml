import QtQuick
import QtQuick.Layouts
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

    // Status/freshness wording lives on UsageData (one code path).

    UiCard {
        id: card

        anchors.fill: parent
        title: i18n.tr("AI Usage")
        channel: 8
        Accessible.name: i18n.tr("AI Usage")

        Column {
            width: parent.width
            spacing: Theme.spacing.small

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
                    spacing: Theme.spacing.small

                    UiStack {
                        orientation: root.hostOrientation
                        compact: root.hostCompact

                        UiText {
                            role: "body"
                            text: usage.recordName(modelData)
                        }

                        UiChip {
                            visible: typeof modelData.plan === "string" && modelData.plan.length > 0
                            text: String(modelData.plan || "")
                            tone: "signal"
                        }

                        UiChip {
                            text: usage.statusText(String(modelData.status || ""))
                            tone: modelData.status === "ok" ? "phosphor" : "neutral"
                        }

                        UiChip {
                            visible: modelData.status === "ok"
                            text: usage.freshnessText(String(modelData.freshness || ""))
                        }
                    }

                    UiStack {
                        visible: modelData.status === "ok"
                        width: parent.width
                        orientation: root.hostOrientation
                        compact: root.hostCompact

                        UiMetric {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            size: "value"
                            label: i18n.tr("Total tokens")
                            value: i18n.formatNumber(Number(modelData.totalTokens || 0))
                        }

                        UiMetric {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            size: "value"
                            visible: !root.hostCompact
                            label: i18n.tr("Tokens in")
                            value: i18n.formatNumber(Number(modelData.inputTokens || 0))
                        }

                        UiMetric {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            size: "value"
                            visible: !root.hostCompact
                            label: i18n.tr("Tokens out")
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

                    Repeater {
                        model: modelData.status === "ok" ? usage.windowsOf(modelData) : []

                        Column {
                            required property var modelData

                            width: parent.width
                            spacing: Theme.spacing.small

                            // Shown only when the provider itself reports a limit.
                            UiMeterRow {
                                width: parent.width
                                label: String(modelData.label || "").toUpperCase()
                                labelWidth: 110
                                valueWidth: 56
                                value: Math.max(0, Math.min(1, Number(modelData.usedPercent || 0) / 100))
                                valueText: i18n.formatNumber(Math.round(Number(modelData.usedPercent || 0))) + " %"
                                threshold: usage.warningPercent / 100
                            }

                            UiText {
                                visible: Number(modelData.resetsAtUnix || 0) > 0
                                role: "caption"
                                text: i18n.tr("Quota resets: %1").arg(i18n.formatDateTime(new Date(Number(modelData.resetsAtUnix || 0) * 1000), "yyyy-MM-dd HH:mm"))
                            }
                        }
                    }

                    UiText {
                        visible: modelData.status === "ok" && usage.windowsOf(modelData).length === 0
                        width: parent.width
                        role: "caption"
                        text: i18n.tr("Quota: unknown - the provider does not expose a limit.")
                    }

                    UiText {
                        visible: typeof modelData.note === "string" && modelData.note.length > 0
                        width: parent.width
                        role: "caption"
                        text: String(modelData.note || "")
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
                        text: i18n.tr("Unavailable: %1").arg(Array.isArray(modelData.errors) && modelData.errors.length > 0 ? modelData.errors.join("; ") : usage.statusText(String(modelData.status || "")))
                    }
                }
            }

            UiActionRow {
                width: parent.width
                glyph: "refresh"
                text: i18n.tr("Refresh")
                tooltipText: i18n.tr("Reload AI usage from horneroctl")
                accessibleName: i18n.tr("Refresh AI usage")
                onClicked: usage.refresh(true)
            }
        }
    }
}
