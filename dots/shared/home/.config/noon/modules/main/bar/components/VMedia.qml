import qs.common
import qs.common.widgets
import qs.services
import qs.store
import QtQuick
import QtQuick.Layouts
import Quickshell

BarGroup {
    id: root

    property int discSize: barSize / 2
    Layout.fillWidth: true
    radius: Rounding.full
    Layout.preferredHeight: discSize
    Layout.preferredWidth: discSize

    Symbol {
        z: 0
        icon: "music_note"
        iconSize: 18
        color: Colors.colPrimary
        anchors.centerIn: parent
        visible: playerList.count === 0
    }

    ListView {
        id: playerList
        z: 1
        anchors.fill: parent
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - discSize) / 2
        preferredHighlightEnd: (width - discSize) / 2 + discSize
        clip: true
        spacing: Padding.massive
        highlightMoveDuration: 400
        maximumFlickVelocity: 2000
        flickDeceleration: 3500
        interactive: false
        model: MediaPlayerService.players

        delegate: Disc {
            required property var modelData
            required property int index
            player: modelData
            implicitSize: root.discSize
        }
    }

    MediaPopup {
        hoverTarget: listMouse
    }

    MouseArea {
        id: listMouse
        anchors.fill: parent
        z: 1000
        hoverEnabled: true
        scrollGestureEnabled: true
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        onPressed: event => {
            var player = playerList.model[playerList.currentIndex];
            if (!player)
                return;
            switch (event.button) {
            case Qt.MiddleButton:
            case Qt.BackButton:
                player.previous();
                break;
            case Qt.ForwardButton:
            case Qt.RightButton:
                player.next();
                break;
            case Qt.LeftButton:
                player.togglePlaying();
                break;
            }
        }
        onWheel: wheel => {
            var dx = wheel.angleDelta.x;
            var dy = wheel.angleDelta.y;
            if (Math.abs(dx) >= Math.abs(dy)) {
                if (dx < 0)
                    playerList.incrementCurrentIndex();
                else if (dx > 0)
                    playerList.decrementCurrentIndex();
            } else {
                var player = playerList.model[playerList.currentIndex];
                if (!player || !player.canControl)
                    return;
                var newValue = (player.volume ?? 0) + (dy / 120 * 0.05);
                player.volume = Math.max(0, Math.min(newValue, 1.0));
            }
            wheel.accepted = true;
        }
    }

    component Disc: StyledRect {
        id: root
        required property var player
        readonly property var colors: palette?.colors || Colors
        readonly property PaletteGenerator palette: MaterialColorsGenerator {
            active: true
            source: root.player?.trackArtUrl || ""
        }
        scale: index === playerList.currentIndex ? 1.0 : 0.75
        Behavior on scale {
            Anim {}
        }
        color: "transparent"
        radius: Rounding.full
        clip: true
        implicitSize: 30

        BlurredImage {
            z: 1
            blur: true
            tint: true
            blurMax: 30
            tintColor: root.colors.colPrimaryContainer
            source: root.player?.trackArtUrl ?? ""
            anchors.fill: parent
        }

        ClippedFilledCircularProgress {
            z: 1
            opacity: 0.6
            colPrimary: root.colors.colPrimary
            colSecondary: "transparent"
            value: MediaPlayerService.currentTrackProgressRatio(root.player)
            anchors.centerIn: parent
            implicitSize: root.implicitSize
        }

        Symbol {
            z: 2
            fill: 1
            anchors.centerIn: parent
            font.pixelSize: Math.round(root.implicitSize * 0.65)
            text: MediaPlayerService.isPlaying(root.player) ? "music_note" : "pause"
            color: root.colors.colLayer0
        }
    }
}
