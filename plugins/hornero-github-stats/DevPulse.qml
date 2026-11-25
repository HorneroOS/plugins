import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Hornero.PluginKit

// Dev Pulse flagship page (PluginKit 5 dashboardTab): GitHub
// development activity as a Hornero Signal instrument panel —
// contributions, PR/issue lifecycle, repositories, an actionable
// inbox, and an optional Agent Deck comparison. Every figure is a
// real horneroctl record; missing data reads as unavailable, never
// as zero, and AI tokens are only ever temporally associated with
// GitHub activity, never attributed to it.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property bool hostCompact: false
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property string hostSurface: "dashboardTab"

    readonly property int viewportCap: hostAvailableHeight > 0 ? hostAvailableHeight : Screen.height > 0 ? Math.max(320, Screen.height - 220) : 760

    implicitWidth: hostAvailableWidth > 0 ? Math.min(1180, hostAvailableWidth) : 968
    implicitHeight: col.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-github-stats"
    }

    GithubData {
        id: pulse
    }

    Process {
        id: openProc

        property string target: ""

        command: ["xdg-open", target]
    }

    function openItem(url: string): void {
        if (url.length > 0) {
            openProc.target = url;
            openProc.running = true;
        }
    }

    Column {
        id: col

        width: parent.width
        spacing: Theme.spacing.normal

        UiStack {
            width: parent.width
            orientation: root.hostOrientation
            compact: root.hostCompact

            UiEyebrow {
                channel: 9
                text: i18n.tr("DEV PULSE")
                context: pulse.account.length > 0 ? i18n.tr("GH · %1").arg(pulse.account) : ""
            }

            UiButton {
                glyph: "refresh"
                text: i18n.tr("Refresh")
                accessibleName: i18n.tr("Refresh GitHub activity")
                onClicked: pulse.refresh(true)
            }
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
            message: i18n.tr("GitHub unavailable: install github-cli and run gh auth login, then Refresh.")
        }

        UiState {
            visible: pulse.loading && !pulse.hasData
            width: parent.width
            kind: "loading"
            message: i18n.tr("Collecting GitHub activity…")
        }

        // Window selector
        UiStack {
            visible: pulse.hasData
            width: parent.width
            orientation: root.hostOrientation
            compact: root.hostCompact

            UiText {
                role: "caption"
                text: i18n.tr("ACTIVITY WINDOW")
            }

            Row {
                visible: root.width >= 760
                spacing: Theme.spacing.small

                Repeater {
                    model: ["7", "30", "90", "365", "all"]

                    UiButton {
                        required property var modelData

                        variant: pulse.statsWindow === modelData ? "primary" : "secondary"
                        text: modelData === "all" ? i18n.tr("All") : modelData + "d"
                        accessibleName: i18n.tr("Activity window")
                        onClicked: pulse.setStatsWindow(modelData)
                    }
                }
            }

            UiComboBox {
                visible: root.width < 760
                model: ["7d", "30d", "90d", "365d", i18n.tr("All")]
                currentIndex: ["7", "30", "90", "365", "all"].indexOf(pulse.statsWindow)
                accessibleName: i18n.tr("Activity window")
                onActivated: index => pulse.setStatsWindow(["7", "30", "90", "365", "all"][index])
            }
        }

        // Overview metrics
        UiStack {
            visible: pulse.calendar !== null
            width: parent.width
            orientation: root.hostOrientation
            compact: root.hostCompact

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Contributions")
                value: pulse.calendar ? i18n.formatNumber(Number(pulse.calendar.totalContributions || 0)) : ""
            }
            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Commits (recognized)")
                value: pulse.calendar ? i18n.formatNumber(Number(pulse.calendar.totalCommitContributions || 0)) : ""
            }
            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Active days")
                value: pulse.calendar ? i18n.formatNumber(Number(pulse.calendar.activeDays || 0)) : ""
            }
            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Current streak")
                value: pulse.calendar ? i18n.formatNumber(Number(pulse.calendar.currentStreak || 0)) : ""
                unit: i18n.tr("d")
            }
            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Longest streak")
                value: pulse.calendar ? i18n.formatNumber(Number(pulse.calendar.longestStreak || 0)) : ""
                unit: i18n.tr("d")
            }
        }

        // Contribution heatmap + trend (genuine calendar days only)
        Column {
            visible: pulse.calendar !== null && pulse.dailyEntries(pulse.calendar).length >= 2
            width: parent.width
            spacing: Theme.spacing.small

            UiText {
                role: "caption"
                text: i18n.tr("CONTRIBUTION DAYS").toUpperCase()
            }

            Grid {
                columns: 30
                spacing: 2

                Repeater {
                    model: pulse.dailyEntries(pulse.calendar)

                    Rectangle {
                        required property var modelData

                        width: 10
                        height: 10
                        radius: 2
                        color: Theme.palette.signal
                        opacity: modelData.count <= 0 ? 0.08 : Math.min(1, 0.25 + modelData.count / 20)
                    }
                }
            }

            UiSparkline {
                width: parent.width
                height: 40
                values: pulse.dailyEntries(pulse.calendar).map(e => e.count)
                window: Math.max(2, pulse.dailyEntries(pulse.calendar).length)
                tone: "cue"
                accessibleName: i18n.tr("Daily contributions")
            }
        }

        // PR / issue lifecycle from search-partitioned totals
        UiStack {
            visible: pulse.totals !== null
            width: parent.width
            orientation: root.hostOrientation
            compact: root.hostCompact

            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("PRs created")
                value: pulse.totals && pulse.totals.prsCreated !== undefined ? i18n.formatNumber(Number(pulse.totals.prsCreated)) : ""
                available: pulse.totals !== null && pulse.totals.prsCreated !== undefined
            }
            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("PRs merged")
                value: pulse.totals && pulse.totals.prsMerged !== undefined ? i18n.formatNumber(Number(pulse.totals.prsMerged)) : ""
                available: pulse.totals !== null && pulse.totals.prsMerged !== undefined
            }
            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("PRs open")
                value: pulse.totals && pulse.totals.prsOpen !== undefined ? i18n.formatNumber(Number(pulse.totals.prsOpen)) : ""
                available: pulse.totals !== null && pulse.totals.prsOpen !== undefined
            }
            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Issues opened")
                value: pulse.totals && pulse.totals.issuesOpened !== undefined ? i18n.formatNumber(Number(pulse.totals.issuesOpened)) : ""
                available: pulse.totals !== null && pulse.totals.issuesOpened !== undefined
            }
            UiMetric {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                size: "value"
                label: i18n.tr("Reviews (contributions)")
                value: pulse.calendar ? i18n.formatNumber(Number(pulse.calendar.totalPullRequestReviewContributions || 0)) : ""
            }
        }

        UiText {
            visible: pulse.totals !== null && pulse.totals.truncated === true
            width: parent.width
            role: "caption"
            text: i18n.tr("Some totals could not be collected; missing metrics are omitted, not zeroed.")
        }

        // Repositories
        Column {
            visible: pulse.repoRecords.length > 0
            width: parent.width
            spacing: Theme.spacing.small

            UiText {
                role: "caption"
                text: i18n.tr("REPOSITORIES BY COMMIT CONTRIBUTIONS").toUpperCase()
            }

            Repeater {
                model: pulse.repoRecords.slice(0, 12)

                UiDetailRow {
                    required property var modelData

                    width: parent.width
                    label: String(modelData.repo || "")
                    value: i18n.tr("%1 commits · %2").arg(i18n.formatNumber(Number(modelData.commitContributions || 0))).arg(String(modelData.visibility || ""))
                }
            }
        }

        // Development inbox
        Column {
            visible: pulse.inboxItems.length > 0
            width: parent.width
            spacing: Theme.spacing.small

            UiText {
                role: "caption"
                text: i18n.tr("DEVELOPMENT INBOX").toUpperCase()
            }

            Repeater {
                model: pulse.inboxItems.slice(0, 20)

                UiActionRow {
                    required property var modelData

                    width: parent.width
                    glyph: "activity"
                    text: String(modelData.repo || "") + " — " + String(modelData.title || "")
                    accessibleName: text
                    onClicked: root.openItem(String(modelData.url || ""))
                }
            }
        }

        // Optional Agent Deck comparison (temporal association only)
        Column {
            visible: pulse.agentRecords.length > 0 && pulse.calendar !== null
            width: parent.width
            spacing: Theme.spacing.small

            UiText {
                role: "caption"
                text: i18n.tr("AI ACTIVITY (AGENT DECK) — SAME PERIOD, NOT ATTRIBUTION").toUpperCase()
            }

            UiSparkline {
                width: parent.width
                height: 40
                values: pulse.agentDailyValues(pulse.statsWindowDays)
                window: Math.max(2, pulse.agentDailyValues(pulse.statsWindowDays).length)
                tone: "cue"
                accessibleName: i18n.tr("Daily AI tokens (local scope)")
            }

            UiText {
                width: parent.width
                role: "caption"
                text: i18n.tr("AI tokens are machine-local Agent Deck buckets shown beside GitHub activity for the same dates. No pull request is attributed to an agent from timing alone.")
            }
        }

        UiText {
            visible: pulse.hasData
            width: parent.width
            role: "caption"
            text: i18n.tr("Coverage: GitHub contributions recognized by GitHub over the selected window, plus search totals by actual event date. Exports: horneroctl github export.")
        }
    }
}
