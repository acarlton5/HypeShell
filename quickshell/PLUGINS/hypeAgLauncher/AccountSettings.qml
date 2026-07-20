import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "hypeAgLauncher"

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property var defaultAccounts: [
        { "name": "Primary Pro Account", "launcher": "antigravity", "profileDir": homeDir + "/DevBox/.gemini_primary" },
        { "name": "Secondary Pro Account", "launcher": "antigravity", "profileDir": homeDir + "/DevBox/.gemini_backup" },
        { "name": "Codex Main Window", "launcher": "codex-ide", "profileDir": homeDir + "/.local/share/codex-profiles/main" }
    ]
    property var accounts: []

    function reloadAccounts() {
        const saved = loadValue("accounts", defaultAccounts);
        accounts = Array.isArray(saved) ? saved.slice() : defaultAccounts.slice();
    }

    function storeAccounts(updatedAccounts) {
        accounts = updatedAccounts.slice();
        saveValue("accounts", accounts);
    }

    Component.onCompleted: reloadAccounts()

    Connections {
        target: pluginService
        enabled: pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.reloadAccounts();
        }
    }

    Column {
        id: editorColumn
        width: parent.width
        spacing: Theme.spacingM

        StyledText {
            width: parent.width
            text: "Antigravity Accounts"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
        }

        StyledText {
            width: parent.width
            text: "Add launch profiles to the AG Hub popout. Changes appear immediately."
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        StyledRect {
            width: parent.width
            height: addColumn.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: addColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                StyledText {
                    text: "Add Account"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                }

                HypeTextField {
                    id: accountName
                    width: parent.width
                    placeholderText: "Account name"
                }

                HypeDropdown {
                    id: launcherType
                    width: parent.width
                    text: "Launcher"
                    description: "Choose the Antigravity application"
                    currentValue: "Antigravity"
                    options: ["Antigravity", "Antigravity IDE", "Codex in Antigravity IDE"]
                }

                HypeTextField {
                    id: profileDirectory
                    width: parent.width
                    placeholderText: "~/.local/share/antigravity-profiles/new"
                }

                HypeButton {
                    text: "Add Account"
                    iconName: "add"
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: {
                        const name = accountName.text.trim();
                        const directory = profileDirectory.text.trim();
                        if (name.length === 0 || directory.length === 0) {
                            ToastService.showError("Enter an account name and profile directory");
                            return;
                        }
                        if (!directory.startsWith("/")) {
                            ToastService.showError("Profile directory must be an absolute path");
                            return;
                        }

                        let launcher = "antigravity";
                        if (launcherType.currentValue === "Antigravity IDE")
                            launcher = "antigravity-ide";
                        else if (launcherType.currentValue === "Codex in Antigravity IDE")
                            launcher = "codex-ide";
                        const updated = root.accounts.slice();
                        updated.push({ "name": name, "launcher": launcher, "profileDir": directory });
                        root.storeAccounts(updated);
                        accountName.text = "";
                        profileDirectory.text = "";
                        ToastService.showInfo("Account added: " + name);
                    }
                }
            }
        }

        StyledText {
            text: "Configured Accounts"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
        }

        Repeater {
            model: root.accounts

            StyledRect {
                required property int index
                required property var modelData

                width: editorColumn.width
                height: accountRow.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Row {
                    id: accountRow
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    HypeIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.launcher === "codex-ide" ? "smart_toy" : (modelData.launcher === "antigravity-ide" ? "developer_mode" : "account_circle")
                        size: Theme.iconSize
                        color: Theme.primary
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.iconSize - removeButton.width - Theme.spacingM * 2
                        spacing: Theme.spacingXS

                        StyledText {
                            width: parent.width
                            text: modelData.name
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: modelData.launcher + "  •  " + modelData.profileDir
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideMiddle
                        }
                    }

                    Rectangle {
                        id: removeButton
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: 18
                        color: removeArea.containsMouse ? Theme.errorHover : "transparent"

                        HypeIcon {
                            anchors.centerIn: parent
                            name: "delete"
                            size: 18
                            color: removeArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                        }

                        MouseArea {
                            id: removeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const removedName = modelData.name;
                                const updated = root.accounts.slice();
                                updated.splice(index, 1);
                                root.storeAccounts(updated);
                                ToastService.showInfo("Account removed: " + removedName);
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            visible: root.accounts.length === 0
            text: "No accounts configured"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
