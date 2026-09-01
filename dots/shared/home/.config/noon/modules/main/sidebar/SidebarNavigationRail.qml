import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.store

Item {
    id: root

    required property var panel
    required property var content
    required property string selectedCategory
    required property var colors

    property alias radius: bg.radius
    property alias color: bg.color

    readonly property bool sleek: !Mem.options.sidebar.navRail.showNavTitles
    readonly property string mode: {
        const dbMode = SidebarData?._get(selectedCategory)?.navRailMode ?? "";
        if (dbMode?.length > 0)
            return dbMode;
        else if (Mem.options.sidebar.navRail.style === "sidebar")
            return Mem.options.sidebar.appearance?.style;
        else
            return Mem.options.sidebar.navRail.style;
    }
    implicitWidth: Sizes.sidebar.bar
    Layout.fillHeight: true

    signal showContextMenu(string category, int globalX, int globalY)

    StyledRect {
        id: stealthPill
        z: 99999
        anchors.centerIn: parent
        color: root.colors.colPrimaryContainer
        radius: Rounding.full
        implicitWidth: catName.contentHeight + Padding.small * 2
        implicitHeight: catName.contentWidth + Padding.massive * 2
        opacity: show ? 1 : 0
        readonly property bool show: SidebarData?.isStealth(root.selectedCategory)

        StyledText {
            id: catName
            text: show ? root.selectedCategory : ""
            font.pixelSize: Fonts.sizes.large
            anchors.centerIn: parent
            rotation: -90
        }
    }

    RoundCorner {
        id: c1

        visible: bg.state === "concave"
        corner: panel.rightMode ? RoundCorner.BottomRight : RoundCorner.BottomLeft
        color: bg.color
        size: root?.panel?.rounding

        anchors.left: panel.rightMode ? undefined : bg.right
        anchors.right: panel.rightMode ? bg.left : undefined
        anchors.bottom: bg.bottom
    }

    RoundCorner {
        corner: panel.rightMode ? RoundCorner.TopRight : RoundCorner.TopLeft

        visible: c1.visible
        color: c1.color
        size: c1.size
        anchors.left: panel.rightMode ? undefined : bg.right
        anchors.right: panel.rightMode ? bg.left : undefined

        anchors.top: bg.top
    }

    StyledRect {
        id: bg
        clip: true
        radius: 0
        anchors.fill: parent
        color: root.colors.colLayer2
        layer.enabled: stealthPill.show
        layer.effect: StyledFastBlur {
            radius: 40
        }
        state: root.mode
        states: [
            State {
                name: "sharp"
            },
            State {
                name: "concave"
            },
            State {
                name: "clear"
                PropertyChanges {
                    target: bg

                    color: colors.colLayer0
                }
                PropertyChanges {
                    target: dropShadow
                    show: false
                }
            },
            State {
                name: "float"
                PropertyChanges {
                    target: bg

                    anchors.margins: Padding.tiny
                    radius: Rounding.large
                }
            },
            State {
                name: "convex"
                PropertyChanges {
                    target: bg

                    leftRadius: panel.rightMode ? panel.rounding : 0
                    rightRadius: !panel.rightMode ? panel.rounding : 0
                }
            }
        ]

        Item {
            anchors.fill: parent

            ListView {
                id: navRailList
                width: parent.width
                height: Math.min(contentHeight + topMargin + bottomMargin, parent.height)
                anchors.centerIn: parent
                spacing: sleek ? 0 : Padding.verylarge
                model: SidebarData.enabledCategories
                currentIndex: SidebarData.enabledCategories.indexOf(root.selectedCategory)
                interactive: height === parent.height

                displayMarginBeginning: topMargin
                displayMarginEnd: bottomMargin

                topMargin: Padding.huge
                bottomMargin: Padding.huge

                highlightFollowsCurrentItem: false
                highlight: SidebarNavigationRailHighlight {}
                delegate: NavigationRailButton {
                    required property int index
                    required property string modelData

                    fontSize: 9
                    showText: !root.sleek
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: baseSize
                    baseSize: Math.round(navRailList.width * 2 / 3)
                    toggled: root.selectedCategory === modelData
                    buttonIcon: SidebarData?.getIcon(modelData, toggled ?? false)
                    buttonText: modelData || ""
                    highlightColor: "transparent"
                    highlightColorHover: index === navRailList?.currentIndex ? "transparent" : root.colors.colLayer2Hover
                    highlightColorActive: "transparent"
                    itemColorActive: root.colors.colOnSecondaryContainer

                    MouseArea {
                        id: eventArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        propagateComposedEvents: true
                        onClicked: event => {
                            if (event.button === Qt.LeftButton)
                                content.changeContent(modelData);
                            else if (event.button === Qt.RightButton) {
                                var pos = eventArea.mapToItem(null, event.x, event.y);
                                root.showContextMenu(modelData, pos.x, pos.y);
                            }
                        }
                    }

                    StyledToolTip {
                        content: modelData
                        extraVisibleCondition: root.sleek && selectedCategory !== ""
                    }

                    DragHandler {
                        acceptedButtons: Qt.LeftButton
                        xAxis.enabled: true
                        yAxis.enabled: false
                        onActiveChanged: if (SidebarData.isDetachable(modelData) && !SidebarData.isDetached(modelData)) {
                            Globals.main.sidebar.detach(modelData);
                        }
                    }
                }
            }
        }
    }
    StyledRect {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: panel.rightMode ? parent.left : undefined
        anchors.right: !panel.rightMode ? parent.right : undefined

        color: root.colors.colLayer3
        implicitWidth: 1
        opacity: !panel.show ? 0 : 1
    }
}
