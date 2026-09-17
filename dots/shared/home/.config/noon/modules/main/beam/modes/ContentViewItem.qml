import QtQuick
import qs.common

Item {
    id: root

    default property var contentItem: root.data

    height: contentItem?.height
    width: contentItem?.width

    onContentItemChanged: if (!!contentItem) {
        contentItem.parent = root;
        contentItem.anchors.centerIn = root;
    }

    function dismiss() {
        // close only; reason resets below-screen, never a visible switch
        Globals.main.beam.show = false;
    }
}
