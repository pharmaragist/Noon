import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

StyledRect {
    id: root
    property var timer

    clip: true
    color: timer.isRunning ? Colors.colPrimary : Colors.colLayer2
    radius: timer.isRunning ? Rounding.huge : Rounding.large

    Item {
        anchors.fill: parent
        anchors.margins: Padding.huge

        StyledText {
            id: bigNo
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Padding.huge
            color: timer.isRunning ? Colors.colOnPrimary : Colors.colOnLayer2
            font: Fonts.request("longNumbers", 220)
            text: TimerService.formatTime(timer.remainingTime).split(':')[0] || 0
        }

        StyledText {
            id: lilNo
            anchors.top: bigNo.top
            topPadding: Padding.massive

            anchors.left: bigNo.right
            leftPadding: Padding.massive

            color: timer.isRunning ? Colors.colOnPrimary : Colors.colOnLayer2
            font: Fonts.request("longNumbers", 124)
            text: TimerService.formatTime(timer.remainingTime).split(':')[1] || '0'
        }

        StyledSwitch {
            anchors.top: lilNo.bottom
            anchors.left: bigNo.right
            anchors.leftMargin: Padding.massive * 1.12

            checked: timer.isRunning
            onToggled: if (timer.isRunning) {
                TimerService.pauseTimer(timer.id);
            } else {
                TimerService.startTimer(timer.id);
            }
        }
    }
    StyledProgressBar {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left
        showProgressIndicator: false
        valueBarHeight: 3
        valueBarGap: 3
        value: root.timer.remainingTime / root.timer.originalDuration
    }
}
