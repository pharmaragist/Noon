import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import qs.modules.common.bg
import qs.services
import qs.data

Rectangle {
    id: root

    required property LockContext context
    property alias blurredArt: backgroundImage
    color: "black"

    BlurredImage {
        id: backgroundImage
        z: 0
        anchors.fill: parent
        source: WallpaperService.currentWallpaper
        blur: true
    }

    Rectangle {
        z: 1
        anchors.fill: parent
        color: Colors.t(Colors.colScrim, 0.5)
    }

    LockProfilePicture {}

    LockBeam {
        id: beam
        context: root.context
    }
}
