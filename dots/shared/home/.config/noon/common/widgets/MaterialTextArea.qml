import QtQuick.Controls.Material
import QtQuick
import QtQuick.Controls
import qs.common






TextArea {
    id: root

    Material.theme: Material[Colors.mode]
    Material.accent: Colors.m3.m3primary
    Material.primary: Colors.m3.m3primary
    Material.background: Colors.m3.m3surface
    Material.foreground: Colors.m3.m3onSurface
    Material.containerStyle: Material.Filled
    renderType: Text.QtRendering
    selectedTextColor: Colors.m3.m3onSecondaryContainer
    selectionColor: Colors.colSecondaryContainer
    placeholderTextColor: Colors.m3.m3outline
    wrapMode: TextEdit.Wrap
    font: Fonts.request("main", "small", {
        hintingPreference: Font.PreferFullHinting
    })
    background: Rectangle {
        implicitHeight: 56
        color: Colors.m3.m3surface
        topLeftRadius: 4
        topRightRadius: 4

        Rectangle {
            height: 1
            color: root.focus ? Colors.m3.m3primary : root.hovered ? Colors.m3.m3outline : Colors.m3.m3outlineVariant

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
