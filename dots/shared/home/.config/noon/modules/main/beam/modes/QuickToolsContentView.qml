import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions

ContentViewItem {
    id: view

    PanelRect {
        id: bg
        color: Colors.colLayer0
        width: row.implicitWidth + Padding.massive
        height: row.implicitHeight + Padding.huge
        radius: Rounding.normal
        readonly property var tools: [
            {
                name: "update",
                icon: "refresh",
                action: () => {
                    NoonUtils.runSystemUpdate();
                }
            },
            {
                url: "https://www.google.com"
            },
            {
                url: "https://www.youtube.com"
            },
            {
                url: "https://www.reddit.com"
            },
            {
                url: "https://ww25.soap2day.day"
            }
        ]

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Padding.large

            Repeater {
                model: bg.tools
                ToolItem {
                    required property var modelData
                    implicitSize: 75
                    url: modelData?.url ?? ""
                    tooltip: modelData?.tooltip ?? ""
                    name: modelData?.name ?? TextUtils.getDomain(this.url)
                    mIcon: modelData?.icon ?? ""
                    downAction: () => {
                        const _action = modelData?.action ?? NoonUtils.open(modelData.url);
                        if (!!_action)
                            _action();
                        view.dismiss();
                    }
                }
            }
        }
    }

    component ToolItem: RippleButton {
        id: root
        buttonRadius: Rounding.huge
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
                sourceComponent: root.url.length > 0 ? favIcon : icon

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
