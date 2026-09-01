import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 45

    property var focusedScreen: MonitorsInfo.focused[0]
    property var brightnessMonitor: BrightnessService.getMonitorForScreen(focusedScreen)

    StyledProgressBar {
        id: brightnessSlider
        anchors.right: parent.right
        anchors.left: parent.left

        value: brightnessMonitor?.brightness ?? 0

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
                if (!root.brightnessMonitor)
                    return;
                const ratio = Math.max(0, Math.min(1, x / parent.width));
                root.brightnessMonitor.setBrightness(ratio);
            }
        }
    }

    Symbol {
        text: "routine"
        z: 0
        color: Colors.colOnPrimary
        fill: 1
        font.pixelSize: 18
        anchors.verticalCenter: brightnessSlider.verticalCenter
        anchors.left: brightnessSlider.left
        anchors.leftMargin: Padding.verylarge
    }
}
