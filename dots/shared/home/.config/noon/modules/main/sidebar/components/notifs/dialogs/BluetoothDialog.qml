import qs.services
import qs.common
import qs.common.widgets
import qs.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

BottomDialog {
    id: root

    baseHeight: parent.height * 0.65

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.huge
        spacing: Padding.large

        PageHeader {
            title: qsTr("Bluetooth devices")
            subTitle: qsTr("Configure Connected Devices")
        }

        StyledIndeterminateProgressBar {
            id: loading
            visible: BluetoothService.discovering
            Layout.fillWidth: true
        }
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
            visible: !BluetoothService.enabled

            MaterialShapeWrappedSymbol {
                id: shape
                anchors.centerIn: parent
                text: "bluetooth_disabled"
                iconSize: 100
            }
            RowLayout {
                width: 110
                anchors.top: shape.bottom
                anchors.horizontalCenter: shape.horizontalCenter
                anchors.margins: Padding.massive
                Layout.preferredHeight: 45
                StyledText {
                    text: BluetoothService.enabled ? "Enabled" : "Disabled"
                    font: Fonts.request("title", "normal")
                    color: BluetoothService.enabled ? Colors.colOnLayer3 : Colors.colSubtext
                    Layout.fillWidth: true
                }
                StyledSwitch {
                    checked: BluetoothService.enabled
                    onToggled: BluetoothService.togglePower()
                }
            }
        }

        StyledListView {
            id: listView
            visible: BluetoothService.enabled
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.margins: Padding.large
            clip: true
            spacing: 2

            model: ScriptModel {
                values: BluetoothService.allDevices.filter(d => {
                    return d && d.name && d.name.trim();
                }).sort((a, b) => {

                    let conn = (b.connected - a.connected) || (b.paired - a.paired);
                    if (conn !== 0)
                        return conn;


                    const macRegex = /^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$/;
                    const aIsMac = macRegex.test(a.name);
                    const bIsMac = macRegex.test(b.name);
                    if (aIsMac !== bIsMac)
                        return aIsMac ? 1 : -1;


                    return a.name.localeCompare(b.name);
                })
            }

            delegate: BluetoothDeviceItem {
                required property var modelData
                required property int index
                device: modelData
                list: listView

                anchors.left: parent?.left
                anchors.right: parent?.right
            }
        }

        RowLayout {

            Layout.preferredHeight: 50
            Layout.fillWidth: true
            spacing: Padding.tiny

            StyledSwitch {
                checked: BluetoothService.adapter.discoverable
                onClicked: BluetoothService.adapter.discoverable = checked
                Layout.leftMargin: Padding.huge
            }

            StyledText {
                text: "Visible"
                color: Colors.colOnLayer0
                Layout.fillWidth: true
                leftPadding: Padding.large
            }

            DialogButton {
                buttonText: qsTr("Details")
                onClicked: {
                    root.show = false;
                    NoonUtils.execDetached(Mem.options.apps.bluetooth);
                    Ipc.call(["sidebar", "hide"]);
                }
            }

            DialogButton {
                buttonText: qsTr("Discover")
                onClicked: BluetoothService.startDiscovery()
            }

            DialogButton {
                buttonText: qsTr("Done")
                onClicked: root.show = false
            }
        }
    }
}
