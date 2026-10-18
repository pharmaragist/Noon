import QtQuick
import qs.common
import qs.common.widgets
import qs.services
import qs.assets.dino

Item {
    id: root
    anchors.fill: parent
    property alias focusItem: window.contentItem

    function getDepth(focus, fall = 1) {
        return focus ? 99 : fall;
    }

    AppLikeWindow {
        id: dino
        z: getDepth(dragHandler.drag.active, 1)
        title: "I'm A Fucking Dino"
        icon: "videogame_asset"
        width: 320
        height: 320
        draggable: true
        center: true
        x: Screen.width - dino.width - Sizes.hyprland.gapsOut;
        y: Screen.height - dino.height - Sizes.hyprland.gapsOut;
        contentItem: Dino {}
    }
}
