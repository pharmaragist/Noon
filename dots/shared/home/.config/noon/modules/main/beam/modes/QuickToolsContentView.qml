import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions

ContentViewItem {
    id: view
    readonly property real toolSize: 60
    readonly property var systemTools: [
        {
            name: "update",
            icon: "refresh",
            action: () => {
                NoonUtils.runSystemUpdate();
            }
        }
    ]
    readonly property var urls: Mem.options.beam.content.quickActionsBookmarks.map(i => ({
        isUrl: true,
        url: i
    }))

    PanelRect {
        id: bg
        color: Colors.colLayer0
        width: row.implicitWidth + Padding.massive
        height: view.toolSize + Padding.veryhuge
        radius: Rounding.normal

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Padding.normal

            Repeater {
                id: rep
                model: [...view.systemTools, ...Mem.options.beam.content.quickActionsTools, "SEPARATOR", ...urls]
                StyledLoader {
                    sourceComponent: modelData === "SEPARATOR" ? separator : tool
                    width: view.toolSize
                    height: view.toolSize
                    binds: {
                        "toolData": () => modelData
                    }
                    Component {
                        id: separator
                        VerticalSeparator {
                            implicitHeight: 50
                            implicitWidth: 2
                        }
                    }
                    Component {
                        id: tool
                        ToolItem {
                            property var toolData
                            implicitSize: view.toolSize
                            isUrl: toolData?.isUrl ?? false
                            url: toolData?.url ?? ""
                            tooltip: toolData?.tooltip ?? ""
                            name: toolData?.name ?? TextUtils.getDomain(this.url)
                            mIcon: toolData?.icon ?? ""
                            downAction: () => {
                                let _action = null
                                if (toolData?.isUrl)
                                    _action = () => NoonUtils.open(toolData?.url)
                                else if (typeof toolData?.action === "function")
                                    _action = toolData.action
                                else
                                    _action = () => NoonUtils.execDetached(toolData?.action ?? "")
                                if (!!_action)
                                    _action();
                                view.dismiss();
                            }
                        }
                    }
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

        contentItem: ColumnLayout {
            anchors.centerIn: parent
            spacing: Padding.large

            StyledLoader {
                height: 50
                width: 50
                Layout.alignment: Qt.AlignCenter
                sourceComponent: root.isUrl ? favIcon : icon

                Component {
                    id: icon

                    Symbol {
                        icon: root.mIcon
                        fill: root.hovered
                        iconSize: 30
                    }
                }

                Component {
                    id: favIcon

                    Favicon {
                        url: root?.url
                        displayText: root.name
                        size: 40
                    }
                }
            }
        }
    }
}
