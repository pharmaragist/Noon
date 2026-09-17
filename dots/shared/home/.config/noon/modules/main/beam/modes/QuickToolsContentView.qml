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
        // explicit cell math instead of layout implicits: each ToolItem is
        // exactly 75x75, so size stays rock-solid while squeezed/async loading
        width: rep.count * 75 + Math.max(0, rep.count - 1) * row.spacing + Padding.massive
        height: 75 + Padding.huge
        radius: Rounding.normal

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Padding.large

            Repeater {
                id: rep
                model: [...Mem.options.beam.content.quickActionsOptions]
                ToolItem {
                    required property var modelData
                    implicitSize: 75
                    url: modelData?.url ?? ""
                    tooltip: modelData?.tooltip ?? ""
                    name: modelData?.name ?? TextUtils.getDomain(this.url)
                    mIcon: modelData?.icon ?? ""
                    downAction: () => {
                        const _action = modelData?.url ? NoonUtils.open(modelData.url) : modelData.action();
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
