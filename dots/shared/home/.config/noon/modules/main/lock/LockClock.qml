import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import qs.services
import qs.data

Item {
    id: root
    anchors.centerIn: parent
    implicitHeight: clock.implicitHeight + 100
    implicitWidth: clock.implicitWidth + 100

    readonly property real clockScale: 2.0
    property int wght: hovered ? 1000 : 100
    property int wdth: hovered ? 0 : 118
    readonly property bool hovered: hoverArea.containsMouse

    Anim on scale {
        from: 0.25
        to: 1
        _duration: "huge"
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
        anchors.centerIn: parent

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
