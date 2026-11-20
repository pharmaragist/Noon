import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

OsdPanel {
    id: root

    anchors {
        right: volumeMode
        left: !volumeMode
    }

    margins {
        left: Sizes.elevationMargin
        right: Sizes.elevationMargin
    }
    mask: Region {
        item: pill
    }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight + Sizes.elevationMargin * 2

    StyledRect {
        id: pill
        anchors.centerIn: parent

        implicitWidth: 55
        implicitHeight: 280

        enableBorders: true
        color: Colors.colLayer1
        radius: Rounding.full
        ColumnLayout {
            anchors.fill: parent
            spacing: 4

            Item {
                id: symbol

                Layout.fillWidth: true
                implicitHeight: width

                MaterialShape {
                    implicitSize: 35
                    rotation: 360 * value
                    anchors.centerIn: parent
                    color: root.value > 0 ? Colors.colPrimary : Colors.colLayer2
                    shape: MaterialShape.Shape.Cookie9Sided
                    Behavior on rotation {
                        Anim {}
                    }
                }

                Symbol {
                    fill: 1
                    text: root.icon
                    font.pixelSize: 16
                    anchors.centerIn: symbol
                    color: root.value > 0 ? Colors.colOnPrimary : Colors.colOnLayer2
                }
            }

            VStyledSlider {
                Layout.bottomMargin: Padding.massive
                Layout.alignment: Qt.AlignHCenter
                icon: "music_note"
                value: 1 - root.value
            }
        }
    }
}
