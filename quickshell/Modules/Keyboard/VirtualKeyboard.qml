import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

PanelWindow {
    id: oskWindow

    property bool isVisible: false
    property bool shift: false
    property bool symbols: false

    signal dismissed

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "hype-virtual-keyboard"

    anchors {
        left: true
        right: true
        bottom: true
    }

    implicitHeight: 290
    visible: isVisible

    function toggle() {
        isVisible = !isVisible;
    }

    function show() {
        isVisible = true;
    }

    function hide() {
        isVisible = false;
        dismissed();
    }

    function sendKey(keyText) {
        if (keyText === "Enter") {
            Quickshell.execDetached(["wtype", "-k", "Return"]);
        } else if (keyText === "Backspace") {
            Quickshell.execDetached(["wtype", "-k", "BackSpace"]);
        } else if (keyText === "Space") {
            Quickshell.execDetached(["wtype", "-k", "space"]);
        } else if (keyText === "Tab") {
            Quickshell.execDetached(["wtype", "-k", "Tab"]);
        } else if (keyText === "Escape") {
            Quickshell.execDetached(["wtype", "-k", "Escape"]);
        } else if (keyText === "Left") {
            Quickshell.execDetached(["wtype", "-k", "Left"]);
        } else if (keyText === "Right") {
            Quickshell.execDetached(["wtype", "-k", "Right"]);
        } else if (keyText === "Up") {
            Quickshell.execDetached(["wtype", "-k", "Up"]);
        } else if (keyText === "Down") {
            Quickshell.execDetached(["wtype", "-k", "Down"]);
        } else {
            Quickshell.execDetached(["wtype", keyText]);
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Theme.surfaceContainerHighest ? Theme.surfaceContainerHighest : "#1a222d"
        border.color: Theme.outline ? Theme.outline : "#3a4654"
        border.width: 1

        Rectangle {
            id: topHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 38
            color: Theme.surfaceContainer ? Theme.surfaceContainer : "#141c24"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                HypeIcon {
                    name: "keyboard"
                    size: 18
                    color: Theme.primary ? Theme.primary : "#ff6537"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "VIRTUAL KEYBOARD"
                    color: Theme.primary ? Theme.primary : "#ff6537"
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 1.2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                height: 26
                radius: 4
                color: Theme.error ? Theme.error : "#ff3b30"

                Text {
                    anchors.centerIn: parent
                    text: "CLOSE"
                    color: "white"
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: oskWindow.hide()
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: topHeader.bottom
            anchors.margins: 6
            spacing: 5

            // Row 1: Numbers & Symbols
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: oskWindow.symbols ? ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"] : ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
                    delegate: Rectangle {
                        width: (oskWindow.width - 70) / 10
                        height: 48
                        radius: 6
                        color: Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38"
                        border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.surfaceText ? Theme.surfaceText : "#f5f5f2"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: oskWindow.sendKey(modelData)
                        }
                    }
                }
            }

            // Row 2: QWERTY
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: oskWindow.symbols ? ["~", "`", "-", "_", "=", "+", "[", "]", "{", "}"] : ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
                    delegate: Rectangle {
                        width: (oskWindow.width - 70) / 10
                        height: 48
                        radius: 6
                        color: Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38"
                        border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                        Text {
                            anchors.centerIn: parent
                            text: oskWindow.symbols ? modelData : (oskWindow.shift ? modelData.toUpperCase() : modelData)
                            color: Theme.surfaceText ? Theme.surfaceText : "#f5f5f2"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                let ch = oskWindow.symbols ? modelData : (oskWindow.shift ? modelData.toUpperCase() : modelData);
                                oskWindow.sendKey(ch);
                                if (oskWindow.shift) oskWindow.shift = false;
                            }
                        }
                    }
                }
            }

            // Row 3: ASDFGHJKL + Backspace
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: oskWindow.symbols ? ["\\", "|", ";", ":", "'", "\"", "<", ">", "?"] : ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
                    delegate: Rectangle {
                        width: (oskWindow.width - 90) / 10.5
                        height: 48
                        radius: 6
                        color: Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38"
                        border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                        Text {
                            anchors.centerIn: parent
                            text: oskWindow.symbols ? modelData : (oskWindow.shift ? modelData.toUpperCase() : modelData)
                            color: Theme.surfaceText ? Theme.surfaceText : "#f5f5f2"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                let ch = oskWindow.symbols ? modelData : (oskWindow.shift ? modelData.toUpperCase() : modelData);
                                oskWindow.sendKey(ch);
                                if (oskWindow.shift) oskWindow.shift = false;
                            }
                        }
                    }
                }

                Rectangle {
                    width: ((oskWindow.width - 90) / 10.5) * 1.5
                    height: 48
                    radius: 6
                    color: Theme.primary ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : "#2a3644"
                    border.color: Theme.primary ? Theme.primary : "#ff6537"
                    Text {
                        anchors.centerIn: parent
                        text: "⌫"
                        color: Theme.primary ? Theme.primary : "#ff6537"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: oskWindow.sendKey("Backspace")
                    }
                }
            }

            // Row 4: Shift, ZXCVBNM, Enter
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                Rectangle {
                    width: ((oskWindow.width - 110) / 11) * 1.3
                    height: 48
                    radius: 6
                    color: oskWindow.shift ? (Theme.primary ? Theme.primary : "#ff6537") : (Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38")
                    border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                    Text {
                        anchors.centerIn: parent
                        text: "⇧"
                        color: oskWindow.shift ? "black" : (Theme.surfaceText ? Theme.surfaceText : "#f5f5f2")
                        font.pixelSize: 20
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: oskWindow.shift = !oskWindow.shift
                    }
                }

                Repeater {
                    model: ["z", "x", "c", "v", "b", "n", "m", ",", "."]
                    delegate: Rectangle {
                        width: (oskWindow.width - 110) / 11
                        height: 48
                        radius: 6
                        color: Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38"
                        border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                        Text {
                            anchors.centerIn: parent
                            text: oskWindow.shift ? modelData.toUpperCase() : modelData
                            color: Theme.surfaceText ? Theme.surfaceText : "#f5f5f2"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                let ch = oskWindow.shift ? modelData.toUpperCase() : modelData;
                                oskWindow.sendKey(ch);
                                if (oskWindow.shift) oskWindow.shift = false;
                            }
                        }
                    }
                }

                Rectangle {
                    width: ((oskWindow.width - 110) / 11) * 1.5
                    height: 48
                    radius: 6
                    color: Theme.primary ? Theme.primary : "#ff6537"
                    Text {
                        anchors.centerIn: parent
                        text: "↵"
                        color: "black"
                        font.pixelSize: 22
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: oskWindow.sendKey("Enter")
                    }
                }
            }

            // Row 5: Symbols, Tab, Space, Esc, Arrow Keys
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                Rectangle {
                    width: 72
                    height: 48
                    radius: 6
                    color: oskWindow.symbols ? (Theme.primary ? Theme.primary : "#ff6537") : (Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38")
                    border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                    Text {
                        anchors.centerIn: parent
                        text: oskWindow.symbols ? "ABC" : "?123"
                        color: oskWindow.symbols ? "black" : (Theme.surfaceText ? Theme.surfaceText : "#f5f5f2")
                        font.pixelSize: 15
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: oskWindow.symbols = !oskWindow.symbols
                    }
                }

                Rectangle {
                    width: 58
                    height: 48
                    radius: 6
                    color: Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38"
                    border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                    Text {
                        anchors.centerIn: parent
                        text: "Tab"
                        color: Theme.surfaceText ? Theme.surfaceText : "#f5f5f2"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: oskWindow.sendKey("Tab")
                    }
                }

                Rectangle {
                    width: oskWindow.width - 340
                    height: 48
                    radius: 6
                    color: Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38"
                    border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                    Text {
                        anchors.centerIn: parent
                        text: "SPACE"
                        color: Theme.surfaceText ? Theme.surfaceText : "#f5f5f2"
                        font.pixelSize: 14
                        font.letterSpacing: 2
                        opacity: 0.6
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: oskWindow.sendKey("Space")
                    }
                }

                Rectangle {
                    width: 50
                    height: 48
                    radius: 6
                    color: Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38"
                    border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                    Text {
                        anchors.centerIn: parent
                        text: "◀"
                        color: Theme.surfaceText ? Theme.surfaceText : "#f5f5f2"
                        font.pixelSize: 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: oskWindow.sendKey("Left")
                    }
                }

                Rectangle {
                    width: 50
                    height: 48
                    radius: 6
                    color: Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38"
                    border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                    Text {
                        anchors.centerIn: parent
                        text: "▶"
                        color: Theme.surfaceText ? Theme.surfaceText : "#f5f5f2"
                        font.pixelSize: 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: oskWindow.sendKey("Right")
                    }
                }

                Rectangle {
                    width: 58
                    height: 48
                    radius: 6
                    color: Theme.surfaceContainerLow ? Theme.surfaceContainerLow : "#222c38"
                    border.color: Theme.outlineVariant ? Theme.outlineVariant : "#384756"
                    Text {
                        anchors.centerIn: parent
                        text: "Esc"
                        color: Theme.surfaceText ? Theme.surfaceText : "#f5f5f2"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: oskWindow.sendKey("Escape")
                    }
                }
            }
        }
    }
}
