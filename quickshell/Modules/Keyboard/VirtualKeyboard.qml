pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modules.Lock

PanelWindow {
    id: oskWindow

    property bool isVisible: false
    signal dismissed

    color: Theme.surfaceContainerHigh
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: isVisible ? implicitHeight : 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "hype-virtual-keyboard"

    anchors {
        left: true
        right: true
        bottom: true
    }

    implicitHeight: 280
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

    function handleKey(keyText) {
        if (keyText === "Enter" || keyText === "keyboard_return") {
            Quickshell.execDetached(["wtype", "-k", "Return"]);
        } else if (keyText === "Backspace" || keyText === "backspace" || keyText === "←") {
            Quickshell.execDetached(["wtype", "-k", "BackSpace"]);
        } else if (keyText === "keyboard_hide") {
            oskWindow.hide();
        } else if (keyText === " ") {
            Quickshell.execDetached(["wtype", "-k", "space"]);
        } else {
            Quickshell.execDetached(["wtype", keyText]);
        }
    }

    Keyboard {
        id: lockKeyboard
        anchors.fill: parent
        color: "transparent"

        onClicked: text => {
            if (text === strShift) {
                lockKeyboard.shift = !lockKeyboard.shift;
            } else if (text === '123') {
                lockKeyboard.symbols = true;
            } else if (text === 'ABC') {
                lockKeyboard.symbols = false;
            } else if (text === strClose) {
                oskWindow.hide();
            } else {
                let charToSend = text;
                if (text === strBackspace) {
                    charToSend = "Backspace";
                } else if (text === strEnter) {
                    charToSend = "Enter";
                } else if (lockKeyboard.symbols) {
                    charToSend = text;
                } else if (lockKeyboard.shift) {
                    charToSend = text.toUpperCase();
                }

                oskWindow.handleKey(charToSend);

                if (lockKeyboard.shift && text !== strShift) {
                    lockKeyboard.shift = false;
                }
            }
        }

        onDismissed: {
            oskWindow.hide();
        }
    }
}
