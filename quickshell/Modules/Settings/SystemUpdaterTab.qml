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

    function formatLastCheck(unixSec) {
        if (!unixSec || unixSec <= 0)
            return I18n.tr("Never checked");
        const diff = Math.floor(Date.now() / 1000 - unixSec);
        if (diff < 60)
            return I18n.tr("Just now");
        if (diff < 3600)
            return I18n.tr("%1 minutes ago").arg(Math.floor(diff / 60));
        if (diff < 86400)
            return I18n.tr("%1 hours ago").arg(Math.floor(diff / 3600));
        return I18n.tr("%1 days ago").arg(Math.floor(diff / 86400));
    }

    // SteamOS Update Status Hero Card
    SettingsCard {
        width: parent.width
        iconName: "system_update"
        title: I18n.tr("Update Status")
        settingKey: "systemUpdateStatus"

        Rectangle {
            width: parent.width - Theme.spacingM * 2
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            height: 96
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.5)
            border.color: Theme.withAlpha(Theme.outline, 0.12)
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.right: actionButtonsRow.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingL

                Rectangle {
                    width: 52
                    height: 52
                    radius: 26
                    color: {
                        if (SystemUpdateService.hasError)
                            return Theme.withAlpha(Theme.error, 0.12);
                        if (SystemUpdateService.isUpgrading)
                            return Theme.withAlpha(Theme.primary, 0.16);
                        if (SystemUpdateService.updateCount > 0)
                            return Theme.withAlpha(Theme.primary, 0.12);
                        return Theme.withAlpha(Theme.success, 0.12);
                    }
                    anchors.verticalCenter: parent.verticalCenter

                    HypeIcon {
                        anchors.centerIn: parent
                        name: {
                            if (SystemUpdateService.hasError)
                                return "error";
                            if (SystemUpdateService.isUpgrading)
                                return "system_update";
                            if (SystemUpdateService.updateCount > 0)
                                return "system_update_alt";
                            return "check_circle";
                        }
                        size: 28
                        color: {
                            if (SystemUpdateService.hasError)
                                return Theme.error;
                            if (SystemUpdateService.isUpgrading || SystemUpdateService.updateCount > 0)
                                return Theme.primary;
                            return Theme.success;
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 52 - Theme.spacingL
                    spacing: 4

                    StyledText {
                        text: {
                            if (SystemUpdateService.isUpgrading)
                                return I18n.tr("Applying System Updates…");
                            if (SystemUpdateService.isChecking)
                                return I18n.tr("Checking for Updates…");
                            if (SystemUpdateService.hasError)
                                return I18n.tr("Update Error");
                            if (SystemUpdateService.updateCount > 0)
                                return I18n.tr("%1 Updates Available").arg(SystemUpdateService.updateCount);
                            return I18n.tr("Your System is Up to Date");
                        }
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    StyledText {
                        text: {
                            if (SystemUpdateService.isUpgrading)
                                return I18n.tr("Installing packages seamlessly in the background");
                            return I18n.tr("Last checked: %1").arg(root.formatLastCheck(SystemUpdateService.lastCheckUnix));
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            Row {
                id: actionButtonsRow
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                HypeButton {
                    height: 40
                    text: I18n.tr("Check for Updates")
                    iconName: "refresh"
                    enabled: !SystemUpdateService.isChecking && !SystemUpdateService.isUpgrading
                    onClicked: SystemUpdateService.checkForUpdates()
                }

                HypeButton {
                    height: 40
                    text: SystemUpdateService.isUpgrading ? I18n.tr("Cancel") : I18n.tr("Apply Updates")
                    iconName: SystemUpdateService.isUpgrading ? "close" : "system_update_alt"
                    visible: SystemUpdateService.isUpgrading || SystemUpdateService.updateCount > 0
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    enabled: !SystemUpdateService.isChecking
                    onClicked: {
                        if (SystemUpdateService.isUpgrading) {
                            SystemUpdateService.cancelUpdates();
                            return;
                        }
                        PopoutService.openSystemUpdateFromSettings();
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
