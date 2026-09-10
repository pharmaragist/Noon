import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root
    required property Item target
    property string style: "button"
    property bool rightMode: false
    property var colors: Colors
    width: target.width
    height: target.currentItem ? target.currentItem.height : 0
    y: target.currentItem ? target.currentItem.y : 0
    z: -2

    Behavior on y {
        SAnim {}
    }

    Anim on opacity {
        from: 0
        to: 1
    }

    Anim on scale {
        from: -0.98
        to: 1
    }

    StyledLoader {
        readonly property var styles: ({
                "button": buttonComponent,
                "pill": pillComponent,
                "badge": badgeComponent
            })
        anchors.fill: parent
        sourceComponent: styles[root?.style] ?? buttonComponent

        readonly property Component pillComponent: Item {
            StyledRect {
                id: pillBg
                anchors.left: root?.rightMode ? undefined : parent.left
                anchors.right: !root?.rightMode ? undefined : parent.right
                anchors.margins: Padding.tiny
                width: 5
                radius: Rounding.small
                color: root?.colors.colSecondaryContainer

                readonly property real baseH: Math.max(1, root?.height - Padding.large)
                readonly property real boom: baseH * 1.6
                readonly property real boomPad: Math.max(Padding.large, baseH * 0.6)
                property real ext: 0

                height: baseH + ext
                y: 0
                anchors.verticalCenter: parent.verticalCenter

                Connections {
                    target: root
                    function onYChanged() {
                        pillBg.ext = pillBg.boomPad;
                    }
                }

                Behavior on ext {
                    Anim {
                        duration: Animations.durations.large
                    }
                }
            }
        }

        readonly property Component badgeComponent: Item {
            RoundCorner {
                corner: RoundCorner.BottomRight
                size: Rounding.verylarge
                color: bg.color
                anchors.bottom: bg.top
                anchors.left: root?.rightMode ? undefined : bg.left
                anchors.right: !root?.rightMode ? undefined : bg.right
            }
            StyledRect {
                id: bg
                anchors.left: root?.rightMode ? undefined : parent.left
                anchors.right: !root?.rightMode ? undefined : parent.right
                anchors.margins: Padding.tiny
                anchors.verticalCenter: parent.verticalCenter

                width: target.width - Padding.large
                bottomRightRadius: root?.rightMode ? Rounding.verylarge : rightRadius
                bottomLeftRadius: !root?.rightMode ? Rounding.verylarge : leftRadius

                height: (target.width / 2) + Padding.small
                rightRadius: !root?.rightMode ? Rounding.verylarge : 0
                leftRadius: root?.rightMode ? Rounding.verylarge : 0
                color: root?.colors.colSecondaryContainer
            }
        }

        readonly property Component buttonComponent: Item {
            StyledRect {
                anchors.centerIn: parent
                width: target.width * 2 / 3
                height: width * 0.8
                radius: width / 2
                color: root?.colors.colSecondaryContainer
            }
        }
    }
}
