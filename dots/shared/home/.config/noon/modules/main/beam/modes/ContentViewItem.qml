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
        Globals.main.beam.show = false;
        Globals.main.beam.reason = "default";
    }
}
