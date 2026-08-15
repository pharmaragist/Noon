import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets

ColumnLayout {
    id: resourcesContainer

    
    required property double batteryPercentage
    required property double cpuPercentage
    required property double memoryPercentage
    required property double swapPercentage

    spacing: 6

    
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Symbol {
            Layout.alignment: Qt.AlignVCenter
            fill: 1
            text: "battery_full" 
            iconSize: Fonts.sizes.normal
            color: Colors.m3.m3onSecondaryContainer
        }

        Item {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            height: 4

            Rectangle {
                anchors.fill: parent
                color: Colors.m3.m3secondaryContainer
                radius: height / 2

                Rectangle {
                    height: parent.height
                    width: parent.width * batteryPercentage
                    color: Colors.m3.m3onSecondaryContainer
                    radius: height / 2

                    Behavior on width {
                        Anim {}
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            color: Colors.colOnLayer1
            text: `${Math.round(batteryPercentage * 100)}%`
            Layout.minimumWidth: 45
            horizontalAlignment: Text.AlignRight
        }
    }

    
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Symbol {
            Layout.alignment: Qt.AlignVCenter
            fill: 1
            text: "memory" 
            iconSize: Fonts.sizes.normal
            color: Colors.m3.m3onSecondaryContainer
        }

        Item {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            height: 4

            Rectangle {
                anchors.fill: parent
                color: Colors.m3.m3secondaryContainer
                radius: height / 2

                Rectangle {
                    height: parent.height
                    width: parent.width * cpuPercentage
                    color: Colors.m3.m3onSecondaryContainer
                    radius: height / 2

                    Behavior on width {
                        Anim {}
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            color: Colors.colOnLayer1
            text: `${Math.round(cpuPercentage * 100)}%`
            Layout.minimumWidth: 45
            horizontalAlignment: Text.AlignRight
        }
    }

    
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Symbol {
            Layout.alignment: Qt.AlignVCenter
            fill: 1
            text: "database" 
            iconSize: Fonts.sizes.normal
            color: Colors.m3.m3onSecondaryContainer
        }

        Item {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            height: 4

            Rectangle {
                anchors.fill: parent
                color: Colors.m3.m3secondaryContainer
                radius: height / 2

                Rectangle {
                    height: parent.height
                    width: parent.width * memoryPercentage
                    color: Colors.m3.m3onSecondaryContainer
                    radius: height / 2

                    Behavior on width {
                        Anim {}
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            color: Colors.colOnLayer1
            text: `${Math.round(memoryPercentage * 100)}%`
            Layout.minimumWidth: 45
            horizontalAlignment: Text.AlignRight
        }
    }

    
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Symbol {
            Layout.alignment: Qt.AlignVCenter
            fill: 1
            text: "swap_horiz" 
            iconSize: Fonts.sizes.normal
            color: Colors.m3.m3onSecondaryContainer
        }

        Item {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            height: 4

            Rectangle {
                anchors.fill: parent
                color: Colors.m3.m3secondaryContainer
                radius: height / 2

                Rectangle {
                    height: parent.height
                    width: parent.width * swapPercentage
                    color: Colors.m3.m3onSecondaryContainer
                    radius: height / 2

                    Behavior on width {
                        Anim {}
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            color: Colors.colOnLayer1
            text: `${Math.round(swapPercentage * 100)}%`
            Layout.minimumWidth: 45
            horizontalAlignment: Text.AlignRight
        }
    }
}
