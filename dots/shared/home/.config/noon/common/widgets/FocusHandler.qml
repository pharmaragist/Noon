import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common

Item {
    id: root

    property var windows: []
    property bool active: false
    signal cleared()

    Loader {
        id: grabLoader
        active: Compositor.isHyprland
        sourceComponent: Component {
            HyprlandFocusGrab {}
        }
        onLoaded: {
            item.windows = Qt.binding(() => root.windows);
            item.active = Qt.binding(() => root.active);
            if (item.cleared)
                item.cleared.connect(root.cleared);
        }
    }
}