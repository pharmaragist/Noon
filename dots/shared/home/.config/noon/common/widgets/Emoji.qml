import QtQuick
import qs.common

StyledText {
    id: root
    property alias icon: root.text
    property real iconSize: Fonts.sizes.small ?? 16
    property real fill: 0
    property real truncatedFill: fill.toFixed(1)

    property var variableAxes: {
        "FILL": truncatedFill,
        "opsz": iconSize
    }
    renderType: Text.NativeRendering

    font {
        hintingPreference: Font.PreferNoHinting
        family: Fonts.family.emoji
        pixelSize: iconSize
        
        
    }

    Behavior on opacity {
        Anim {}
    }

    Behavior on fill {
        Anim {}
    }
}
