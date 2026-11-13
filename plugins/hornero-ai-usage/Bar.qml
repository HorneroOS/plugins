import QtQuick
import Hornero.PluginKit

// AI Usage 2.0 bar surface (manifest v2): a compact, self-hiding
// indicator — it takes no bar space until at least one provider
// reports usage — opening a host-owned popover with a provider
// switcher and the selected provider's detail. Same normalized
// records and honesty rules as the dashboard surface.
Item {
    id: root

    // Host context (opt-in): defaults match a roomy horizontal bar.
    property string hostOrientation: "horizontal"
    property bool hostCompact: false

    property string selectedProvider: ""

    implicitWidth: usage.anyOk ? indicator.implicitWidth : 0
    implicitHeight: usage.anyOk ? indicator.implicitHeight : 0

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
        for (const record of usage.records)
            if (record && record.status === "ok")
                return record;
        return usage.records.length > 0 ? usage.records[0] : null;
    }

    function statusText(status: string): string {
        if (status === "ok")
            return i18n.tr("Available");
        if (status === "error")
            return i18n.tr("Error");
        return i18n.tr("Unavailable");
    }

    UiButton {
        id: indicator

        visible: usage.anyOk
        variant: "ghost"
        text: root.hostCompact ? i18n.tr("AI") : i18n.tr("AI %1").arg(i18n.formatNumber(usage.totalTokensAll))
        tooltipText: i18n.tr("AI usage: activate for provider details")
        accessibleName: i18n.tr("AI usage details")
        onClicked: popover.toggle()
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("AI usage details")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("AI Usage")
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
                    model: usage.records

                    UiButton {
                        required property var modelData

                        variant: "ghost"
                        text: String(modelData.provider || "")
                        tooltipText: i18n.tr("Show %1 usage").arg(String(modelData.provider || ""))
                        accessibleName: i18n.tr("Show %1 usage").arg(String(modelData.provider || ""))
                        onClicked: root.selectedProvider = String(modelData.provider || "")
                    }
                }
            }

            Column {
                visible: root.current !== null
                width: parent.width
                spacing: Theme.spacingSmall

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiText {
                        role: "body"
                        text: root.current ? String(root.current.provider || "") : ""
                    }

                    UiChip {
                        text: root.current ? root.statusText(String(root.current.status || "")) : ""
                        tone: root.current && root.current.status === "ok" ? "primary" : root.current && root.current.status === "error" ? "error" : "neutral"
                    }
                }

                UiMetric {
                    visible: root.current !== null && root.current.status === "ok"
                    label: i18n.tr("Total tokens")
                    value: root.current ? i18n.formatNumber(Number(root.current.totalTokens || 0)) : ""
                }

                UiText {
                    visible: root.current !== null && root.current.status === "ok" && typeof root.current.models === "string" && root.current.models.length > 0
                    width: parent.width
                    role: "caption"
                    text: root.current ? i18n.tr("Models: %1").arg(String(root.current.models || "")) : ""
                }

                Column {
                    visible: root.current !== null && root.current.status === "ok" && root.current.quota === "available"
                    width: parent.width
                    spacing: Theme.spacingSmall

                    UiText {
                        role: "caption"
                        text: root.current ? i18n.tr("Quota used: %1%").arg(i18n.formatNumber(Math.round(Number(root.current.quotaUsedPercent || 0)))) : ""
                    }

                    UiProgress {
                        width: parent.width
                        value: root.current ? Math.max(0, Math.min(1, Number(root.current.quotaUsedPercent || 0) / 100)) : 0
                    }

                    UiText {
                        visible: root.current !== null && Number(root.current.quotaResetsAtUnix || 0) > 0
                        role: "caption"
                        text: root.current ? i18n.tr("Quota resets: %1").arg(i18n.formatDateTime(new Date(Number(root.current.quotaResetsAtUnix || 0) * 1000), "yyyy-MM-dd HH:mm")) : ""
                    }
                }

                UiText {
                    visible: root.current !== null && root.current.status === "ok" && root.current.quota !== "available"
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("Quota: unknown - the provider does not expose a limit.")
                }

                UiText {
                    visible: root.current !== null && root.current.status !== "ok"
                    width: parent.width
                    role: "caption"
                    text: root.current ? i18n.tr("Unavailable: %1").arg(Array.isArray(root.current.errors) && root.current.errors.length > 0 ? root.current.errors.join("; ") : root.statusText(String(root.current.status || ""))) : ""
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
