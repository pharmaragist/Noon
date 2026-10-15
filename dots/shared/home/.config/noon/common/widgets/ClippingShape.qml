import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import qs.common

Item {
    id: root
    property string source: ""
    property var shape: MaterialShape.Shape.Cookie9Sided
    property string _shape: "Cookie9Sided"
    property bool toggled: true
    property int implicitSize: 46
    property color colPrimary: colors.colPrimary
    property color colSecondary: colors.colSecondary
    property var colors: Colors
    property int padding: 6
    implicitWidth: this.implicitSize
    implicitHeight: this.implicitSize

    Shape {
        id: shape
        anchors.centerIn: parent
        implicitSize: root.implicitSize
        color: root.toggled ? root.colors.colPrimary : "transparent"

        Behavior on color {
            CAnim {}
        }

        Shape {
            anchors.centerIn: parent
            clip: true
            StyledImage {
                anchors.fill: parent
                source: root.source
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: Shape {}
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 50
            shadowColor: "white"
        }
    }

    component Shape: MaterialShape {
        _shape: root._shape
        shape: root.shape
        implicitSize: root.implicitSize - root.padding
        color: root.colors.colSecondaryContainer
    }
}
