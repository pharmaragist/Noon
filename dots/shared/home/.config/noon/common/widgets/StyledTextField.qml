import QtQuick
import QtQuick.Controls
import qs.common
import qs.common.widgets
import qs.common.functions

TextField {
    id: folderPathField
    readonly property var methods: TextUtils
    property var colors: Colors
    property alias radius: rect.radius
    property alias bg: rect
    placeholderTextColor: colors.colOnLayer1
    color: colors.colOnLayer1
    Keys.onEscapePressed: focus = false
    placeholderText: "Search..."
    selectionColor: colors.colSecondaryContainer
    selectedTextColor: colors.colOnSecondaryContainer
    selectByMouse: true

    font: Fonts.request("main", "small")

    background: StyledRect {
        id: rect

        color: colors.colLayer2
        radius: Rounding.large
    }
}
