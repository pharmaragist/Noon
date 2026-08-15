import QtQuick

import qs.common
import qs.common.widgets
import qs.common.functions

StyledRect {
    id: root
    property var window
    property var widgetData
    readonly property bool pinned: widgetData?.pin ?? false
    readonly property bool pill: widgetData?.pill ?? false
    readonly property string size: widgetData?.size ?? "normal"
    readonly property bool isSmall: size === "small"
    readonly property bool isNormal: size === "normal"
    readonly property bool isLarge: size === "large"
    readonly property bool isXLarge: size === "xlarge"
    readonly property Component currentComponent: root[root?.size]

    
    property Component small: null
    property Component normal: null
    property Component large: null
    property Component xlarge: null

    clip: true
    color: colors.colLayer2
    radius: (pill && isSmall) ? 99 : Rounding.huge
    onWidgetDataChanged: contentLoader.reload()

    StyledLoader {
        id: contentLoader
        anchors.fill: parent
        sourceComponent: root.currentComponent ?? null
        active: true
    }

    Symbol {
        z: 999
        font.pixelSize: 20
        visible: pinned
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Padding.large
        opacity: 0.6
        color: colors.colOnLayer0
        text: "push_pin"
        rotation: 45
    }
}
