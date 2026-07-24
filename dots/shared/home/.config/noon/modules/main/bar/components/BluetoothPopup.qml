import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

StyledPopup {
    id: root

    property var currentDevice: BluetoothService.filterConnectedDevices(BluetoothService.pairedDevices)[0]
    // extraVisibilityCondition: BluetoothService.filterConnectedDevices(BluetoothService.pairedDevices).length > 0
    contentMargins: 0
    contentItem: StyledRect {
        id: bg
        clip: true
        implicitHeight: 120
        implicitWidth: 300
        radius: Rounding.verylarge
        color: Colors.colLayer0
        readonly property real bPercentage: root.currentDevice?.battery ? root.currentDevice?.battery : 1
        readonly property string dName: root.currentDevice?.name || "No Current Device"
        readonly property string mIcon: BluetoothService.filterConnectedDevices(BluetoothService.pairedDevices).length > 0 ? BluetoothService.getDeviceIcon(root.currentDevice) : "bluetooth"

        Item {
            z: 999
            width: shape.implicitSize
            height: shape.implicitSize
            anchors.bottom: progressArea.bottom
            anchors.right: progressArea.left
            anchors.bottomMargin: Padding.tiny
            anchors.rightMargin: -25

            Symbol {
                z: 1
                anchors.centerIn: shape
                icon: bg.mIcon
                iconSize: 25
                color: Colors.colOnPrimary
            }

            // MaterialShape {
            //     z: shape.z + 1
            //     color: Colors.colSecondaryContainer
            //     _shape: "Oval"
            //     anchors.top: shape.top
            //     anchors.left: shape.right
            //     anchors.leftMargin: -15
            //     implicitSize: 34
            //     StyledText {
            //         color: Colors.colOnSecondaryContainer
            //         font: Fonts.request("numbers", 14)
            //         anchors.centerIn: parent
            //         text: root.currentDevice?.battery ? Math.round(root.currentDevice.battery * 100) : 100
            //     }
            // }

            MaterialShape {
                id: shape
                implicitSize: 54
                _shape: "Cookie9Sided"
                rotation: -15
                anchors.centerIn: parent
                color: Colors.colPrimary

                RotationAnimation on rotation {
                    running: true
                    duration: 12000
                    easing.type: Easing.Linear
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                }
            }
        }
        StyledRect {
            id: progressArea
            anchors.margins: Padding.small
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Colors.colLayer2
            radius: Rounding.large
            clip: true
            width: 100

            StyledText {
                z: 99999
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: Padding.normal
                color: this.contentHeight >= progress.implicitHeight ? Colors.colOnPrimary : Colors.colOnLayer0
                text: root.currentDevice?.battery ? Math.round(root.currentDevice.battery * 100) : 100
                font: Fonts.request("numbers", 28)
            }

            StyledRect {
                id: progress
                z: 999
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.left: parent.left
                implicitHeight: bg.bPercentage * parent.height
                topRadius: Rounding.small
            }
        }
        ColumnLayout {
            anchors.margins: Padding.large
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: bg.width - 100

            RowLayout {
                spacing: 4
                Layout.fillWidth: true

                Symbol {
                    icon: BluetoothService.getDeviceStatusIcon(root.currentDevice) || "bluetooth"
                    color: Colors.m3.m3onSurfaceVariant
                    font.pixelSize: Fonts.sizes.large
                }

                StyledText {
                    text: BluetoothService.getDeviceStatus(root.currentDevice).trim().length > 0 ? BluetoothService.getDeviceStatus(root.currentDevice) : "No Current Status"
                    color: Colors.m3.m3onSurfaceVariant
                    font: Fonts.request("title", "small")
                }
            }

            StyledText {
                text: root.currentDevice?.name.trim() || " -_-"
                font: Fonts.request("title", Math.max(Fonts.sizes.large, Fonts.sizes.huge - this.text.length))
            }
        }
    }
}
