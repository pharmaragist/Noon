import QtQuick
import qs.common

Item {
    id: root
    anchors.fill: parent
    implicitHeight: 300

    CurveEditor {
        id: curve
        property var store: Mem.options.appearance.animations
        anchors.fill: parent
        anchors.margins: -Padding.small
        color: "transparent"
        Component.onCompleted: this.setNodesFrom(store.userCurve)
        onCurveValuesChanged: if (!!store.userCurve && curveValues.length > 2)
            store.userCurve = this.curveValues
    }

    RippleButtonWithIcon {
        implicitSize: 22
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 6
        toggled: true
        materialIcon: "play_arrow"
        downAction: () => curve?.playPreview()
    }
}
