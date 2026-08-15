import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

StyledRect {
    id: bg
    height: controls?.implicitHeight + Padding.massive
    width: controls?.implicitWidth + Padding.massive
    radius: height / 2
    color: Colors.colPrimaryContainer
    ButtonGroup {
        id: controls
        anchors.centerIn: parent
        spacing: Padding.verysmall

        Repeater {
            id: rptr
            model: [
                {
                    icon: "logout",
                    releaseAction: () => NoonUtils.execDetached(["loginctl", "kill-user", Quickshell.env("USER")])
                },
                {
                    icon: "dark_mode",
                    releaseAction: () => NoonUtils.execDetached(["systemctl", "suspend"])
                },
                {
                    icon: "restart_alt",
                    releaseAction: () => NoonUtils.execDetached(["systemctl", "reboot"])
                },
                {
                    icon: "power_settings_new",
                    releaseAction: () => NoonUtils.execDetached(["systemctl", "poweroff"])
                },
            ]
            delegate: GroupButtonWithIcon {
                required property var modelData
                required property int index
                toggled: true
                materialIcon: modelData?.icon
                implicitSize: 54
                iconSize: 20
                leftRadius: index === 0 ? height / 2 : Rounding.tiny
                rightRadius: index === rptr.model.length - 1 ? height / 2 : Rounding.tiny
                onClicked: modelData.releaseAction()
            }
        }
    }
}
