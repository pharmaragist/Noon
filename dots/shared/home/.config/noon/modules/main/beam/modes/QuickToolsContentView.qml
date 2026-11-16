import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions

ContentViewItem {
    id: view
    readonly property real toolSize: 72
    readonly property real itemSize: toolSize - Padding.small

    readonly property var systemTools: [
        {
            name: "Update",
            icon: "refresh",
            action: () => NoonUtils.runSystemUpdate()
        }
    ]
    readonly property var urls: (Mem.options?.beam?.content?.quickActionsBookmarks ?? []).map(i => ({
                isUrl: true,
                url: i
            }))
    readonly property var bookmarks: (Mem.states?.services?.bookmarks?.firefoxBookmarks ?? []).map(obj => ({
                isUrl: true,
                name: obj.title ?? "",
                url: obj.url
            }))

    readonly property var allItems: {
        const groups = [[...(systemTools ?? []), ...(Mem.options?.beam?.content?.quickActionsTools ?? [])], urls ?? [], bookmarks ?? []].filter(g => g.length > 0);

        return groups.reduce((acc, g, i) => acc.concat(i > 0 ? ["SEPARATOR", ...g] : g), []);
    }
    readonly property int gridColumns: Math.max(1, Math.min((allItems ?? []).length, 15))

    Component {
        id: separatorComponent
        Item {
            implicitWidth: view.toolSize
            implicitHeight: view.toolSize
            VerticalSeparator {
                anchors.centerIn: parent
                implicitHeight: view.itemSize * 0.6
                implicitWidth: 2
            }
        }
    }

    Component {
        id: toolComponent
        ToolItem {
            property var toolData
            anchors.centerIn: parent
            implicitWidth: view.itemSize
            implicitHeight: view.itemSize
            isUrl: toolData?.isUrl ?? false
            url: toolData?.url ?? ""
            name: toolData?.name || TextUtils.getDomain(url)
            tooltip: toolData?.tooltip || name
            mIcon: toolData?.icon ?? ""

            downAction: () => {
                if (isUrl) {
                    NoonUtils.open(url);
                } else if (typeof toolData?.action === "function") {
                    toolData.action();
                } else if (toolData?.action) {
                    NoonUtils.execDetached(toolData.action);
                }
                view.dismiss();
            }

            StyledToolTip {
                content: parent.tooltip
            }
        }
    }

    PanelRect {
        id: bg
        color: Colors.colLayer0

        implicitWidth: gridLayout.implicitWidth + Padding.huge * 2
        implicitHeight: gridLayout.implicitHeight + Padding.huge * 2
        radius: Rounding.normal

        GridLayout {
            id: gridLayout
            anchors.centerIn: parent
            columns: view.gridColumns
            columnSpacing: Padding.normal
            rowSpacing: Padding.normal

            Repeater {
                model: view.allItems

                delegate: StyledLoader {
                    Layout.preferredWidth: view.toolSize
                    Layout.preferredHeight: view.toolSize
                    sourceComponent: modelData === "SEPARATOR" ? separatorComponent : toolComponent
                    binds: ({
                            toolData: () => modelData
                        })
                }
            }
        }
    }

    component ToolItem: RippleButton {
        id: root
        buttonRadius: Rounding.huge
        property bool isUrl: false
        property string tooltip: ""
        property string name: ""
        property string mIcon: ""
        property string url: ""

        contentItem: Item {
            anchors.fill: parent

            StyledLoader {
                anchors.centerIn: parent
                height: Math.min(parent.width, parent.height) * 0.6
                width: height
                sourceComponent: root.isUrl ? favIcon : icon

                Component {
                    id: icon
                    Symbol {
                        anchors.centerIn: parent
                        icon: root.mIcon
                        fill: root.hovered
                        iconSize: Math.min(parent.width, parent.height)
                    }
                }

                Component {
                    id: favIcon
                    Favicon {
                        anchors.centerIn: parent
                        url: root.url
                        displayText: root.name
                        size: Math.min(parent.width, parent.height)
                    }
                }
            }
        }
    }
}
