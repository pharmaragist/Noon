import QtQuick
import QtQuick.Effects
import Quickshell
import qs.data
import qs.common
import qs.common.utils
import qs.common.widgets

Variants {
    model: MonitorsInfo.all

    StyledPanel {
        required property var modelData

        id: root
        name: "noanim_blurred_layer"
        color: "transparent"
        visible: true
        _layer: "Top"
        exclusiveZone: 0
        fill: true
        screen: modelData

        mask: Region {
            item: container
            intersection: Intersection.Xor
        }

        Item {
            id: container

            anchors.fill: parent


            Rectangle {
                anchors.fill: parent
                color: Colors.colLayer0
                layer.enabled: true

                layer.effect: MultiEffect {
                    maskSource: maskLayer
                    maskEnabled: true
                    maskInverted: true
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
            }


            Item {
                id: maskLayer

                anchors.fill: parent
                visible: false
                layer.enabled: true

                Rectangle {
                    id: innerMask

                    function getMargins(side) {
                        const base = Sizes.frameThickness
                        return BarData.currentModeInfo.position === side ? base / 2 : base;
                    }

                    radius: Rounding.veryhuge
                    anchors {
                        fill: parent
                        leftMargin: getMargins("left")
                        rightMargin: getMargins("right")
                        topMargin: getMargins("top")
                        bottomMargin: getMargins("bottom")
                    }
                }
            }
        }
    }
}
