import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

BarGroup {
    id: root
    readonly property bool useBothWhenAvailable: Mem.options.bar.statusIcons.showTextWhenAvailable
    readonly property Component batteryPopup: BatteryPopup {}
    readonly property Component bluetoothPopup: BluetoothPopup {}
    readonly property Component networkPopup: NetworkPopup {}
    readonly property Component tooltipComp: StyledToolTip {
        property var hoverTarget
        extraVisibleCondition: hoverTarget.containsMouse
    }

    function getItemPropById(id, prop) {
        const item = content.find(i => i.id === id);
        if (!!item[prop])
            return item[prop];
    }

    readonly property var content: [
        {
            id: "record",
            icon: "radio_button_checked",
            visible: RecordingService.isRecording,
            dialog: "Record",
            tooltip: "Recording"
        },
        {
            id: "mute",
            icon: "volume_off",
            visible: AudioService.sink?.audio.muted
        },
        {
            id: "battery",
            visible: BatteryService.available,
            icon: BatteryService.materialIcon,
            mode: Mem.options.bar.statusIcons.batteryMode,
            text: () => {
                const base = Math.round(BatteryService.percentage * 100);
                const charge = (root.getItemPropById("battery", "mode") !== "both" && BatteryService.isPluggedIn) ? "*" : "";
                return base + charge;
            },
            hoverItem: batteryPopup
        },
        {
            id: "silent",
            icon: "notifications_off",
            visible: Notifications.silent
        },
        {
            id: "polkit",
            icon: "shield",
            visible: PolkitService.interactionAvailable,
            action: () => Ipc.call(["sidebar", "reveal", "Auth"]),
            tooltip: PolkitService?.flow?.message
        },
        {
            id: "overheat",
            visible: ResourcesService.stats.cpu_temp > 85,
            text: ResourcesService.stats.cpu_temp + "°",
            icon: "mode_heat",
            mode: "both"
        },
        {
            id: "bluetooth",
            dialog: "Bluetooth",
            visible: BluetoothService?.connectedDevices?.length > 0,
            icon: BluetoothService.currentDeviceIcon,
            text: () => {
                if (!BluetoothService.connectedDevices.length > 0)
                    return;
                const device = BluetoothService.filterConnectedDevices(BluetoothService.pairedDevices)[0];
                return Math.round(100 * (device?.battery ? device?.battery : 1));
            },
            hoverItem: bluetoothPopup
        },
        {
            id: "network",
            icon: NetworkService.manager.materialSymbol,
            dialog: "Wifi",
            hoverItem: networkPopup
        }
    ]

    implicitWidth: grid.implicitWidth + Padding.huge
    implicitHeight: grid.implicitHeight + Padding.huge

    GridLayout {
        id: grid

        anchors.centerIn: parent
        rows: verticalMode ? 4 : 1
        columns: verticalMode ? 1 : 4
        rowSpacing: verticalMode ? Padding.small : 0
        columnSpacing: verticalMode ? 0 : Padding.small
        Repeater {
            model: ScriptModel {
                values: {
                    return root.content.filter(item => {
                        const isVisible = item.visible ?? true;
                        const isEnabled = Mem.options.bar.statusIcons.enabledStatusIcons.indexOf(item.id) !== -1 ?? true;
                        return isEnabled && isVisible;
                    });
                }
            }

            delegate: StatusIcon {
                required property var modelData
                required property int index
                readonly property int aPadding: useBg ? Padding.massive : Padding.small
                useBg: root.active
                implicitHeight: isVertical ? grid.implicitHeight + aPadding : root?.height - Padding.large
                implicitWidth: !isVertical ? grid.implicitWidth + aPadding : root?.width - Padding.large
                icon: modelData?.icon ?? ""
                mode: (root.useBothWhenAvailable && modelData.text && !modelData.mode) ? "both" : modelData?.mode ?? "symbol"
                isVertical: root.vertical
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                text: {
                    if (!modelData)
                        return;

                    if (typeof modelData.text === "function")
                        return modelData?.text() ?? "";
                    else
                        return modelData?.text ?? "";
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: !!modelData.dialog ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (modelData.dialog) {
                            Globals.main.dialogs.current = modelData.dialog;
                            Ipc.call(["sidebar", "reveal", "Notifs"]);
                        } else
                            modelData?.action() ?? null;
                    }
                    StyledLoader {
                        shown: modelData.hoverItem !== null
                        anchors.fill: parent
                        sourceComponent: modelData.tooltip ? tooltipComp : modelData?.hoverItem ?? null
                        onLoaded: {
                            if ("hoverTarget" in _item) {
                                _item.hoverTarget = Qt.binding(() => hoverArea);
                            }
                            if (("content" in _item) && modelData.tooltip) {
                                _item.content = Qt.binding(() => modelData.tooltip);
                            }
                        }
                    }
                }
            }
        }
    }
}
