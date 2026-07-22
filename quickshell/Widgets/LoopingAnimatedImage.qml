import QtQuick

AnimatedImage {
    id: root

    property bool restartPending: false

    playing: source !== ""

    onCurrentFrameChanged: {
        if (restartPending || frameCount <= 1 || currentFrame < frameCount - 1)
            return;

        restartPending = true;
        const animationSource = source;
        Qt.callLater(() => {
            root.source = "";
            Qt.callLater(() => {
                root.source = animationSource;
                root.playing = true;
                root.restartPending = false;
            });
        });
    }
}
