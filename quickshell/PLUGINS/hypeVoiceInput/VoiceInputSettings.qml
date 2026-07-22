import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "hypeVoiceInput"

    Column {
        width: parent.width
        spacing: Theme.spacingL

        StyledText {
            text: "Local Voice Input"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
        }

        StyledText {
            width: parent.width
            text: "Audio is transcribed locally with whisper.cpp and never leaves this computer."
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        HypeTextField {
            width: parent.width
            placeholderText: "/path/to/ggml-base.en.bin"
            text: loadValue("modelPath", "")
            onEditingFinished: saveValue("modelPath", text.trim())
        }

        HypeTextField {
            width: parent.width
            placeholderText: "Language code (en, es, de…)"
            text: loadValue("language", "en")
            onEditingFinished: saveValue("language", text.trim() || "en")
        }

        HypeToggle {
            text: "Type into focused field"
            description: "When disabled, the transcript is copied to the clipboard only."
            checked: loadValue("autoInsert", true)
            onToggled: checked => saveValue("autoInsert", checked)
        }

        StyledRect {
            width: parent.width
            height: dependencyText.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh
            StyledText {
                id: dependencyText
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                text: "Required commands: pw-record, whisper-cli, and wtype (or wl-copy + hyprctl)."
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }
    }
}
