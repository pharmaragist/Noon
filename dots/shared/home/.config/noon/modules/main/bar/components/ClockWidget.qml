import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.data

BarGroup {
    id: root
    vertical: false
    implicitWidth: clock.implicitWidth + (active ? Padding.massive : Padding.small)
    property int wght: hovered ? 1000 : 300
    property int wdth: hovered ? 0 : 100
    readonly property bool hovered: eventArea.containsMouse

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
        id: eventArea
        hoverEnabled: true
        anchors.fill: parent
    }

    RowLayout {
        id: clock
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: {
                const h = DateTimeService.hour;
                const m = DateTimeService.minute;
                return [h[0], h[1], "SEPARATOR", m[0], m[1]];
            }

            StyledText {
                id: textItem
                required property var modelData
                required property int index
                text: modelData === "SEPARATOR" ? ":" : modelData
                font.pixelSize: 18
                color: root.hovered ? ((Math.floor(index / 2) + index) % 2 === 0 ? root.colPrimary : root.colSecondary) : root.colBase
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
        hoverTarget: eventArea
    }
}
