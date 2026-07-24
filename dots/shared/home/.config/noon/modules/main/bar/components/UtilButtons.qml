import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

BarGroup {
    id: root
    implicitWidth: content.implicitWidth + Padding.huge
    implicitHeight: content.implicitHeight + Padding.huge

    readonly property var utils: [
        {
            "icon": "screenshot",
            "action": () => Globals.main.showScreenshot = true
        },
        {
            "icon": "dashboard",
            "action": () => NoonUtils.callIpc("sidebar reveal Notifs")
        }
    ]

    GridLayout {
        id: content

        rows: !root.vertical ? 1 : 4
        columns: root.vertical ? 1 : 4
        columnSpacing: 4
        rowSpacing: 4
        anchors.centerIn: parent

        Repeater {
            id: repeater
            model: [...root.utils, ...Mem.options.bar.utils.customUtils]
            delegate: RippleButtonWithIcon {
                toggled: false
                materialIcon: modelData.icon
                materialIconFill: hovered
                implicitSize: Math.round(Math.min(root.width, root.height) * 0.75)
                releaseAction: () => {
                    if (typeof modelData.action !== "function")
                        NoonUtils.execDetached([...modelData.action]);
                    else
                        modelData.action();
                }
            }
        }
    }
}
