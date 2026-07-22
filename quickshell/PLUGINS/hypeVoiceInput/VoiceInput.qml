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

    component VoiceStateIcon: Item {
        implicitWidth: Theme.iconSize + 2
        implicitHeight: Theme.iconSize + 2

        HypeIcon {
            anchors.centerIn: parent
            visible: root.phase !== "transcribing"
            name: root.phase === "listening" ? "stop_circle" : "mic"
            color: root.phase === "listening" ? Theme.error : Theme.primary
            size: Theme.iconSize

            SequentialAnimation on scale {
                running: root.phase === "listening"
                loops: Animation.Infinite
                NumberAnimation { to: 1.14; duration: 420; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.92; duration: 420; easing.type: Easing.InOutSine }
            }
        }

        Row {
            anchors.centerIn: parent
            visible: root.phase === "transcribing"
            spacing: 2

            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 6 + index * 2
                    radius: 2
                    color: Theme.primary

                    SequentialAnimation on height {
                        running: root.phase === "transcribing"
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 55 }
                        NumberAnimation { to: 18 - index * 2; duration: 190; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 5 + index * 2; duration: 190; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

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

    pillClickAction: function() {
        if (phase === "listening") {
            toggleRecording();
            return;
        }
        if (phase === "transcribing" || phase === "starting")
            return;
        togglePopout();
    }

    Timer {
        id: stopDelay
        interval: 100
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
        VoiceStateIcon {}
    }

    verticalBarPill: Component {
        VoiceStateIcon {}
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

                    Item {
                        id: voiceOrb
                        anchors.centerIn: parent
                        width: 126
                        height: 126
                        property real motionPhase: 0

                        SequentialAnimation on scale {
                            running: root.phase === "listening"
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.045; duration: 720; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.985; duration: 720; easing.type: Easing.InOutSine }
                        }

                        Canvas {
                            id: orbCanvas
                            anchors.fill: parent
                            antialiasing: true

                            onPaint: {
                                const ctx = getContext("2d");
                                const w = width;
                                const h = height;
                                const cx = w / 2;
                                const cy = h / 2;
                                const radius = Math.min(w, h) * 0.47;
                                ctx.clearRect(0, 0, w, h);
                                ctx.save();
                                ctx.beginPath();
                                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                                ctx.clip();

                                const base = ctx.createRadialGradient(cx - 18, cy - 24, 4, cx, cy, radius);
                                base.addColorStop(0, "#e8fbff");
                                base.addColorStop(0.24, "#74ddff");
                                base.addColorStop(0.62, "#3578e5");
                                base.addColorStop(1, "#101d58");
                                ctx.fillStyle = base;
                                ctx.fillRect(0, 0, w, h);

                                ctx.globalCompositeOperation = "screen";
                                const colors = ["rgba(255,255,255,0.82)", "rgba(75,239,255,0.72)", "rgba(118,99,255,0.65)"];
                                for (let i = 0; i < 3; i++) {
                                    const angle = voiceOrb.motionPhase * (0.7 + i * 0.18) + i * 2.1;
                                    const bx = cx + Math.cos(angle) * (20 + i * 5);
                                    const by = cy + Math.sin(angle * 1.17) * (17 + i * 4);
                                    const blob = ctx.createRadialGradient(bx, by, 1, bx, by, 43 - i * 5);
                                    blob.addColorStop(0, colors[i]);
                                    blob.addColorStop(1, "rgba(0,0,0,0)");
                                    ctx.fillStyle = blob;
                                    ctx.fillRect(0, 0, w, h);
                                }
                                ctx.restore();

                                ctx.beginPath();
                                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                                ctx.lineWidth = 2;
                                ctx.strokeStyle = root.phase === "error" ? "#ff6b7a" : "rgba(190,245,255,0.75)";
                                ctx.stroke();
                            }
                        }

                        Timer {
                            interval: 33
                            repeat: true
                            running: root.phase === "listening" || root.phase === "transcribing"
                            onTriggered: {
                                voiceOrb.motionPhase += root.phase === "transcribing" ? 0.075 : 0.045;
                                orbCanvas.requestPaint();
                            }
                        }

                        Connections {
                            target: root
                            function onPhaseChanged() { orbCanvas.requestPaint(); }
                        }

                        HypeIcon {
                            anchors.centerIn: parent
                            name: root.phase === "done" ? "check" : (root.phase === "error" ? "error" : "mic")
                            size: 32
                            color: "#f5fdff"
                            opacity: 0.92
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.phase !== "transcribing" && root.phase !== "starting"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleRecording()
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
