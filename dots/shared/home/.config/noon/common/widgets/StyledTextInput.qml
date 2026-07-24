import QtQuick
import QtQuick.Controls
import qs.common

/**
 * Does not include visual layout, but includes the easily neglected colors.
 */
TextInput {
    renderType: Text.NativeRendering
    selectedTextColor: Colors.m3.m3onSecondaryContainer
    selectionColor: Colors.colSecondaryContainer

    font: Fonts.request("main", "small")

}
