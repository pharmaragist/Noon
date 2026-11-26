import QtQuick
import QtQuick.Layouts
import qs.services

import qs.common
import qs.common.utils
import qs.common.widgets

Scope {
    id: root

    Variants {
        model: MonitorsInfo.main

        StyledPanel {
            visible:true
            required property var modelData
            name: "blurred_layer"
            screen: modelData
            fill: true
            _layer: "Overlay"
            mask: Region {
                item: bg
            }

            StyledRectangularShadow {
                target: bg
            }

            StyledRect {
                id: bg
                anchors.centerIn: parent
                implicitWidth: Math.max(400, grid.contentWidth + Padding.huge)
                implicitHeight: Math.max(100, grid.contentHeight + Padding.huge)
                radius: Rounding.huge
                color: Colors.colLayer2

                GridLayout {
                    id: grid
                    anchors.fill: parent
                    anchors.margins: Padding.huge
                    rows: 1
                    rowSpacing: Padding.small

                    Repeater {
                        model: Compositor.keyboardLayouts
                        delegate: StyledRect {
                            required property var modelData
                            required property int index
                            readonly property bool isSelected: modelData === Compositor.currentKeyboardLayout
                            color: isSelected ? Colors.colLayer3Active : Colors.colLayer3
                            radius: Rounding.verylarge

                            StyledText {
                                anchors.centerIn: parent
                                font: Fonts.request("title", 25)
                                color: Colors.colOnSurface
                            }
                        }
                    }
                }
            }
        }
    }
}
