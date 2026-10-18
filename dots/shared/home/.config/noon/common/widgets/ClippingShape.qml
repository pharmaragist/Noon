import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import qs.common

Item {
    id: root
    property string source: ""
    property var shape: MaterialShape.Shape[_shape]
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
        color: root.toggled ? root.colors.colPrimary : root.colors.colLayer1

        Behavior on color {
            CAnim {}
        }

        Shape {
            anchors.centerIn: parent
            clip: true
            StyledImage {
                anchors.centerIn: parent
                source: root.source
                antialiasing: true
                implicitSize:root.implicitSize
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                antialiasing: true
                maskSource: Shape {}
            }
        }
    }

    component Shape: MaterialShape {
        _shape: root._shape
        shape: root.shape
        implicitSize: root.implicitSize - root.padding
        color: root.colors.colSecondaryContainer
    }
}
