import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.store

Item {
    id: highlight
    readonly property bool rightMode: Globals.main.sidebar.rightMode
    width: navRailList.width
    height: navRailList.currentItem ? navRailList.currentItem.height : 0
    y: navRailList.currentItem ? navRailList.currentItem.y : 0
    z: -2

    Behavior on y {
        Anim {}
    }

    Anim on opacity {
        from: 0
        to: 1
    }

    StyledLoader {
        readonly property var styles: ({
                "shape": shapeComponent,
                "button": buttonComponent,
                "pill": pillComponent,
                "badge": badgeComponent
            })
        anchors.fill: parent
        sourceComponent: styles[Mem.options.sidebar.navRail.indicatorStyle] ?? shapeComponent

        readonly property Component shapeComponent: Item {
            MaterialShape {
                anchors.centerIn: parent
                shape: SidebarData.getShape(root.selectedCategory)
                color: root.colors.colSecondaryContainer
                Anim on implicitSize {
                    from: 0
                    to: 40
                }
            }
        }
        readonly property Component pillComponent: Item {
            StyledRect {
                anchors.left: highlight.rightMode ? undefined : parent.left
                anchors.right: !highlight.rightMode ? undefined : parent.right
                anchors.margins: Padding.tiny
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                radius: Rounding.small
                color: root.colors.colPrimary
                Anim on height {
                    from: 0
                    to: highlight?.height - Padding.large
                }
            }
        }

        readonly property Component badgeComponent: Item {
            RoundCorner {
                corner: RoundCorner.BottomRight
                size: Rounding.verylarge
                color: bg.color
                anchors.bottom: bg.top
                anchors.left: highlight.rightMode ? undefined : bg.left
                anchors.right: !highlight.rightMode ? undefined : bg.right
            }
            StyledRect {
                id: bg
                anchors.left: highlight.rightMode ? undefined : parent.left
                anchors.right: !highlight.rightMode ? undefined : parent.right
                anchors.margins: Padding.tiny
                anchors.verticalCenter: parent.verticalCenter

                width: navRailList.width - Padding.large
                bottomRightRadius: highlight.rightMode ? Rounding.verylarge : rightRadius
                bottomLeftRadius: !highlight.rightMode ? Rounding.verylarge : leftRadius

                height: (navRailList.width / 2) + Padding.small
                rightRadius: !highlight.rightMode ? Rounding.verylarge : 0
                leftRadius: highlight.rightMode ? Rounding.verylarge : 0
                color: root.colors.colSecondaryContainer
            }
        }

        readonly property Component buttonComponent: Item {
            StyledRect {
                anchors.centerIn: parent
                width: navRailList.width * 2 / 3
                height: width * 0.8
                radius: width / 2
                color: root.colors.colSecondaryContainer
            }
        }
    }
}
