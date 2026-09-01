import QtQuick
import Quickshell

import qs.services
import qs.common
import qs.common.widgets

Variants {
    model: MonitorsInfo.focused

    StyledPanel {
        id: root
        required property var modelData
        name: "noanim_blurred_layer"
        _layer: "Top"
        exclusiveZone: 0
        fill: true
        screen: modelData
        mask: Region {
            item: listview
        }
        NotificationListView {
            id: listview

            hint: false
            clip: false
            popup: true

            implicitWidth: Sizes.notificationPopupWidth - anchors.margins * 2
            implicitHeight: listview.contentItem.childrenRect.height

            readonly property string pos: Mem.options.desktop.popups?.notifications ?? "TopCenter"

            function getAnc(side) {
                return pos.toLowerCase().includes(side) ? side === "center" ? parent.horizontalCenter : parent[side] : undefined;
            }

            anchors {
                top: getAnc("top")
                left: getAnc("left")
                right: getAnc("right")
                bottom: getAnc("bottom")
                horizontalCenter: getAnc("center")
            }

            popupProps: ({
                    overshoot: Screen.width,
                    threshold: 20
                })

            Anim on anchors.margins {
                from: -height
                to: Sizes.elevationMargin
                duration: Animations.durations.normal
            }
        }
    }
}
