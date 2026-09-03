import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.data
import qs.common
import qs.services
import qs.common.functions
import qs.common.utils
import qs.common.widgets

Scope {
    id: scope

    Variants {
        model: MonitorsInfo.focused

        StyledPanel {
            id: root

            fill: true
            screen: modelData
            shell: "noon"
            name: "blurred_layer"
            _layer: Mem.options.sidebar.behavior.overlay ? "Overlay" : "Top"
            implicitWidth: !pinned ? Screen.width : effectiveLayerWidth
            aboveWindows: true
            keyboardFocus: true
            anchors.left: !root.rightMode || !pinned
            anchors.right: root.rightMode || !pinned
            exclusiveZone: pinned ? effectiveLayerWidth : 0
            focusHandler.active: root.pinned || root.show
            focusHandler.onCleared: !root.pinned ? root.hide() : null

            mask: Region {
                Region {
                    item: hoverArea
                }
                Region {
                    item: bg
                }
                Region {
                    item: bubble
                }
            }

            property bool hoverMode: true
            property bool pinned: false
            property bool expanded: false
            property bool reveal: revealCondition
            property int selectedTabIndex: 0
            property alias selectedCategory: content.selectedCategory

            readonly property alias content: content
            required property var modelData
            readonly property bool opposeBar: true
            readonly property bool rightMode: opposeBar ? barPosition !== "right" : barPosition !== "left"
            readonly property bool show: !hoverMode
            readonly property bool revealCondition: (!hoverMode || hoverArea.containsMouse || content.hovered) || PolkitService.flow !== null
            readonly property int rounding: Rounding.verylarge
            readonly property string barPosition: BarData.currentModeInfo.position
            readonly property int sidebarWidth: Math.min(Screen.width - 120, SidebarData.currentSize(hoverMode, root.expanded, selectedCategory) + auxWidth)
            readonly property int auxWidth: content.auxVisible && !hoverMode ? SidebarData.currentSize(false, false, content.auxCategory) : 0
            readonly property int hoverArea: 2
            readonly property int effectiveLayerWidth: bg.width + bubble.width + Sizes.hyprland.gapsOut
            readonly property Component detachedWindow: DetachedSidebarWindow {}

            function hide() {
                if (pinned)
                    return;
                reveal = false;
                hoverMode = true;
                selectedTabIndex = 0;
                content.selectedCategory = "";
                if (!pinned)
                    reset_reveal_conditions();
            }

            function incubate(cat = selectedCategory) {
                if (SidebarData.isIncubatable(cat)) {
                    Globals.main.sysDialogs.mode = "incubate";
                    Globals.main.sysDialogs.pendingData = cat;
                    Mem.states.desktop.dialogs.lastIncubatedCategory = cat;
                }
            }
            function detach(cat = selectedCategory) {
                if (SidebarData.isDetachable(cat) || !isDetached()) {
                    detachedWindow.createObject(root, {
                        category: cat
                    });
                }
                hide();
            }
            function isDetached() {
                return SidebarData.detachedContent.includes(root.selectedCategory);
            }
            function setTab(tab) {
                if (tab)
                    root.selectedTabIndex = tab;
            }
            function reveal_content(selectedTab = 0) {
                hoverMode = false;
                content.forceActiveFocus();
            }

            function close_aux() {
                content.closeAux();
            }

            function reset_reveal_conditions() {
                root.reveal = Qt.binding(() => {
                    return root.revealCondition;
                });
            }

            Binding {
                target: Globals.main
                property: "sidebar"
                value: root
            }

            HoverHandler {
                id: hoverArea
                implicitWidth: root.hoverArea
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: !root.rightMode ? parent.left : undefined
                anchors.right: root.rightMode ? parent.right : undefined
            }

            ScreenActionHintPanel {
                target: dropArea
                hint: {
                    "icon": "keyboard_double_arrow_right",
                    "text": "Drop it Inside Your Shelf !"
                }
            }


            DropArea {
                id: dropArea
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: NoonUtils.callIpc("sidebar reveal Shelf")
            }

            StyledRectangularShadow {
                target: bg
                show: root.reveal
            }

            PanelRect {
                id: bg
                readonly property int hideMargin: state === "float" ? Sizes.elevationMargin : 0

                width: root.sidebarWidth
                animationDuration: Animations.durations.large

                anchors.top: parent.top
                anchors.bottom: parent.bottom

                anchors.left: !rightMode ? parent.left : undefined
                anchors.right: rightMode ? parent.right : undefined
                anchors.leftMargin: !rightMode ? ((!hoverMode || reveal) ? hideMargin : -root.sidebarWidth) : 0
                anchors.rightMargin: rightMode ? ((!hoverMode || reveal) ? hideMargin : -root.sidebarWidth) : 0
                state: Mem.options.sidebar.appearance?.style ?? "float"

                Content {
                    id: content
                    panelWindow: root
                    selectedTabIndex: root.selectedTabIndex
                }

                states: [
                    State {
                        name: "float"
                        PropertyChanges {
                            target: bg
                            radius: root.rounding
                            enableBorders: true
                            border.color: content.rail.color
                            anchors.topMargin: Sizes.elevationMargin
                            anchors.bottomMargin: Sizes.elevationMargin
                        }
                    },
                    State {
                        name: "convex"

                        PropertyChanges {
                            target: bg

                            rightRadius: root.rightMode ? 0 : Rounding.massive
                            leftRadius: !root.rightMode ? 0 : Rounding.massive
                        }
                    },
                    State {
                        name: "sharp"
                    },
                    State {
                        name: "concave"
                    }
                ]

                Behavior on anchors.leftMargin {
                    Anim {
                        easing.bezierCurve: Animations.curves.emphasized
                    }
                }

                Behavior on anchors.rightMargin {
                    Anim {
                        easing.bezierCurve: Animations.curves.emphasized
                    }
                }
            }

            SidebarBubble {
                id: bubble

                show: !hoverMode
                rightMode: root.rightMode
                selectedCategory: content.selectedCategory
                colors: content.colors
                sidebarBg: bg
            }

            RoundCorner {
                id: c1

                visible: bg.state === "concave"
                corner: root.rightMode ? RoundCorner.BottomRight : RoundCorner.BottomLeft
                color: content.colors.colLayer0
                size: root.rounding

                anchors.left: root.rightMode ? undefined : bg.right
                anchors.right: root.rightMode ? bg.left : undefined
                anchors.bottom: bg.bottom
                anchors.bottomMargin: root.barPosition === "bottom" ? 0 : Sizes.frameThickness
            }

            RoundCorner {
                corner: root.rightMode ? RoundCorner.TopRight : RoundCorner.TopLeft

                visible: c1.visible
                color: c1.color
                size: c1.size
                anchors.left: root.rightMode ? undefined : bg.right
                anchors.right: root.rightMode ? bg.left : undefined

                anchors.top: bg.top
                anchors.topMargin: root.barPosition === "top" ? 0 : Sizes.frameThickness
            }
            IpcHandler {
                target: "sidebar"

                function reveal_aux(cat: string) {
                    content.toggleAux(cat);
                }

                function dismiss_aux() {
                    content.closeAux();
                }

                function reveal(cat: string) {
                    content.changeContent(cat);
                }

                function reveal_no(index: int) {
                    const arr = Object.keys(SidebarData?.registry);
                    const cat = arr[index];
                    content.changeContent(cat);
                }

                function pin() {
                    root.pinned = true;
                }

                function unpin() {
                    root.pinned = false;
                }

                function toggle_pin() {
                    root.pinned = !root.pinned;
                }

                function hide() {
                    root.hide();
                }
            }
        }
    }
}
