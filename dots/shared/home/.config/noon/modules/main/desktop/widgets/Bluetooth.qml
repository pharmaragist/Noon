import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets

WidgetContainer {
    id: root

    readonly property var currentDevice: BluetoothService.filterConnectedDevices(BluetoothService.pairedDevices)[0]
    readonly property int connectedCount: BluetoothService.connectedDevices.length

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: BluetoothService.togglePower()
    }

    small: Item {
        anchors.fill: parent
        MaterialShapeWrappedSymbol {
            anchors.centerIn: parent
            shape: MaterialShape.Shape.Pentagon
            color: BluetoothService.enabled ? Colors.colPrimaryContainer : Colors.colSurfaceContainerHigh
            colSymbol: BluetoothService.enabled ? Colors.colOnPrimaryContainer : Colors.colOnSurfaceVariant
            text: BluetoothService.enabled ? (root.connectedCount > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled"
            iconSize: Fonts.sizes.verylarge
            fill: 1
            padding: Padding.normal
            implicitSize: Fonts.sizes.verylarge + Padding.massive
        }
    }

    normal: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive
        spacing: Padding.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Padding.normal

            MaterialShapeWrappedSymbol {
                shape: MaterialShape.Shape.Pentagon
                color: BluetoothService.enabled ? Colors.colPrimaryContainer : Colors.colSurfaceContainerHigh
                colSymbol: BluetoothService.enabled ? Colors.colOnPrimaryContainer : Colors.colOnSurfaceVariant
                text: BluetoothService.enabled ? (root.connectedCount > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled"
                iconSize: Fonts.sizes.verylarge
                fill: 1
                padding: Padding.normal
                implicitSize: Fonts.sizes.verylarge + Padding.massive
                Layout.alignment: Qt.AlignVCenter
            }

            Spacer {}
        }

        Spacer {}

        RowLayout {
            Layout.fillWidth: true
            spacing: Padding.normal

            Symbol {
                text: BluetoothService.getDeviceIcon(root.currentDevice)
                color: Colors.colPrimary
                fill: 1
                iconSize: Fonts.sizes.large
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                Layout.fillWidth: true
                text: root.currentDevice?.name || (BluetoothService.enabled ? "No Device Connected" : "Bluetooth Off")
                color: Colors.colOnLayer0
                font: Fonts.request("main", "small", {
                    weight: Font.Medium
                })
                truncate: true
            }
        }
    }

    large: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive
        spacing: Padding.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Padding.normal

            MaterialShapeWrappedSymbol {
                shape: MaterialShape.Shape.Pentagon
                color: BluetoothService.enabled ? Colors.colPrimaryContainer : Colors.colSurfaceContainerHigh
                colSymbol: BluetoothService.enabled ? Colors.colOnPrimaryContainer : Colors.colOnSurfaceVariant
                text: BluetoothService.enabled ? (root.connectedCount > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled"
                iconSize: Fonts.sizes.verylarge
                fill: 1
                padding: Padding.normal
                implicitSize: Fonts.sizes.verylarge + Padding.massive
                Layout.alignment: Qt.AlignVCenter
            }

            Spacer {}

            StyledText {
                text: BluetoothService.enabled ? (root.connectedCount > 0 ? `${root.connectedCount} connected` : "Discovering…") : "Disabled"
                color: BluetoothService.enabled ? Colors.colPrimary : Colors.colOnSurfaceVariant
                font: Fonts.request("main", "verysmall", {
                    weight: Font.Medium
                })
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Spacer {}

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Padding.verysmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Padding.normal

                Symbol {
                    text: BluetoothService.getDeviceIcon(root.currentDevice)
                    color: Colors.colPrimary
                    fill: 1
                    iconSize: Fonts.sizes.large
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: root.currentDevice?.name || (BluetoothService.enabled ? "No Device Connected" : "Bluetooth Off")
                        color: Colors.colOnLayer0
                        font: Fonts.request("main", "small", {
                            weight: Font.Medium
                        })
                        truncate: true
                    }

                    StyledText {
                        text: root.currentDevice ? BluetoothService.getDeviceStatus(root.currentDevice) : "Click to toggle"
                        color: Colors.colOnSurfaceVariant
                        font: Fonts.request("main", "verysmall")
                    }
                }
            }

            ClippedProgressBar {
                Layout.fillWidth: true
                visible: root.currentDevice?.battery !== undefined
                value: root.currentDevice?.battery ?? 0
                valueBarHeight: 4
                showEndPoint: false
                highlightColor: Colors.colSecondary
                trackColor: Colors.colSurfaceContainerHigh
            }
        }
    }

    xlarge: large
}
