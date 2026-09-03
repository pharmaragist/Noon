import QtQuick
import qs.data
import qs.common
import qs.common.widgets

StyledRect {
    id: root
    required property string cat
    property var catInfo: SidebarData._get(cat)
    clip: true
    anchors.fill: parent
    color: "transparent"
    radius: Rounding.verylarge

    Item {
        z: 1
        anchors.fill: parent
        layer.enabled: true
        layer.effect: StyledFastBlur {}
    }

    MaterialShapeWrappedSymbol {
        id: shape
        visible: !!text
        z: 999
        anchors.centerIn: parent
        text: catInfo?.icon ?? ""
        iconSize: 128
        padding: 30
        shape: MaterialShape.Shape[catInfo?.shape]
    }
}
