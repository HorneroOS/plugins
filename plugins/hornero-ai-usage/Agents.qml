import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Agent Deck flagship page (PluginKit 5 dashboardTab, plugins#22):
// every discovered coding-agent subscription as a Signal instrument
// module — provider-reported quota windows with resets, plan and
// billing, plus local (or account-scope) token activity. Nothing
// estimated: a provider that exposes no limit reads "unknown", and
// figures from different scopes or periods are never summed.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property bool hostCompact: false
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property string hostSurface: "dashboardTab"

    property double nowMs: Date.now()

    // Vertical room for the whole page. PluginKit 5 hosts report it
    // (hostAvailableHeight); older hosts report 0, so fall back to
    // this screen minus the same reserve the shell itself uses.
    // The cards scroll inside what is left under the fixed header
    // instead of overflowing off the bottom of the dashboard.
    readonly property int viewportCap: hostAvailableHeight > 0 ? hostAvailableHeight : Screen.height > 0 ? Math.max(320, Screen.height - 220) : 760
    readonly property int scrollHeight: Math.max(180, Math.min(cardsWrap.implicitHeight, root.viewportCap - headerCol.implicitHeight - Theme.spacing.normal))

    implicitWidth: hostAvailableWidth > 0 ? Math.min(1180, hostAvailableWidth) : 968
    implicitHeight: col.implicitHeight

    // Reset countdowns tick locally; providers are never polled for it.
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.nowMs = Date.now()
    }

    Translations {
        id: i18n

        pluginId: "hornero-ai-usage"
    }

    UsageData {
        id: usage
    }

    Column {
        id: col

        width: parent.width
        spacing: Theme.spacing.normal

        Column {
            id: headerCol

            width: parent.width
            spacing: Theme.spacing.normal

        UiStack {
            width: parent.width
            orientation: root.hostOrientation
            compact: root.hostCompact

            UiEyebrow {
                channel: 8
                text: i18n.tr("AGENT DECK")
                context: usage.lastUpdatedMs > 0 ? i18n.tr("UPDATED %1").arg(i18n.formatDateTime(new Date(usage.lastUpdatedMs), "HH:mm")) : ""
            }

            UiButton {
                glyph: "refresh"
                text: i18n.tr("Refresh")
                tooltipText: i18n.tr("Reload AI usage from horneroctl")
                accessibleName: i18n.tr("Refresh AI usage")
                onClicked: usage.refresh(true)
            }
        }

        UiStack {
            visible: usage.anyOk
            width: parent.width
            orientation: root.hostOrientation
            compact: root.hostCompact

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Subscriptions")
                value: i18n.formatNumber(usage.subCount)
            }

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Tightest quota")
                available: usage.worstPercent >= 0
                value: usage.worstPercent >= 0 ? i18n.formatNumber(Math.round(usage.worstPercent)) : ""
                unit: "%"
                tone: usage.worstPercent >= usage.warningPercent ? "alert" : "default"
            }

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Next reset")
                available: usage.nextResetUnix > 0
                value: usage.nextResetUnix > 0 ? usage.resetInText(usage.nextResetUnix, root.nowMs) : ""
            }

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Agents reporting")
                value: i18n.tr("%1 / %2").arg(i18n.formatNumber(usage.okCount)).arg(i18n.formatNumber(usage.records.length))
            }
        }

        UiText {
            visible: usage.worstPercent >= 0
            width: parent.width
            role: "caption"
            text: i18n.tr("Tightest right now: %1").arg(usage.worstLabel)
        }

        UiStack {
            visible: usage.anyOk
            width: parent.width
            orientation: root.hostOrientation
            compact: root.hostCompact

            UiText {
                role: "caption"
                text: i18n.tr("ACTIVITY WINDOW")
            }

            // Adaptable selector: segmented buttons when the page is
            // wide, a dropdown when it is not. One persisted setting.
            Row {
                visible: root.width >= 760
                spacing: Theme.spacing.small

                Repeater {
                    model: ["7", "30", "60", "90", "all"]

                    UiButton {
                        required property var modelData

                        variant: usage.statsWindow === modelData ? "primary" : "secondary"
                        text: modelData === "all" ? i18n.tr("All") : modelData + "d"
                        accessibleName: i18n.tr("Activity window")
                        onClicked: usage.setStatsWindow(modelData)
                    }
                }
            }

            UiComboBox {
                visible: root.width < 760
                model: ["7d", "30d", "60d", "90d", i18n.tr("All")]
                currentIndex: ["7", "30", "60", "90", "all"].indexOf(usage.statsWindow)
                accessibleName: i18n.tr("Activity window")
                tooltipText: i18n.tr("Activity window")
                onActivated: index => usage.setStatsWindow(["7", "30", "60", "90", "all"][index])
            }
        }

        UiText {
            visible: usage.anyOk && usage.statsWindow === "all"
            width: parent.width
            role: "caption"
            text: i18n.tr("All available daily history (up to 90 days).")
        }

        Column {
            visible: usage.anyOk && usage.holisticSeries(usage.statsWindowDays).values.length >= 2
            width: parent.width
            spacing: Theme.spacing.small

            UiText {
                role: "caption"
                text: i18n.tr("All agents · daily tokens").toUpperCase()
            }

            UiSparkline {
                width: parent.width
                height: 40
                values: usage.holisticSeries(usage.statsWindowDays).values
                window: Math.max(2, usage.holisticSeries(usage.statsWindowDays).values.length)
                tone: "cue"
                accessibleName: i18n.tr("All agents · daily tokens")
            }

            UiText {
                width: parent.width
                role: "caption"
                text: {
                    const h = usage.holisticSeries(usage.statsWindowDays);
                    return i18n.tr("%1 tokens · peak %2 on %3 · %4 active days").arg(i18n.formatNumber(h.total)).arg(i18n.formatNumber(h.peak)).arg(h.peakDate).arg(i18n.formatNumber(h.activeDays));
                }
            }
        }

        UiText {
            visible: usage.stale
            width: parent.width
            role: "caption"
            text: i18n.tr("Showing last known data; the latest check failed.")
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

        }

        UiScrollArea {
            id: scroll

            width: parent.width
            height: root.scrollHeight
            accessibleName: i18n.tr("Agent subscriptions")

            Column {
                id: cardsWrap

                width: scroll.width - 8
                spacing: Theme.spacing.normal

                GridLayout {
                    width: parent.width
                    columns: root.width >= 1080 ? 2 : 1
                    columnSpacing: Theme.spacing.normal
                    rowSpacing: Theme.spacing.normal

                    Repeater {
                        model: usage.sortedRecords

                        UiCard {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                title: usage.recordName(modelData)
                channel: index + 1
                glyph: "robot"
                context: typeof modelData.plan === "string" ? modelData.plan.toUpperCase() : ""
                Accessible.name: usage.recordName(modelData)

                Column {
                    width: parent.width
                    spacing: Theme.spacing.small

                    UiStack {
                        orientation: root.hostOrientation
                        compact: root.hostCompact

                        UiChip {
                            text: usage.statusText(String(modelData.status || ""))
                            tone: modelData.status === "ok" ? "phosphor" : "neutral"
                        }

                        UiChip {
                            visible: typeof modelData.plan === "string" && modelData.plan.length > 0
                            text: String(modelData.plan || "")
                            tone: "signal"
                        }

                        UiChip {
                            visible: modelData.billing === "subscription"
                            text: i18n.tr("Subscription")
                        }

                        UiChip {
                            visible: modelData.scope === "account"
                            text: i18n.tr("Account-wide")
                            tone: "cue"
                        }

                        UiChip {
                            visible: modelData.status === "ok"
                            text: usage.freshnessText(String(modelData.freshness || ""))
                        }

                        UiChip {
                            visible: modelData.authStatus === "authorization-needed"
                            text: i18n.tr("Sign-in needed")
                            tone: "alert"
                        }
                    }

                    Repeater {
                        model: usage.windowsOf(modelData)

                        Column {
                            required property var modelData

                            width: parent.width
                            spacing: Theme.spacing.small

                            UiMeterRow {
                                width: parent.width
                                label: String(modelData.label || "").toUpperCase()
                                labelWidth: 150
                                valueWidth: 56
                                value: Math.max(0, Math.min(1, Number(modelData.usedPercent || 0) / 100))
                                valueText: i18n.formatNumber(Math.round(Number(modelData.usedPercent || 0))) + " %"
                                threshold: usage.warningPercent / 100
                            }

                            UiText {
                                visible: Number(modelData.resetsAtUnix || 0) > 0
                                role: "caption"
                                text: i18n.tr("Resets %1 · %2 · %3% remaining").arg(usage.resetInText(Number(modelData.resetsAtUnix || 0), root.nowMs)).arg(i18n.formatDateTime(new Date(Number(modelData.resetsAtUnix || 0) * 1000), "MMM d HH:mm")).arg(i18n.formatNumber(Math.max(0, 100 - Math.round(Number(modelData.usedPercent || 0)))))
                            }
                        }
                    }

                    UiText {
                        visible: modelData.status === "ok" && usage.windowsOf(modelData).length === 0
                        width: parent.width
                        role: "caption"
                        text: i18n.tr("Quota: unknown - the provider does not expose a limit.")
                    }

                    Column {
                        visible: modelData.status === "ok" && usage.dailyValues(modelData, usage.statsWindowDays).length >= 2
                        width: parent.width
                        spacing: Theme.spacing.small

                        UiText {
                            role: "caption"
                            text: i18n.tr("Daily tokens").toUpperCase()
                        }

                        UiSparkline {
                            width: parent.width
                            height: 34
                            values: usage.dailyValues(modelData, usage.statsWindowDays)
                            window: Math.max(2, usage.dailyValues(modelData, usage.statsWindowDays).length)
                            tone: "cue"
                            accessibleName: i18n.tr("Daily tokens")
                        }

                        UiText {
                            role: "caption"
                            text: i18n.tr("Tokens in window: %1").arg(i18n.formatNumber(usage.windowTokens(modelData, usage.statsWindowDays)))
                        }
                    }

                    UiPartition {
                        visible: modelData.status === "ok" && modelData.totalTokens !== undefined && Number(modelData.cacheReadTokens || 0) + Number(modelData.cacheWriteTokens || 0) > 0
                        width: parent.width
                        total: Number(modelData.inputTokens || 0) + Number(modelData.outputTokens || 0) + Number(modelData.cacheReadTokens || 0) + Number(modelData.cacheWriteTokens || 0)
                        used: Number(modelData.inputTokens || 0)
                        secondary: Number(modelData.outputTokens || 0)
                        usedLabel: i18n.tr("Tokens in")
                        secondaryLabel: i18n.tr("Tokens out")
                    }

                    UiStack {
                        visible: modelData.status === "ok" && modelData.totalTokens !== undefined
                        width: parent.width
                        orientation: root.hostOrientation
                        compact: root.hostCompact

                        UiMetric {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            size: "value"
                            label: modelData.scope === "account" ? i18n.tr("Account tokens") : i18n.tr("Total tokens (this machine)")
                            value: i18n.formatNumber(Number(modelData.totalTokens || 0))
                        }

                        UiMetric {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            size: "value"
                            label: i18n.tr("Tokens in")
                            value: i18n.formatNumber(Number(modelData.inputTokens || 0))
                        }

                        UiMetric {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            size: "value"
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
                        visible: modelData.status === "ok" && typeof modelData.models === "string" && modelData.models.length > 0
                        width: parent.width
                        role: "caption"
                        text: i18n.tr("Models: %1").arg(String(modelData.models || ""))
                    }

                    UiText {
                        visible: typeof modelData.note === "string" && modelData.note.length > 0
                        width: parent.width
                        role: "caption"
                        text: String(modelData.note || "")
                    }

                    UiText {
                        visible: modelData.status !== "ok"
                        width: parent.width
                        role: "caption"
                        text: i18n.tr("Unavailable: %1").arg(usage.errorsText(modelData).length > 0 ? usage.errorsText(modelData) : usage.statusText(String(modelData.status || "")))
                    }
                }
            }
        }

                }

                UiText {
                    visible: usage.hasData
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Quota appears only when the provider itself reports it. Unknown never means 0% used, and account-wide figures are never added to this machine's activity.")
                }
            }
        }
    }
}
