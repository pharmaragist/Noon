import QtQuick
import Quickshell
import qs.common
import qs.common.widgets

QuickToggleButton {
    id: root

    dialogName: "Transparency"
    buttonName: "Transparency"
    buttonSubtext: toggled ? "Clear" : "opaque"
    toggled: Mem.options.appearance.transparency.enabled
    buttonIcon: toggled ? "blur_on" : "blur_off"
    onClicked: Mem.options.appearance.transparency.enabled = !Mem.options.appearance.transparency.enabled
}
