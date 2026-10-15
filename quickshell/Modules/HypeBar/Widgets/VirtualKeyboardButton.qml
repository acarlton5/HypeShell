import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

BasePill {
    id: root

    property bool isActive: false
    signal toggleRequested

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.triggerRipple(this, mouse.x, mouse.y)
        onClicked: {
            root.toggleRequested();
            Quickshell.execDetached(["hype", "ipc", "call", "keyboard", "toggle"]);
        }
    }

    content: Component {
        Item {
            implicitWidth: icon.width
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            HypeIcon {
                id: icon
                anchors.centerIn: parent
                name: "keyboard"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: root.isActive ? (Theme.primary ? Theme.primary : "#ff6537") : Theme.widgetIconColor
            }
        }
    }
}
