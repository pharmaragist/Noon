import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.common.widgets

Variants {
    model: MonitorsInfo.main

    StyledPanel {
        id: root
        required property var modelData
        property int wght: hovered ? 1000 : Mem.states.fonts.variableAxes.display.wght
        property int wdth: hovered ? 0 : Mem.states.fonts.variableAxes.display.wdth
        readonly property real clockScale: Mem.states.desktop.clock.scale
        readonly property bool hovered: hoverArea.containsMouse

        name: "noanim_layer"
        exclusiveZone: 0
        _layer: "Bottom"
        _margins: Sizes.elevationMargin
        implicitHeight: 400 * clockScale
        implicitWidth: 400 * clockScale

        anchors {
            bottom: true
            left: true
        }
        mask: Region {
            item: clock
        }

        Behavior on wght {
            SAnim {
                spring: 4
            }
        }

        Behavior on wdth {
            SAnim {
                spring: 4
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
        }

        GridLayout {
            id: clock
            anchors.leftMargin: Padding.large
            anchors.bottomMargin: Padding.large
            anchors.bottom: parent.bottom
            anchors.left: parent.left

            rowSpacing: -25 * clockScale
            columns: 2
            rows: 2

            Repeater {
                model: {
                    const h = DateTimeService.hour;
                    const m = DateTimeService.minute;
                    return [h[0], h[1], m[0], m[1]];
                }

                StyledText {
                    id: textItem
                    required property var modelData
                    required property int index
                    text: modelData

                    font.pixelSize: 100 * root.clockScale
                    color: root.hovered ? ((Math.floor(index / 2) + index) % 2 === 0 ? Colors.colPrimary : Colors.colSecondaryContainer) : Colors.colOnBackground
                    font.family: Fonts.family.main
                    font.variableAxes: ({
                            "wdth": root.wdth,
                            "wght": root.wght
                        })

                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }
    }
}
