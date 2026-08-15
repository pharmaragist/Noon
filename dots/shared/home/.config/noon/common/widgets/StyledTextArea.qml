import QtQuick
import QtQuick.Controls
import qs.common




TextArea {
    renderType: Text.NativeRendering
    selectedTextColor: Colors.m3.m3onSecondaryContainer
    selectionColor: Colors.colSecondaryContainer
    placeholderTextColor: Colors.m3.m3outline
    horizontalAlignment: Text.AlignLeft
    font: Fonts.request("main", "small")
}
