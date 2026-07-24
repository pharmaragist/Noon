import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root
    visible: Mem.options.sidebar.appearance.showVolumeInputSlider ?? false
    Layout.fillWidth: true
    Layout.preferredHeight: 45

    property var source: AudioService.source

    Symbol {
        z: 2
        text: volumeSlider.value <= 0.01 ? "mic_off" : "mic"
        animateChange: true
        fill: 1
        color: Colors.m3.m3onPrimary
        font.pixelSize: 18
        anchors.verticalCenter: volumeSlider.verticalCenter
        anchors.left: volumeSlider.left
        anchors.leftMargin: Padding.verylarge
    }

    StyledProgressBar {
        id: volumeSlider
        anchors.right: parent.right
        anchors.left: parent.left

        value: source?.audio?.volume ?? 0

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
                if (!root.source?.audio)
                    return;
                const ratio = Math.max(0, Math.min(1, x / parent.width));
                root.source.audio.volume = ratio;
            }
        }
    }
}
