import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

BarGroup {
    id: root

    implicitHeight: clock.implicitHeight + (active ? Padding.massive : Padding.small)
    property int wght: hovered ? 1000 : 300
    property int wdth: hovered ? 0 : 100
    readonly property bool hovered: eventAarea.containsMouse

    readonly property color colPrimary: Colors.colPrimary
    readonly property color colSecondary: Colors.colSecondaryContainer
    readonly property color colBase: Colors.colOnSurfaceVariant

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
        id: eventAarea
        hoverEnabled: true
        anchors.fill: parent
    }

    GridLayout {
        id: clock
        anchors.centerIn: parent

        columnSpacing: 1
        rowSpacing: 2

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
                font.pixelSize: 18
                color: root.hovered ? ((Math.floor(index / 2) + index) % 2 === 0 ? root.colPrimary : root.colSecondary) : root.colBase
                // Layout.topMargin: (index % 2) === 0 ? 4 : 0
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

    ClockPopup {
        hoverTarget: eventAarea
    }
}
