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

            // Progress bar when updating
            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: SystemUpdateService.isUpgrading

                Row {
                    width: parent.width
                    StyledText {
                        width: parent.width - pctLabel.implicitWidth
                        text: SystemUpdateService.statusStep || I18n.tr("Applying updates in background…")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }
                    StyledText {
                        id: pctLabel
                        text: `${SystemUpdateService.progressPercent}%`
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.primary
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 10
                    radius: 5
                    color: Theme.withAlpha(Theme.surfaceContainerLowest, 0.6)
                    clip: true

                    Rectangle {
                        height: parent.height
                        width: Math.max(10, parent.width * Math.min(1.0, Math.max(0.04, SystemUpdateService.progress)))
                        radius: parent.radius
                        color: Theme.primary
                    }
                }
            }

            // Status row when not updating
            Row {
                width: parent.width
                visible: !SystemUpdateService.isUpgrading
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
                                return I18n.tr("%1 updates available").arg(SystemUpdateService.updateCount);
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
                    width: 130
                    height: 36
                    text: SystemUpdateService.updateCount > 0 ? I18n.tr("Update All") : I18n.tr("Check Now")
                    iconName: SystemUpdateService.updateCount > 0 ? "system_update_alt" : "refresh"
                    onClicked: {
                        if (SystemUpdateService.updateCount > 0) {
                            SystemUpdateService.runUpdates();
                        } else {
                            SystemUpdateService.checkForUpdates();
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
