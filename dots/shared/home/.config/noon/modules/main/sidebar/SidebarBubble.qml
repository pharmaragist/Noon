import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data
import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root

    required property var sidebarBg
    required property bool show
    required property bool rightMode
    required property string selectedCategory
    required property var colors
    readonly property var sidebar: Globals.main.sidebar

    ScriptModel {
        id: bubbles
        values: [
            {
                "cat": "Tasks",
                "bubbles": [
                    {
                        "icon": "refresh",
                        "action": () => {
                            TodoService.pull();
                        }
                    }
                ]
            },
            {
                "cat": "API",
                "bubbles": [
                    {
                        "icon": "clear_all",
                        "action": () => {
                            Ai.clearMessages();
                        }
                    },
                    {
                        "icon": "globe",
                        "action": () => {
                            Ai.openInTerm();
                        }
                    }
                ]
            },
            {
                "cat": "History",
                "bubbles": [
                    {
                        "icon": "clear_all",
                        "action": () => {
                            ClipboardService.wipe();
                        }
                    }
                ]
            },
            {
                "cat": "Shelf",
                "bubbles": [
                    {
                        "icon": "clear_all",
                        "action": () => {
                            Mem.states.sidebar.shelf.filePaths = [];
                        }
                    }
                ]
            },
            {
                "cat": "Tasks",
                "bubbles": []
            },
            {
                "cat": "Beats",
                "bubbles": [
                    {
                        "icon": "restart_alt",
                        "action": () => BeatsService.restartDaemon()
                    },
                    {
                        "icon": "close",
                        "action": () => MediaPlayerService.stopPlayer()
                    }
                ]
            }
        ]
    }

    readonly property var panelActionsModel: [
        {
            icon: "close",
            visible: sidebar.auxWidth > 0,
            action: () => sidebar.close_aux(),
            toggled: false
        },
        {
            icon: "select_window",
            toggled: SidebarData.detachedContent.includes(sidebar.selectedCategory),
            visible: SidebarData.isDetachable(sidebar.selectedCategory),
            enabled: !SidebarData.detachedContent.includes(sidebar.selectedCategory),
            action: () => sidebar.detach()
        },
        {
            icon: "push_pin",
            toggled: sidebar.pinned,
            action: () => sidebar.pinned = !sidebar.pinned
        },
        {
            visible: SidebarData.isExpandable(sidebar.selectedCategory),
            icon: "expand_content",
            toggled: sidebar.expanded,
            action: () => sidebar.expanded = !sidebar.expanded
        }
    ]

    visible: bg.width > 0
    width: show ? 55 : 0
    clip: true
    height: bg.height

    anchors.right: !rightMode ? undefined : sidebarBg.left
    anchors.left: rightMode ? undefined : sidebarBg.right
    anchors.bottom: sidebarBg.bottom
    anchors.margins: Math.max(Math.floor(sidebar.rounding / 3), Padding.small)
    anchors.bottomMargin: anchors.margins + Sizes.frameThickness

    StyledRect {
        id: bg

        color: Colors.t(root.colors.colLayer0)
        anchors.right: parent.right
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: content.implicitHeight + Padding.massive
        radius: Rounding.verylarge

        MouseArea {
            id: mouse

            acceptedButtons: Qt.NoButton
            anchors.fill: parent
            propagateComposedEvents: false
            hoverEnabled: true
        }

        ColumnLayout {
            id: content

            spacing: Padding.verysmall
            anchors.centerIn: parent

            Repeater {
                id: repeater
                model: bubbles

                ColumnLayout {
                    spacing: parent.spacing
                    visible: modelData?.cat === root?.selectedCategory ?? true

                    Repeater {
                        id: subrepeater
                        model: ScriptModel {
                            values: modelData.bubbles
                        }

                        RippleButtonWithIcon {
                            toggled: modelData.toggled ?? false
                            colors: root.colors
                            visible: modelData?.extraVisibleCondition ?? true
                            Layout.fillWidth: true
                            enabled: modelData.enabled !== undefined ? modelData.enabled : true
                            materialIcon: modelData.icon
                            releaseAction: modelData.action
                        }
                    }

                    Separator {
                        visible: subrepeater.count > 0
                        Layout.leftMargin: Padding.normal
                        Layout.rightMargin: Padding.normal
                    }
                }
            }
            Repeater {
                model: root.panelActionsModel

                RippleButtonWithIcon {
                    colors: root.colors
                    Layout.fillWidth: true
                    visible: modelData?.visible ?? true
                    toggled: modelData.toggled ?? false
                    enabled: modelData?.enabled ?? true
                    materialIcon: modelData?.icon
                    releaseAction: modelData?.action
                }
            }
        }
    }
}
