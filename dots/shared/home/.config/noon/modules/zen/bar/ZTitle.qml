import qs.services
import qs.common
import qs.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland

StyledText {
    required property var bar
    readonly property var monitor: Compositor.monitorFor(bar?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    color: Colors.colOnLayer3
    font.bold: true
    font.pixelSize: Fonts.sizes.large
    font.family: Fonts.family.monospace
    text: activeWindow?.appId ?? ""
}
