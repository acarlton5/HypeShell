import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Column {
    id: root

    spacing: Theme.spacingXL

    readonly property var intervalOptions: [
        {
            label: I18n.tr("Every 15 minutes"),
            seconds: 900
        },
        {
            label: I18n.tr("Every 30 minutes"),
            seconds: 1800
        },
        {
            label: I18n.tr("Every hour"),
            seconds: 3600
        },
        {
            label: I18n.tr("Every 4 hours"),
            seconds: 14400
        },
        {
            label: I18n.tr("Once a day"),
            seconds: 86400
        }
    ]

    function intervalLabelFor(seconds) {
        for (const opt of intervalOptions) {
            if (opt.seconds === seconds) {
                return opt.label;
            }
        }
        return intervalOptions[1].label;
    }

    function intervalSecondsFor(label) {
        for (const opt of intervalOptions) {
            if (opt.label === label) {
                return opt.seconds;
            }
        }
        return 1800;
    }

    property bool showLogDetails: false
    property real animatedProgress: SystemUpdateService.progress
    Behavior on animatedProgress {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    SettingsCard {
        width: parent.width
        iconName: SystemUpdateService.isUpgrading ? "refresh" : (SystemUpdateService.updateCount > 0 ? "system_update_alt" : "check_circle")
        title: I18n.tr("Update Status")
        settingKey: "systemUpdaterStatus"

        Column {
            width: parent.width - Theme.spacingM * 2
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            spacing: Theme.spacingM

            // ACTIVE UPGRADE VIEW (Progress bar, current step, and optional collapsible details)
            Column {
                width: parent.width
                spacing: Theme.spacingM
                visible: SystemUpdateService.isUpgrading

                // Progress Hero Box
                Rectangle {
                    width: parent.width
                    height: 104
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
                                width: parent.width - pctLabel.implicitWidth
                                text: SystemUpdateService.statusStep || I18n.tr("Applying updates in background…")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                id: pctLabel
                                text: `${SystemUpdateService.progressPercent}%`
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Animated Progress Bar Track
                        Rectangle {
                            width: parent.width
                            height: 12
                            radius: 6
                            color: Theme.withAlpha(Theme.surfaceContainerLowest, 0.6)
                            clip: true

                            Rectangle {
                                height: parent.height
                                width: Math.max(12, parent.width * Math.min(1.0, Math.max(0.04, root.animatedProgress)))
                                radius: parent.radius
                                color: Theme.primary

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
                                width: parent.width - 24
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Collapsible Log / Details Toggle
                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    Rectangle {
                        width: 140
                        height: 32
                        radius: 16
                        color: detailsToggleArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.14) : Theme.withAlpha(Theme.surfaceVariantText, 0.08)

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            HypeIcon {
                                name: root.showLogDetails ? "keyboard_arrow_up" : "keyboard_arrow_down"
                                size: 16
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: root.showLogDetails ? I18n.tr("Hide Details") : I18n.tr("View Details")
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
                            onClicked: root.showLogDetails = !root.showLogDetails
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - 140 - Theme.spacingM - cancelBtn.width)
                        height: 1
                    }

                    HypeButton {
                        id: cancelBtn
                        height: 32
                        text: I18n.tr("Cancel Update")
                        iconName: "close"
                        backgroundColor: Theme.withAlpha(Theme.error, 0.16)
                        textColor: Theme.error
                        onClicked: SystemUpdateService.cancelUpdates()
                    }
                }

                // Collapsible Details Log Box (Hidden by default!)
                Rectangle {
                    width: parent.width
                    height: 160
                    radius: Theme.cornerRadius
                    color: "#0d1117"
                    border.color: Theme.withAlpha(Theme.outline, 0.16)
                    border.width: 1
                    visible: root.showLogDetails
                    clip: true

                    HypeFlickable {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        contentWidth: width
                        contentHeight: Math.max(height, logOutputText.implicitHeight)
                        clip: true

                        onContentHeightChanged: {
                            if (contentHeight > height)
                                contentY = contentHeight - height;
                        }

                        StyledText {
                            id: logOutputText
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
            }

            // IDLE / STATUS VIEW (When not updating)
            Column {
                width: parent.width
                spacing: Theme.spacingM
                visible: !SystemUpdateService.isUpgrading

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    Column {
                        width: parent.width - actionBtn.width - Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            text: {
                                if (SystemUpdateService.isChecking)
                                    return I18n.tr("Checking for updates…");
                                if (SystemUpdateService.hasError)
                                    return I18n.tr("Update error");
                                if (SystemUpdateService.updateCount > 0)
                                    return I18n.tr("%1 updates available to install").arg(SystemUpdateService.updateCount);
                                return I18n.tr("Your system is up to date");
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: {
                                const names = (SystemUpdateService.backends || []).map(b => b.displayName).join(", ");
                                return names.length > 0 ? I18n.tr("Detected: %1").arg(names) : "";
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    HypeButton {
                        id: actionBtn
                        anchors.verticalCenter: parent.verticalCenter
                        width: 140
                        height: 38
                        text: SystemUpdateService.updateCount > 0 ? I18n.tr("Update All") : I18n.tr("Check Now")
                        iconName: SystemUpdateService.updateCount > 0 ? "system_update_alt" : "refresh"
                        backgroundColor: SystemUpdateService.updateCount > 0 ? Theme.primary : Theme.surfaceContainerHighest
                        textColor: SystemUpdateService.updateCount > 0 ? Theme.primaryText : Theme.surfaceText
                        onClicked: {
                            if (SystemUpdateService.updateCount > 0) {
                                SystemUpdateService.runUpdates();
                            } else {
                                SystemUpdateService.checkForUpdates();
                            }
                        }
                    }
                }

                // Pending updates list in Settings
                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: SystemUpdateService.availableUpdates.length > 0 && !SystemUpdateService.isChecking

                    Repeater {
                        model: SystemUpdateService.availableUpdates

                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 44
                            radius: Theme.cornerRadius
                            color: Theme.withAlpha(Theme.surfaceVariantText, 0.05)

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingM

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 48
                                    height: 20
                                    radius: 10
                                    color: modelData.repo === "hypeshell" ? Theme.withAlpha(Theme.primary, 0.2) : Theme.withAlpha(Theme.surfaceVariantText, 0.12)

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.repo === "hypeshell" ? "hype" : (modelData.repo || "")
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        color: modelData.repo === "hypeshell" ? Theme.primary : Theme.surfaceText
                                    }
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 140
                                    text: modelData.name || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
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
                    }
                }
            }
        }
    }

    SettingsCard {
        width: parent.width
        iconName: "refresh"
        title: I18n.tr("System Updater")
        settingKey: "systemUpdater"

                StyledText {
                    width: parent.width - Theme.spacingM * 2
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    visible: SystemUpdateService.backends.length > 0
                    text: {
                        const names = (SystemUpdateService.backends || []).map(b => b.displayName).join(", ");
                        return I18n.tr("Detected backends: %1").arg(names);
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                SettingsDropdownRow {
                    text: I18n.tr("Check interval")
                    description: I18n.tr("How often the server polls for new updates.")
                    options: root.intervalOptions.map(o => o.label)
                    currentValue: root.intervalLabelFor(SettingsData.updaterIntervalSeconds)
                    onValueChanged: label => {
                        const secs = root.intervalSecondsFor(label);
                        SettingsData.set("updaterIntervalSeconds", secs);
                        SystemUpdateService.setInterval(secs);
                    }
                }

                SettingsToggleRow {
                    text: I18n.tr("Include Flatpak updates")
                    description: I18n.tr("Apply Flatpak updates alongside system updates when running 'Update All'.")
                    visible: (SystemUpdateService.backends || []).some(b => b.repo === "flatpak")
                    checked: SettingsData.updaterIncludeFlatpak
                    onToggled: checked => SettingsData.set("updaterIncludeFlatpak", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Include AUR updates")
                    description: I18n.tr("Run paru/yay with AUR enabled when 'Update All' is clicked.")
                    visible: (SystemUpdateService.backends || []).some(b => b.id === "paru" || b.id === "yay")
                    checked: SettingsData.updaterAllowAUR
                    onToggled: checked => SettingsData.set("updaterAllowAUR", checked)
                }

                TerminalPickerRow {}
    }

    SettingsCard {
        width: parent.width
                iconName: "tune"
                title: I18n.tr("Advanced")
                settingKey: "systemUpdaterAdvanced"

                SettingsToggleRow {
                    text: I18n.tr("Use custom command")
                    description: I18n.tr("Open a terminal and run a custom command instead of the in-shell upgrade flow.")
                    checked: SettingsData.updaterUseCustomCommand
                    onToggled: checked => {
                        if (!checked) {
                            updaterCustomCommand.text = "";
                            updaterTerminalCustomClass.text = "";
                            SettingsData.set("updaterCustomCommand", "");
                            SettingsData.set("updaterTerminalAdditionalParams", "");
                        }
                        SettingsData.set("updaterUseCustomCommand", checked);
                    }
                }

                Rectangle {
                    width: parent.width - Theme.spacingM * 2
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    visible: SettingsData.updaterUseCustomCommand
                    height: warnText.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)

                    StyledText {
                        id: warnText
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        text: I18n.tr("Custom command and terminal params are split on whitespace; paths with spaces will break.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.warning
                        wrapMode: Text.WordWrap
                    }
                }

                FocusScope {
                    width: parent.width - Theme.spacingM * 2
                    height: customCommandColumn.implicitHeight
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    visible: SettingsData.updaterUseCustomCommand

                    Column {
                        id: customCommandColumn
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Custom update command")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        HypeTextField {
                            id: updaterCustomCommand
                            width: parent.width
                            placeholderText: "topgrade --no-retry"
                            backgroundColor: Theme.surfaceContainerHighest
                            normalBorderColor: Theme.outlineMedium
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                if (SettingsData.updaterCustomCommand) {
                                    text = SettingsData.updaterCustomCommand;
                                }
                            }

                            onTextEdited: SettingsData.set("updaterCustomCommand", text.trim())

                            MouseArea {
                                anchors.fill: parent
                                onPressed: mouse => {
                                    updaterCustomCommand.forceActiveFocus();
                                    mouse.accepted = false;
                                }
                            }
                        }
                    }
                }

                FocusScope {
                    width: parent.width - Theme.spacingM * 2
                    height: terminalParamsColumn.implicitHeight
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    visible: SettingsData.updaterUseCustomCommand

                    Column {
                        id: terminalParamsColumn
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Terminal additional parameters")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        HypeTextField {
                            id: updaterTerminalCustomClass
                            width: parent.width
                            placeholderText: "-T updater"
                            backgroundColor: Theme.surfaceContainerHighest
                            normalBorderColor: Theme.outlineMedium
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                if (SettingsData.updaterTerminalAdditionalParams) {
                                    text = SettingsData.updaterTerminalAdditionalParams;
                                }
                            }

                            onTextEdited: SettingsData.set("updaterTerminalAdditionalParams", text.trim())

                            MouseArea {
                                anchors.fill: parent
                                onPressed: mouse => {
                                    updaterTerminalCustomClass.forceActiveFocus();
                                    mouse.accepted = false;
                                }
                            }
                        }
                    }
                }
    }
}
