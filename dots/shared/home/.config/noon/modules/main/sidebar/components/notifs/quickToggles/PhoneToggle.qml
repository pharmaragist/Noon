import QtQuick
import Quickshell
import qs.common
import qs.services
import qs.common.widgets

QuickToggleButton {
    buttonName: KdeConnectService?.selectedDeviceName || "Offline"
    dialogName: "Phone"
    buttonSubtext: KdeConnectService?.selectedDeviceStatus || "No Reachable Devices"
    toggled: KdeConnectService?.selectedDeviceName.length > 0
    buttonIcon: toggled ? "phonelink" : "phonelink_off"
}
