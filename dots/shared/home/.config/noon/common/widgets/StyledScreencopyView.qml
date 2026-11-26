import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

ScreencopyView {
    id: root
    paintCursor: false
    constraintSize: Qt.size(parent.width, parent.height)
    visible: true
    live: true
}
