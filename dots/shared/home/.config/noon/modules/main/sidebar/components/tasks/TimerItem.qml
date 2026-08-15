import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

Rectangle {
    id: timerDock

    property int contentWidth: timerContent.implicitWidth + 36
    property bool extraVisibleCondition

    function requestOverlayMode() {
        Mem.options.desktop.timerOverlayMode = !Mem.options.desktop.timerOverlayMode;
    }

    
    visible: TimerService.timers.length >= 1 && extraVisibleCondition
    width: visible ? contentWidth : 0
    height: 55
    border.color: Colors.colOutline
    color: Colors.m3.m3secondaryContainer
    topLeftRadius: Rounding.verylarge
    topRightRadius: Rounding.verylarge
    bottomRightRadius: Rounding.verylarge
    bottomLeftRadius: Rounding.verylarge

    RowLayout {
        id: timerContent

        anchors.centerIn: parent

        Repeater {
            model: TimerService.timers

            delegate: RowLayout {
                spacing: 0

                Rectangle {
                    color: "transparent"
                    implicitWidth: timerLayout.implicitWidth
                    implicitHeight: timerLayout.implicitHeight

                    RowLayout {
                        id: timerLayout

                        spacing: 12

                        
                        Column {
                            spacing: 2
                            Layout.alignment: Qt.AlignLeft

                            
                            StyledText {
                                text: modelData.name
                                font: Fonts.request("main", Fonts.sizes.small, { weight: 500 })
                                color: Colors.m3.m3onSurface
                                opacity: 0.9
                            }

                            StyledText {
                                text: TimerService.formatTime(modelData.remainingTime)
                                font: Fonts.request("main", Fonts.sizes.small, { weight: Font.DemiBold })
                                color: Colors.colOnLayer0
                                opacity: 0.7
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        CircularProgress {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            lineWidth: 4
                            value: (modelData.originalDuration - modelData.remainingTime) / modelData.originalDuration
                            implicitSize: 40
                            colSecondary: Colors.m3.m3secondaryContainer
                            colPrimary: modelData.color || Colors.m3.m3secondary

                            Symbol {
                                anchors.centerIn: parent
                                fill: 1
                                text: (modelData.isRunning ? "pause" : "play_arrow") ?? "timer"
                                font.pixelSize: Fonts.sizes.large
                                color: Colors.m3.m3onSecondaryContainer
                            }

                            
                            Behavior on value {
                                Anim {}
                            }
                        }
                    }

                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                timerDock.requestOverlayMode();
                            } else if (mouse.button === Qt.MiddleButton) {
                                TimerService.removeTimer(modelData.id);
                            } else if (mouse.button === Qt.LeftButton) {
                                if (modelData.isRunning)
                                    TimerService.pauseTimer(modelData.id);
                                else if (modelData.isPaused)
                                    TimerService.startTimer(modelData.id);
                            }
                        }
                    }
                }

                
                Rectangle {
                    visible: index < TimerService.timers.length - 1
                    Layout.fillHeight: true
                    width: 1
                    color: Colors.colSubtext
                    opacity: 0.6
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                }
            }
        }
    }

    
    SequentialAnimation {
        running: {
            for (let i = 0; i < TimerService.timers.length; i++) {
                if (TimerService.timers[i].isRunning && TimerService.timers[i].remainingTime <= 10 && TimerService.timers[i].remainingTime > 0)
                    return true;
            }
            return false;
        }
        loops: Animation.Infinite

        Anim {
            target: timerDock
            property: "opacity"
            from: 1
            to: 0.6
        }

        Anim {
            target: timerDock
            property: "opacity"
            from: 0.6
            to: 1
        }
    }

    
    MouseArea {
        anchors.fill: parent
        z: -1 
        hoverEnabled: true
        onClicked: {
            timerDock.requestOverlayMode();
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: 300
        }
    }

    
    Behavior on width {
        Anim {}
    }
}
