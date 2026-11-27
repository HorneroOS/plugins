import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Agent Deck bar surface: a compact, self-hiding Signal indicator.
// It shows the tightest *verified* quota (never a cross-provider
// average or a summed token total) and opens a quick popover with
// every discovered account, its critical windows and resets.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property bool hostCompact: false

    property string selectedProvider: ""
    property double nowMs: Date.now()

    implicitWidth: usage.anyOk ? indicator.implicitWidth : 0
    implicitHeight: usage.anyOk ? indicator.implicitHeight : 0

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.nowMs = Date.now()
    }

    Translations {
        id: i18n

        pluginId: "hornero-ai-usage"
    }

    UsageData {
        id: usage
    }

    readonly property var current: {
        for (const record of usage.records)
            if (record && record.provider === root.selectedProvider)
                return record;
        return usage.sortedRecords.length > 0 ? usage.sortedRecords[0] : null;
    }

    readonly property bool warn: usage.worstPercent >= usage.warningPercent

    UiButton {
        id: indicator

        visible: usage.anyOk
        variant: "quiet"
        glyph: "robot"
        text: root.hostCompact ? "" : usage.worstPercent >= 0 ? "%1 %".arg(i18n.formatNumber(Math.round(usage.worstPercent))) : i18n.formatNumber(usage.subCount > 0 ? usage.subCount : usage.okCount)
        tooltipText: usage.worstPercent >= 0 ? i18n.tr("Agent quotas: tightest is %1 at %2%. Activate for details.").arg(usage.worstLabel).arg(i18n.formatNumber(Math.round(usage.worstPercent))) : i18n.tr("Agent usage: activate for provider details")
        accessibleName: usage.worstPercent >= 0 ? i18n.tr("Agent quotas, tightest %1 percent used").arg(i18n.formatNumber(Math.round(usage.worstPercent))) : i18n.tr("Agent usage details")
        onClicked: popover.toggle()
    }

    Process {
        id: navProc

        command: ["qs", "ipc", "call", "drawers", "dashboardTab", "hornero-ai-usage:agents"]
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Agent quotas")

        Column {
            width: 340
            spacing: Theme.spacing.small

            UiText {
                role: "title"
                text: i18n.tr("Agent Deck")
            }

            UiText {
                visible: usage.anyOk
                width: parent.width
                role: "caption"
                text: usage.worstPercent >= 0 ? i18n.tr("%1 subscriptions · tightest: %2 at %3%").arg(i18n.formatNumber(usage.subCount > 0 ? usage.subCount : usage.okCount)).arg(usage.worstLabel).arg(i18n.formatNumber(Math.round(usage.worstPercent))) : i18n.tr("%1 agents reporting activity").arg(i18n.formatNumber(usage.okCount))
            }

            UiText {
                visible: usage.stale
                width: parent.width
                role: "caption"
                text: i18n.tr("Showing last known data; the latest check failed.")
            }

            UiState {
                visible: usage.failed
                width: parent.width
                kind: "error"
                message: i18n.tr("AI usage unavailable: horneroctl returned no usable data.")
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                Repeater {
                    model: usage.sortedRecords

                    UiButton {
                        required property var modelData

                        variant: "quiet"
                        text: usage.recordName(modelData)
                        tooltipText: i18n.tr("Show %1 usage").arg(usage.recordName(modelData))
                        accessibleName: i18n.tr("Show %1 usage").arg(usage.recordName(modelData))
                        onClicked: root.selectedProvider = String(modelData.provider || "")
                    }
                }
            }

            Column {
                visible: root.current !== null
                width: parent.width
                spacing: Theme.spacing.small

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiText {
                        role: "body"
                        text: root.current ? usage.recordName(root.current) : ""
                    }

                    UiChip {
                        visible: root.current !== null && typeof root.current.plan === "string" && root.current.plan.length > 0
                        text: root.current ? String(root.current.plan) : ""
                        tone: "signal"
                    }

                    UiChip {
                        text: root.current ? usage.statusText(String(root.current.status || "")) : ""
                        tone: root.current && root.current.status === "ok" ? "phosphor" : "neutral"
                    }
                }

                Repeater {
                    model: root.current ? usage.windowsOf(root.current) : []

                    Column {
                        required property var modelData

                        width: parent.width
                        spacing: Theme.spacing.small

                        UiMeterRow {
                            width: parent.width
                            label: String(modelData.label || "")
                            labelWidth: 110
                            valueWidth: 52
                            value: Math.max(0, Math.min(1, Number(modelData.usedPercent || 0) / 100))
                            valueText: i18n.formatNumber(Math.round(Number(modelData.usedPercent || 0))) + " %"
                            threshold: usage.warningPercent / 100
                        }

                        UiText {
                            visible: Number(modelData.resetsAtUnix || 0) > 0
                            role: "caption"
                            text: i18n.tr("Resets %1 · %2").arg(usage.resetInText(Number(modelData.resetsAtUnix || 0), root.nowMs)).arg(i18n.formatDateTime(new Date(Number(modelData.resetsAtUnix || 0) * 1000), "MMM d HH:mm"))
                        }
                    }
                }

                UiText {
                    visible: root.current !== null && root.current.status === "ok" && usage.windowsOf(root.current).length === 0
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Quota: unknown - the provider does not expose a limit.")
                }

                UiMetric {
                    size: "value"
                    visible: root.current !== null && root.current.status === "ok" && root.current.totalTokens !== undefined
                    label: root.current && root.current.scope === "account" ? i18n.tr("Account tokens") : i18n.tr("Total tokens")
                    value: root.current ? i18n.formatNumber(Number(root.current.totalTokens || 0)) : ""
                }

                UiText {
                    visible: root.current !== null && typeof root.current.note === "string" && root.current.note.length > 0
                    width: parent.width
                    role: "caption"
                    text: root.current ? String(root.current.note) : ""
                }

                UiText {
                    visible: root.current !== null && root.current.status !== "ok"
                    width: parent.width
                    role: "caption"
                    text: root.current ? i18n.tr("Unavailable: %1").arg(usage.errorsText(root.current).length > 0 ? usage.errorsText(root.current) : usage.statusText(String(root.current.status || ""))) : ""
                }
            }

            UiActionRow {
                width: parent.width
                glyph: "layout-grid"
                text: i18n.tr("Open Agents")
                tooltipText: i18n.tr("Open the full Agents dashboard")
                accessibleName: i18n.tr("Open Agents dashboard")
                onClicked: {
                    popover.close();
                    navProc.running = true;
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
