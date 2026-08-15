import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 45

    property var sink: AudioService.sink
    property real maxValue: 1.5

    Symbol {
        z: 2
        text: volumeSlider.value <= 0.01 ? "volume_off" : "volume_up"
        color: Colors.colOnPrimary
        font.pixelSize: 18
        fill: 1
        anchors.verticalCenter: volumeSlider.verticalCenter
        anchors.left: volumeSlider.left
        anchors.leftMargin: Padding.verylarge
        animateChange: true
    }

    StyledProgressBar {
        id: volumeSlider
        z: 1
        

        anchors.right: parent.right
        anchors.left: parent.left

        value: (sink?.audio?.volume ?? 0) / maxValue

        highlightHeight: 36
        showDot: true
        valueBarHeight: 12
        valueBarGap: 10
        wavelength: 40

        MouseArea {
            z: 99
            anchors.fill: parent
            hoverEnabled: true

            property bool isDragging: false

            onPressed: mouse => {
                isDragging = true;
                seekTo(mouse.x);
            }

            onPositionChanged: mouse => {
                if (isDragging)
                    seekTo(mouse.x);
            }

            onReleased: isDragging = false

            function seekTo(x) {
                if (!root.sink?.audio)
                    return;
                const ratio = Math.max(0, Math.min(1, x / parent.width));
                root.sink.audio.volume = ratio * root.maxValue;
            }
        }
    }

}
