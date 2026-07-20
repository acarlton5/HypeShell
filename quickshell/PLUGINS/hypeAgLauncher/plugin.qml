import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property var defaultAccounts: [
        { "name": "Primary Pro Account", "launcher": "antigravity", "profileDir": homeDir + "/DevBox/.gemini_primary" },
        { "name": "Secondary Pro Account", "launcher": "antigravity", "profileDir": homeDir + "/DevBox/.gemini_backup" },
        { "name": "Codex Main Window", "launcher": "codex-ide", "profileDir": homeDir + "/.local/share/codex-profiles/main" }
    ]
    readonly property var accounts: Array.isArray(pluginData.accounts) ? pluginData.accounts : defaultAccounts

    function launchAccount(account) {
        if (account.launcher === "codex-ide") {
            Quickshell.execDetached([
                "/usr/bin/env",
                "CODEX_HOME=" + account.profileDir,
                "/usr/bin/antigravity-ide",
                "--new-window",
                "--user-data-dir", account.profileDir + "/.antigravity-ide-ui",
                "--extensions-dir", homeDir + "/.antigravity-ide/extensions",
                "--enable-proposed-api", "openai.chatgpt",
                "--disable-extension", "google.antigravity"
            ]);
        } else {
            Quickshell.execDetached([account.launcher, "--user-data-dir=" + account.profileDir]);
        }
        ToastService.showInfo("Antigravity Launcher", "Launching " + account.name);
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            HypeIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "bolt"
                color: Theme.primary
                size: Theme.iconSize - 4
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "AG HUB"
                color: Theme.primary
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            HypeIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "bolt"
                color: Theme.primary
                size: Theme.iconSize - 4
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "AG"
                color: Theme.primary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: hubPopout

            headerText: "Antigravity Launcher"
            detailsText: accounts.length > 0 ? "Choose an account or workspace" : "Add an account in plugin settings"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: accounts

                    HypeButton {
                        required property var modelData

                        width: parent.width
                        text: modelData.name
                        iconName: modelData.launcher === "codex-ide" ? "smart_toy" : (modelData.launcher === "antigravity-ide" ? "developer_mode" : "account_circle")
                        onClicked: {
                            root.closePopout();
                            if (hubPopout.closePopout)
                                hubPopout.closePopout();
                            root.launchAccount(modelData);
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: accounts.length === 0
                    text: "No accounts configured"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeMedium
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    popoutWidth: 360
    popoutHeight: Math.max(150, 110 + accounts.length * 48)
}
