import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Dev Pulse bar surface: a compact Signal indicator (open PRs,
// failing checks, review requests) with a quick popover. It hides
// itself when GitHub data is unavailable, and every number comes
// from horneroctl — nothing is estimated.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property bool hostCompact: false

    implicitWidth: pulse.hasData ? indicator.implicitWidth : 0
    implicitHeight: pulse.hasData ? indicator.implicitHeight : 0

    Translations {
        id: i18n

        pluginId: "hornero-github-stats"
    }

    GithubData {
        id: pulse
    }

    readonly property double openPrs: pulse.summaryTotal("mine")
    readonly property double reviewReq: pulse.summaryTotal("review")
    readonly property string indicatorLabel: {
        const parts = [];
        if (root.openPrs >= 0)
            parts.push(i18n.formatNumber(root.openPrs));
        if (pulse.failingItems.length > 0)
            parts.push("✗" + i18n.formatNumber(pulse.failingItems.length));
        if (root.reviewReq > 0)
            parts.push("◐" + i18n.formatNumber(root.reviewReq));
        return parts.join(" · ");
    }

    UiButton {
        id: indicator

        visible: pulse.hasData
        variant: "quiet"
        glyph: "activity"
        text: root.hostCompact ? "" : root.indicatorLabel
        tooltipText: i18n.tr("Dev Pulse: %1 open PRs, %2 failing, %3 review requests. Activate for details.").arg(i18n.formatNumber(Math.max(0, root.openPrs))).arg(i18n.formatNumber(pulse.failingItems.length)).arg(i18n.formatNumber(Math.max(0, root.reviewReq)))
        accessibleName: i18n.tr("Dev Pulse GitHub activity")
        onClicked: popover.toggle()
    }

    Process {
        id: navProc

        command: ["qs", "ipc", "call", "drawers", "dashboardTab", "hornero-github-stats:devpulse"]
    }

    Process {
        id: openProc

        property string target: ""

        command: ["xdg-open", target]
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Dev Pulse")

        Column {
            width: 340
            spacing: Theme.spacing.small

            UiText {
                role: "title"
                text: i18n.tr("Dev Pulse")
            }

            UiText {
                visible: pulse.account.length > 0
                width: parent.width
                role: "caption"
                text: i18n.tr("Signed in via gh as %1").arg(pulse.account)
            }

            UiText {
                visible: pulse.stale
                width: parent.width
                role: "caption"
                text: i18n.tr("Showing last known data; the latest check failed.")
            }

            UiState {
                visible: pulse.failed
                width: parent.width
                kind: "error"
                message: i18n.tr("GitHub unavailable: check gh is installed and signed in (gh auth login).")
            }

            UiMetric {
                visible: pulse.calendar !== null
                size: "value"
                label: i18n.tr("Contributions (window)")
                value: pulse.calendar ? i18n.formatNumber(Number(pulse.calendar.totalContributions || 0)) : ""
            }

            UiText {
                visible: pulse.failingItems.length > 0
                width: parent.width
                role: "caption"
                text: i18n.tr("Failing checks")
            }

            Repeater {
                model: pulse.failingItems.slice(0, 3)

                UiActionRow {
                    required property var modelData

                    width: parent.width
                    glyph: "alert-circle"
                    text: String(modelData.repo || "") + " — " + String(modelData.title || "")
                    accessibleName: text
                    onClicked: {
                        openProc.target = String(modelData.url || "");
                        openProc.running = true;
                    }
                }
            }

            UiText {
                visible: pulse.reviewItems.length > 0
                width: parent.width
                role: "caption"
                text: i18n.tr("Review requested")
            }

            Repeater {
                model: pulse.reviewItems.slice(0, 3)

                UiActionRow {
                    required property var modelData

                    width: parent.width
                    glyph: "eye"
                    text: String(modelData.repo || "") + " — " + String(modelData.title || "")
                    accessibleName: text
                    onClicked: {
                        openProc.target = String(modelData.url || "");
                        openProc.running = true;
                    }
                }
            }

            UiText {
                visible: pulse.mineItems.length > 0
                width: parent.width
                role: "caption"
                text: i18n.tr("Recent open PRs")
            }

            Repeater {
                model: pulse.mineItems.slice(0, 3)

                UiActionRow {
                    required property var modelData

                    width: parent.width
                    glyph: "activity"
                    text: String(modelData.repo || "") + " — " + String(modelData.title || "")
                    accessibleName: text
                    onClicked: {
                        openProc.target = String(modelData.url || "");
                        openProc.running = true;
                    }
                }
            }

            UiActionRow {
                width: parent.width
                glyph: "layout-grid"
                text: i18n.tr("Open Dev Pulse")
                accessibleName: i18n.tr("Open the full Dev Pulse dashboard")
                onClicked: {
                    popover.close();
                    navProc.running = true;
                }
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
