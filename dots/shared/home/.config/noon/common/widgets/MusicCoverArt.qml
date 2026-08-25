import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services

StyledRect {
    id: root

    radius: Rounding.large
    color: MediaPlayerService?.colors.colSecondaryContainer
    clip: true
    property alias source: coverImage.source
    property alias tintColor: coverImage.tintColor
    property alias tintLevel: coverImage.tintLevel
    property alias tint: coverImage.tint
    CroppedImage {
        id: coverImage

        z: 99
        tint: true
        tintLevel: 0.8
        tintColor: MediaPlayerService?.colors.colSecondaryContainer
        visible: true
        anchors.fill: parent
        sourceSize: Qt.size(root.implicitSize, root.implicitSize)
        source: MediaPlayerService.artUrl
        mipmap: true
        radius: root.radius
    }

    Symbol {
        z: 99
        visible: coverImage.status === Image.Null || coverImage.status === Image.Error
        anchors.centerIn: parent
        text: "music_note"
        font.pixelSize: (parent.height + parent.width) / 2 - Padding.verylarge
        color: MediaPlayerService?.colors.colSecondary
    }
}
