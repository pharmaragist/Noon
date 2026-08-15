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
        id: window
        z: getDepth(dragHandler.drag.active, 2)
        title: "Your words will be displayed here."
        icon: "transcribe"
        width: Sizes.beam.dictateWindow.width
        height: Sizes.beam.dictateWindow.height
        draggable: true
        center: true
        contentItem: StyledTextArea {
            readOnly: true
            font: Fonts.request("reading", 50)
            color: Colors.colOnSurfaceVariant
            text: SpeechService.speech.length > 0 ? SpeechService.speech : "Say Something ..."
            wrapMode: Text.Wrap
        }
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
