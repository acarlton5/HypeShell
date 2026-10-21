import QtQuick
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Modals
import qs.Services
import qs.Widgets

HypePopout {
    id: systemUpdatePopout

    layerNamespace: "hype:system-update"

    property var parentWidget: null
    property var triggerScreen: null

    Ref {
        service: SystemUpdateService
    }

    property bool _reopenAfterUpgrade: false
    property bool _updateTerminalWasSeen: false
    property int _terminalProbeAttempts: 0

    readonly property bool polkitModalOpen: polkitAuthSurfaceModal.shouldBeVisible
    readonly property bool inlineAuthActive: (PolkitService.agent?.isActive ?? false) && PolkitService.agent?.flow !== null
    readonly property bool anyModalOpen: polkitModalOpen || inlineAuthActive

    Connections {
        target: PolkitService.agent
        enabled: PolkitService.polkitAvailable && systemUpdatePopout.shouldBeVisible

        function onAuthenticationRequestStarted() {
            Qt.callLater(() => {
                const item = systemUpdatePopout.contentLoader.item;
                if (item && item.inlineAuthContent) {
                    item.inlineAuthContent.reset();
                    item.inlineAuthContent.forceActiveFocus();
                    item.inlineAuthContent.focusPasswordField();
                }
            });
        }
    }

    PolkitAuthSurfaceModal {
        id: polkitAuthSurfaceModal
        parentPopout: systemUpdatePopout
    }

    backgroundInteractive: !anyModalOpen

    customKeyboardFocus: {
        if (!shouldBeVisible)
            return WlrKeyboardFocus.None;
        if (polkitModalOpen)
            return WlrKeyboardFocus.None;
        if (CompositorService.useHyprlandFocusGrab)
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.Exclusive;
    }

    Connections {
        target: SystemUpdateService
        function onIsUpgradingChanged() {
            const item = systemUpdatePopout.contentLoader.item;
            if (item) {
                item.upgradeStarting = false;
            }
            if (SystemUpdateService.isUpgrading)
                return;
            if (!systemUpdatePopout._reopenAfterUpgrade)
                return;
            terminalCloseTimer.restart();
        }
    }

    Timer {
        id: terminalCloseTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!terminalWindowProbe.running)
                terminalWindowProbe.running = true;
        }
    }

    Process {
        id: terminalWindowProbe
        command: ["sh", "-c", "test -e \"${XDG_RUNTIME_DIR:-/tmp}/hypeshell-update-terminal.active\""]
        running: false
        onExited: exitCode => {
            if (!systemUpdatePopout._reopenAfterUpgrade)
                return;
            systemUpdatePopout._terminalProbeAttempts++;
            if (exitCode === 0) {
                systemUpdatePopout._updateTerminalWasSeen = true;
                terminalCloseTimer.restart();
                return;
            }
            if (SystemUpdateService.isUpgrading || (!systemUpdatePopout._updateTerminalWasSeen && systemUpdatePopout._terminalProbeAttempts < 12)) {
                terminalCloseTimer.restart();
                return;
            }
            systemUpdatePopout._reopenAfterUpgrade = false;
            systemUpdatePopout.open();
        }
    }

    popupWidth: 460
    popupHeight: 520
    triggerWidth: 55
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false
    contentHandlesKeys: true

    onBackgroundClicked: {
        if (anyModalOpen)
            return;
        close();
    }

    onShouldBeVisibleChanged: {
        if (!shouldBeVisible)
            return;
        const stale = !SystemUpdateService.lastCheckUnix || (Date.now() / 1000 - SystemUpdateService.lastCheckUnix) > 300;
        if (stale && !SystemUpdateService.isChecking && !SystemUpdateService.isUpgrading)
            SystemUpdateService.checkForUpdates();
    }

    content: Component {
        FocusScope {
            id: updaterPanel

            focus: true

            property bool upgradeStarting: false
            property bool showLogDetails: false
            property var queuedUpdates: []

            property real animatedProgress: SystemUpdateService.progress
            Behavior on animatedProgress {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }

            readonly property alias inlineAuthContent: inlineAuthLoader.item

            readonly property var hypeShellUpdate: (SystemUpdateService.availableUpdates || []).find(pkg => pkg.backend === "hypeshell" || pkg.repo === "hypeshell" || pkg.name === "HypeShell") || null
            readonly property bool hasHypeShellUpdate: hypeShellUpdate !== null
            readonly property int hypeShellUpdateCount: hasHypeShellUpdate ? 1 : 0
            readonly property var hypeShellUpdates: hasHypeShellUpdate ? [hypeShellUpdate] : []
            readonly property var generalUpdates: (SystemUpdateService.availableUpdates || []).filter(pkg => pkg.backend !== "hypeshell" && pkg.repo !== "hypeshell" && pkg.name !== "HypeShell")
            readonly property var allUpdates: hypeShellUpdates.concat(generalUpdates)
            readonly property int generalUpdateCount: generalUpdates.length
            readonly property int pacmanUpdatesCount: generalUpdates.filter(pkg => pkg.backend === "pacman").length
            readonly property int paruUpdatesCount: generalUpdates.filter(pkg => pkg.backend === "paru" || pkg.backend === "yay" || pkg.repo === "aur").length
            readonly property int flatpakUpdatesCount: generalUpdates.filter(pkg => pkg.backend === "flatpak" || pkg.repo === "flatpak").length
            readonly property color statusColor: SystemUpdateService.hasError ? Theme.error : (SystemUpdateService.isUpgrading ? Theme.primary : Theme.surfaceVariantText)

            function prepareTerminalUpdate() {
                systemUpdatePopout._reopenAfterUpgrade = true;
                systemUpdatePopout._updateTerminalWasSeen = false;
                systemUpdatePopout._terminalProbeAttempts = 0;
                systemUpdatePopout.close();
                terminalCloseTimer.restart();
            }

            function handleUpgradeStartError(response) {
                upgradeStarting = false;
                if (!response?.error)
                    return false;
                systemUpdatePopout._reopenAfterUpgrade = false;
                systemUpdatePopout.open();
                ToastService.showError(I18n.tr("Update failed to start"), response.error);
                return true;
            }

            function runUpdate() {
                if (upgradeStarting)
                    return;
                if (SystemUpdateService.isUpgrading) {
                    SystemUpdateService.cancelUpdates();
                    return;
                }
                if (hypeShellUpdateCount + generalUpdateCount === 0)
                    return;
                upgradeStarting = true;
                queuedUpdates = allUpdates.filter(pkg => {
                    if ((pkg.backend === "flatpak" || pkg.repo === "flatpak") && !SettingsData.updaterIncludeFlatpak)
                        return false;
                    if ((pkg.backend === "paru" || pkg.backend === "yay" || pkg.repo === "aur") && !SettingsData.updaterAllowAUR)
                        return false;
                    return true;
                });

                if (SettingsData.updaterUseCustomCommand && SettingsData.updaterCustomCommand.length > 0) {
                    prepareTerminalUpdate();
                    SystemUpdateService.runUpdates();
                    return;
                }

                const opts = {
                    includeFlatpak: SettingsData.updaterIncludeFlatpak,
                    includeAUR: SettingsData.updaterAllowAUR,
                    targets: queuedUpdates
                };
                HYPEService.sysupdateUpgrade(opts, response => {
                    if (handleUpgradeStartError(response))
                        return;
                    upgradeStarting = false;
                    SystemUpdateService.requestState();
                });
            }

            function statusSubtitle() {
                if (SystemUpdateService.isUpgrading) {
                    if (SystemUpdateService.statusStep && SystemUpdateService.statusStep.length > 0)
                        return SystemUpdateService.statusStep;
                    return I18n.tr("Applying updates in background…");
                }
                if (SystemUpdateService.isChecking)
                    return I18n.tr("Checking for updates…");
                if (SystemUpdateService.hasError)
                    return SystemUpdateService.errorMessage || I18n.tr("An error occurred");
                const total = hypeShellUpdateCount + generalUpdateCount;
                if (total === 0)
                    return I18n.tr("All components are up to date");
                return I18n.tr("%1 updates available to install").arg(total);
            }

            function repoLabel(pkg) {
                if (!pkg)
                    return "";
                if (pkg.repo === "hypeshell")
                    return "hype";
                return pkg.repo || "";
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    systemUpdatePopout.close();
                    event.accepted = true;
                    return;
                }
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                    updaterPanel.runUpdate();
                    event.accepted = true;
                }
            }

            Component.onCompleted: {
                if (systemUpdatePopout.shouldBeVisible)
                    forceActiveFocus();
            }

            // Inline Authentication Overlay
            Rectangle {
                anchors.fill: parent
                visible: systemUpdatePopout.inlineAuthActive
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.96)
                    border.color: Theme.withAlpha(Theme.primary, 0.35)
                    border.width: 1
                    clip: true

                    Loader {
                        id: inlineAuthLoader
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        active: systemUpdatePopout.inlineAuthActive
                        focus: true
                        sourceComponent: PolkitAuthContent {
                            focus: true
                        }
                    }
                }
            }

            // Main Popout Interface
            Rectangle {
                anchors.fill: parent
                visible: !systemUpdatePopout.inlineAuthActive
                color: "transparent"

                // Header
                Row {
                    id: popoutHeader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    height: 44
                    spacing: Theme.spacingM

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: Theme.withAlpha(updaterPanel.statusColor, 0.14)
                        anchors.verticalCenter: parent.verticalCenter

                        HypeIcon {
                            anchors.centerIn: parent
                            name: {
                                if (SystemUpdateService.isUpgrading || SystemUpdateService.isChecking)
                                    return "refresh";
                                if (SystemUpdateService.hasError)
                                    return "error";
                                if (updaterPanel.allUpdates.length > 0)
                                    return "system_update_alt";
                                return "check_circle";
                            }
                            size: 22
                            color: updaterPanel.statusColor

                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: SystemUpdateService.isChecking || SystemUpdateService.isUpgrading

                                onRunningChanged: {
                                    if (!running)
                                        parent.rotation = 0;
                                }
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40 - Theme.spacingM * 2 - refreshBtn.width
                        spacing: 2

                        StyledText {
                            text: I18n.tr("System Updates")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: updaterPanel.statusSubtitle()
                            font.pixelSize: Theme.fontSizeSmall
                            color: updaterPanel.statusColor
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    HypeActionButton {
                        id: refreshBtn
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: 34
                        iconName: "refresh"
                        iconSize: 18
                        enabled: !SystemUpdateService.isChecking && !SystemUpdateService.isUpgrading
                        opacity: enabled ? 1 : 0.4
                        onClicked: SystemUpdateService.checkForUpdates()
                    }
                }

                // Center Content Area
                Item {
                    id: centralContentArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: popoutHeader.bottom
                    anchors.bottom: bottomActions.top
                    anchors.margins: Theme.spacingL

                    // 1. ACTIVE UPGRADE VIEW (Progress Bar & Live Status)
                    Column {
                        id: upgradeProgressView
                        anchors.fill: parent
                        spacing: Theme.spacingM
                        visible: SystemUpdateService.isUpgrading

                        // Progress Hero Card
                        Rectangle {
                            width: parent.width
                            height: 110
                            radius: Theme.cornerRadius
                            color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.8)
                            border.color: Theme.withAlpha(Theme.primary, 0.28)
                            border.width: 1

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width
                                    height: 24

                                    StyledText {
                                        width: parent.width - percentLabel.implicitWidth
                                        text: SystemUpdateService.statusStep || I18n.tr("Installing updates…")
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.DemiBold
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        id: percentLabel
                                        text: `${SystemUpdateService.progressPercent}%`
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Animated Progress Bar Track
                                Rectangle {
                                    id: progressTrack
                                    width: parent.width
                                    height: 12
                                    radius: 6
                                    color: Theme.withAlpha(Theme.surfaceContainerLowest, 0.6)
                                    clip: true

                                    Rectangle {
                                        id: progressFill
                                        height: parent.height
                                        width: Math.max(12, parent.width * Math.min(1.0, Math.max(0.04, updaterPanel.animatedProgress)))
                                        radius: parent.radius
                                        color: Theme.primary

                                        // Subtle gradient shimmer
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            opacity: 0.35
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: Theme.primary }
                                                GradientStop { position: 1.0; color: Theme.secondary }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    HypeIcon {
                                        name: "schedule"
                                        size: 14
                                        color: Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: SystemUpdateService.currentItem && SystemUpdateService.currentItem.length > 0 ?
                                              SystemUpdateService.currentItem :
                                              I18n.tr("Applying changes smoothly in background…")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        width: parent.width - 20
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Collapsible Log / Details Toggle
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 16
                            color: detailsToggleArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : Theme.withAlpha(Theme.surfaceVariantText, 0.08)

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                HypeIcon {
                                    name: updaterPanel.showLogDetails ? "keyboard_arrow_up" : "keyboard_arrow_down"
                                    size: 16
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: updaterPanel.showLogDetails ? I18n.tr("Hide Details") : I18n.tr("View Details")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: detailsToggleArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: updaterPanel.showLogDetails = !updaterPanel.showLogDetails
                            }
                        }

                        // Collapsible Details Log Box (Hidden by default!)
                        Rectangle {
                            width: parent.width
                            height: parent.height - 110 - 32 - Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: "#0d1117"
                            border.color: Theme.withAlpha(Theme.outline, 0.16)
                            border.width: 1
                            visible: updaterPanel.showLogDetails
                            clip: true

                            HypeFlickable {
                                id: logFlickable
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                contentWidth: width
                                contentHeight: Math.max(height, logText.implicitHeight)
                                clip: true

                                onContentHeightChanged: {
                                    if (contentHeight > height)
                                        contentY = contentHeight - height;
                                }

                                StyledText {
                                    id: logText
                                    width: parent.width
                                    text: (SystemUpdateService.recentLog || []).join("\n")
                                    font.family: Theme.monoFontFamily || "monospace"
                                    font.pixelSize: 11
                                    lineHeight: 1.25
                                    color: "#c9d1d9"
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }

                        // When log details are hidden: Queued Packages Summary
                        Rectangle {
                            width: parent.width
                            height: parent.height - 110 - 32 - Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.6)
                            border.color: Theme.withAlpha(Theme.outline, 0.12)
                            border.width: 1
                            visible: !updaterPanel.showLogDetails
                            clip: true

                            HypeListView {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: 2
                                model: updaterPanel.queuedUpdates.length > 0 ? updaterPanel.queuedUpdates : updaterPanel.allUpdates

                                delegate: Rectangle {
                                    required property var modelData
                                    width: ListView.view.width
                                    height: 40
                                    radius: Theme.cornerRadius
                                    color: "transparent"

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingS
                                        anchors.rightMargin: Theme.spacingS
                                        spacing: Theme.spacingM

                                        HypeIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: "check"
                                            size: 16
                                            color: Theme.primary
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name || ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width - 90
                                        }

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 48
                                            height: 20
                                            radius: 10
                                            color: Theme.withAlpha(Theme.primary, 0.14)

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: updaterPanel.repoLabel(modelData)
                                                font.pixelSize: 10
                                                color: Theme.primary
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. UPDATES AVAILABLE VIEW
                    Rectangle {
                        id: updatesAvailableCard
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.72)
                        border.color: Theme.withAlpha(Theme.outline, 0.14)
                        border.width: 1
                        clip: true
                        visible: !SystemUpdateService.isUpgrading && updaterPanel.allUpdates.length > 0 && !SystemUpdateService.hasError && !SystemUpdateService.isChecking

                        Column {
                            anchors.fill: parent

                            // Subheader summary
                            Rectangle {
                                width: parent.width
                                height: 42
                                color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.35)

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingS

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: I18n.tr("Pending Updates (%1)").arg(updaterPanel.allUpdates.length)
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }
                                }
                            }

                            HypeListView {
                                width: parent.width
                                height: parent.height - 42
                                clip: true
                                spacing: 2
                                model: updaterPanel.allUpdates

                                delegate: Rectangle {
                                    required property var modelData

                                    width: ListView.view.width
                                    height: 52
                                    radius: Theme.cornerRadius
                                    color: packageMouse.containsMouse ? Theme.withAlpha(Theme.surfaceVariantText, 0.08) : "transparent"

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingS
                                        spacing: Theme.spacingM

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 48
                                            height: 22
                                            radius: 11
                                            color: modelData.repo === "hypeshell" ? Theme.withAlpha(Theme.primary, 0.2) : Theme.withAlpha(Theme.surfaceVariantText, 0.12)

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: updaterPanel.repoLabel(modelData)
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: modelData.repo === "hypeshell" ? Theme.primary : Theme.surfaceText
                                            }
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 48 - Theme.spacingM
                                            spacing: 1

                                            StyledText {
                                                width: parent.width
                                                text: modelData.name || ""
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.Medium
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                width: parent.width
                                                text: {
                                                    const from = modelData.fromVersion || "";
                                                    const to = modelData.toVersion || "";
                                                    return from && to ? `${from}  ➔  ${to}` : (to || from);
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: packageMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: modelData.changelogUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (modelData.changelogUrl)
                                                Qt.openUrlExternally(modelData.changelogUrl);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. CLEAN / UP TO DATE VIEW
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.6)
                        border.color: Theme.withAlpha(Theme.outline, 0.12)
                        border.width: 1
                        visible: !SystemUpdateService.isUpgrading && updaterPanel.allUpdates.length === 0 && !SystemUpdateService.hasError && !SystemUpdateService.isChecking

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM
                            width: parent.width - Theme.spacingXL * 2

                            Rectangle {
                                width: 56
                                height: 56
                                radius: 28
                                color: Theme.withAlpha(Theme.success, 0.14)
                                anchors.horizontalCenter: parent.horizontalCenter

                                HypeIcon {
                                    anchors.centerIn: parent
                                    name: "check"
                                    size: 32
                                    color: Theme.success
                                }
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("Everything is up to date")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("All system packages, Flatpaks, and HypeShell are running the latest versions.")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    // 4. CHECKING VIEW
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.6)
                        border.color: Theme.withAlpha(Theme.outline, 0.12)
                        border.width: 1
                        visible: SystemUpdateService.isChecking && !SystemUpdateService.isUpgrading

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            HypeIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "refresh"
                                size: 36
                                color: Theme.primary

                                RotationAnimator on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: SystemUpdateService.isChecking
                                }
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("Checking for updates…")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    // 5. ERROR VIEW
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.error, 0.08)
                        border.color: Theme.withAlpha(Theme.error, 0.25)
                        border.width: 1
                        visible: SystemUpdateService.hasError && !SystemUpdateService.isUpgrading

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM
                            width: parent.width - Theme.spacingXL * 2

                            Rectangle {
                                width: 52
                                height: 52
                                radius: 26
                                color: Theme.withAlpha(Theme.error, 0.18)
                                anchors.horizontalCenter: parent.horizontalCenter

                                HypeIcon {
                                    anchors.centerIn: parent
                                    name: "error"
                                    size: 28
                                    color: Theme.error
                                }
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("Update Check Failed")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.DemiBold
                                color: Theme.error
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: SystemUpdateService.errorMessage || I18n.tr("Failed to contact update service")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }
                }

                // Bottom Action Buttons
                Row {
                    id: bottomActions
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacingL
                    height: 44
                    spacing: Theme.spacingM

                    HypeButton {
                        width: (parent.width - Theme.spacingM) * 0.65
                        height: parent.height
                        text: {
                            if (SystemUpdateService.isUpgrading)
                                return I18n.tr("Cancel Update");
                            if (updaterPanel.allUpdates.length > 0)
                                return I18n.tr("Update All");
                            return I18n.tr("Check for Updates");
                        }
                        iconName: {
                            if (SystemUpdateService.isUpgrading)
                                return "close";
                            if (updaterPanel.allUpdates.length > 0)
                                return "system_update_alt";
                            return "refresh";
                        }
                        enabled: !updaterPanel.upgradeStarting && (!SystemUpdateService.isChecking || SystemUpdateService.isUpgrading)
                        backgroundColor: SystemUpdateService.isUpgrading ? Theme.withAlpha(Theme.error, 0.18) : Theme.primary
                        textColor: SystemUpdateService.isUpgrading ? Theme.error : Theme.primaryText
                        onClicked: {
                            if (SystemUpdateService.isUpgrading) {
                                SystemUpdateService.cancelUpdates();
                            } else if (updaterPanel.allUpdates.length > 0) {
                                updaterPanel.runUpdate();
                            } else {
                                SystemUpdateService.checkForUpdates();
                            }
                        }
                    }

                    HypeButton {
                        width: parent.width - parent.children[0].width - Theme.spacingM
                        height: parent.height
                        text: I18n.tr("Close")
                        onClicked: systemUpdatePopout.close()
                    }
                }
            }
        }
    }
}
