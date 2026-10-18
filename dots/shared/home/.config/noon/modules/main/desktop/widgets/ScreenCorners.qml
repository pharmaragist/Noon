import QtQuick
import qs.common
import qs.common.utils
import qs.common.widgets

Variants {
    model: MonitorsInfo.all

    StyledPanel {
        id: panel
        required property var modelData
        screen: modelData
        _layer: Mem.options.desktop?.screenCorners === "Top" ? "Top" : "Overlay"
        exclusiveZone: -1
        name: "noanim_blurred_layer"
        fill: true
        mask: Region {
            Region {
                item: topRight
            }
            Region {
                item: bottomRight
            }
            Region {
                item: topLeft
            }
            Region {
                item: bottomLeft
            }
        }

        Corner {
            id: topLeft
            anchors.top: parent.top
            anchors.left: parent.left
            corner: RoundCorner.TopLeft
            action: () => {}
        }
        Corner {
            id: topRight
            anchors.top: parent.top
            anchors.right: parent.right
            corner: RoundCorner.TopRight
            action: () => {}
        }
        Corner {
            id: bottomLeft
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            corner: RoundCorner.BottomLeft
            action: () => {
                NoonUtils.execDetached("hyprctl eval 'overview_toggle()'");
            }
        }
        Corner {
            id: bottomRight
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            corner: RoundCorner.BottomRight
            action: () => {
                Globals.main.beam.show = true;
                Globals.main.beam.reason = "music";
            }
        }
    }

    component Corner: Item {
        property var action
        property alias corner: cornerItem.corner
        implicitHeight: implicitWidth
        implicitWidth: Math.min(20, cornerItem.size)

        RoundCorner {
            id: cornerItem
            color: Mem.options.desktop.screenCorners === "Disabled" ? "transparent" : "black"
            size: Mem?.hypr?.rounding ?? Rounding.verylarge
        }
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            onEntered: () => {
                hoverArea.enabled = false;
                action();
                NoonUtils.inlineTimer(() => {
                    hoverArea.enabled = true;
                }, 200);
            }
        }
    }
}
