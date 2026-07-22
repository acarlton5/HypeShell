import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string phase: "idle"
    property string detail: "Ready to listen"
    property string lastTranscript: ""
    readonly property string scriptPath: Qt.resolvedUrl("scripts/voice-input").toString().replace("file://", "")
    readonly property string modelPath: pluginData.modelPath || ""
    readonly property string language: pluginData.language || "en"
    readonly property bool autoInsert: pluginData.autoInsert !== false
    readonly property bool active: phase === "listening" || phase === "transcribing"

    function runAction(action) {
        if (actionProcess.running)
            return;
        phase = action === "start" ? "starting" : "transcribing";
        detail = action === "start" ? "Opening microphone…" : "Turning speech into text…";
        actionProcess.command = [scriptPath, action, modelPath, language, autoInsert ? "1" : "0"];
        actionProcess.running = true;
    }

    function toggleRecording() {
        if (phase === "listening") {
            closePopout();
            stopDelay.restart();
            return;
        }
        runAction("start");
    }

    Timer {
        id: stopDelay
        interval: 350
        repeat: false
        onTriggered: root.runAction("stop")
    }

    Process {
        id: actionProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (!output)
                    return;
                const lines = output.split("\n");
                const status = lines.shift();
                if (status === "LISTENING") {
                    root.phase = "listening";
                    root.detail = "Listening… tap again when finished";
                } else if (status === "TRANSCRIPT") {
                    root.phase = "done";
                    root.lastTranscript = lines.join("\n").trim();
                    root.detail = root.autoInsert ? "Inserted into the focused field" : "Transcription copied to clipboard";
                } else if (status === "CANCELLED") {
                    root.phase = "idle";
                    root.detail = "Recording cancelled";
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const errorText = text.trim();
                if (!errorText)
                    return;
                root.phase = "error";
                root.detail = errorText.split("\n").pop();
                ToastService.showError("Voice Input", root.detail);
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 && root.phase !== "error") {
                root.phase = "error";
                root.detail = "Voice input failed (exit " + exitCode + ")";
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            HypeIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.active ? "graphic_eq" : "mic"
                color: root.active ? Theme.error : Theme.primary
                size: Theme.iconSize - 3
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.phase === "listening" ? "LISTENING" : "VOICE"
                color: root.active ? Theme.error : Theme.primary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
            }
        }
    }

    verticalBarPill: Component {
        HypeIcon {
            name: root.active ? "graphic_eq" : "mic"
            color: root.active ? Theme.error : Theme.primary
            size: Theme.iconSize
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "Voice Input"
            detailsText: root.detail
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingL

                Item {
                    width: parent.width
                    height: 150

                    Rectangle {
                        id: voiceOrb
                        anchors.centerIn: parent
                        width: 108
                        height: 108
                        radius: width / 2
                        color: root.phase === "error" ? Theme.errorContainer : Theme.primaryContainer
                        border.width: 2
                        border.color: root.phase === "listening" ? Theme.error : Theme.primary

                        SequentialAnimation on scale {
                            running: root.phase === "listening"
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.10; duration: 650; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.96; duration: 650; easing.type: Easing.InOutSine }
                        }

                        HypeIcon {
                            anchors.centerIn: parent
                            name: root.phase === "transcribing" ? "progress_activity" : (root.phase === "done" ? "check" : "mic")
                            size: 44
                            color: root.phase === "error" ? Theme.error : Theme.primary
                            rotation: 0
                            RotationAnimation on rotation {
                                running: root.phase === "transcribing"
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        spacing: 5
                        visible: root.phase === "listening"
                        Repeater {
                            model: 7
                            Rectangle {
                                required property int index
                                width: 4
                                height: 8 + ((index * 11) % 22)
                                radius: 2
                                color: Theme.primary
                                SequentialAnimation on opacity {
                                    running: root.phase === "listening"
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: index * 45 }
                                    NumberAnimation { to: 0.35; duration: 250 }
                                    NumberAnimation { to: 1.0; duration: 250 }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: root.lastTranscript !== ""
                    text: root.lastTranscript
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

                HypeButton {
                    width: parent.width
                    enabled: root.phase !== "starting" && root.phase !== "transcribing"
                    text: root.phase === "listening" ? "Stop and transcribe" : "Start listening"
                    iconName: root.phase === "listening" ? "stop_circle" : "mic"
                    backgroundColor: root.phase === "listening" ? Theme.error : Theme.primary
                    textColor: root.phase === "listening" ? Theme.errorText : Theme.primaryText
                    onClicked: root.toggleRecording()
                }

                HypeButton {
                    width: parent.width
                    visible: root.phase === "listening"
                    text: "Cancel"
                    iconName: "close"
                    onClicked: root.runAction("cancel")
                }
            }
        }
    }

    popoutWidth: 390
    popoutHeight: 390
}
