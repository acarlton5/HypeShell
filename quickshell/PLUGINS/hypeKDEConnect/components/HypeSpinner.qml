import QtQuick

Item {
    id: root

    property int size: 24
    property color color: "white"

    width: size
    height: size

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.beginPath();
            context.strokeStyle = root.color;
            context.lineWidth = Math.max(2, root.size / 8);
            context.lineCap = "round";
            context.arc(width / 2, height / 2, Math.max(1, width / 2 - context.lineWidth), 0, Math.PI * 1.45);
            context.stroke();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    RotationAnimator on rotation {
        from: 0
        to: 360
        duration: 850
        loops: Animation.Infinite
        running: root.visible
    }

    onColorChanged: canvas.requestPaint()
}
