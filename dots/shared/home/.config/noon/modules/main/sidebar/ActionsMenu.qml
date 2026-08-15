import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets

PopupWindow {
    id: root

    required property var panelWindow
    property string category: ""

    function show(cat, globalX, globalY) {
        category = cat;
        posX = globalX;
        posY = globalY;
        visible = true;
    }

    function hide() {
        visible = false;
    }

    property int posX: 0
    property int posY: 0

    grabFocus: true
    color: "transparent"

    anchor {
        window: root.panelWindow || null
        rect.x: root.posX
        rect.y: root.posY
        gravity: Edges.Top | Edges.Left
        edges: Edges.Top | Edges.Left
    }

    implicitWidth: bg.implicitWidth + Padding.massive * 2
    implicitHeight: bg.implicitHeight + Padding.massive * 2

    StyledRectangularShadow {
        target: bg
    }

    PanelRect {
        id: bg
        anchors {
            fill: parent
            margins: Padding.massive
        }
        implicitWidth: 200
        implicitHeight: 100
        enableBorders: true
        radius: Rounding.verylarge

        Item {
            anchors.fill: parent
            anchors.margins: Padding.small
            ButtonGroup {
                anchors.fill: parent
                Repeater {
                    model: ["open_in_new", "panel_right", "close"]
                    delegate: GroupButtonWithIcon {
                        materialIcon: modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitSize: 55
                    }
                }
            }
        }
    }
}
