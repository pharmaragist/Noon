import qs.common
import qs.common.widgets
import qs.services
import qs.data
import QtQuick
import QtQuick.Layouts
import Quickshell

BarGroup {
    id: root

    property bool expanded: true
    implicitWidth: rowLayout.implicitWidth + Padding.massive

    RowLayout {
        id: rowLayout
        spacing: Padding.normal
        anchors.centerIn: parent

        MusicCoverArt {
            implicitSize: 45
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                font: Fonts.request("title", "normal")
                truncate: true
                color: Colors.colOnLayer1
                Layout.maximumHeight: 20
                Layout.fillWidth: true
                Layout.maximumWidth: 100
                horizontalAlignment: Text.AlignHCenter
                text: MediaPlayerService.title
            }
            StyledText {
                font: Fonts.request("title", "small")
                truncate: true
                Layout.maximumHeight: 20
                color: Colors.colSubtext
                Layout.fillWidth: true
                Layout.maximumWidth: 100
                text: MediaPlayerService.artist
            }
        }
    }

    MediaPopup {
        id: mediaPopup
        hoverTarget: mouse
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        hoverEnabled: true

        onPressed: event => {
            const activePlayer = MediaPlayerService.player;
            switch (event.button) {
            case Qt.MiddleButton:
            case Qt.BackButton:
                activePlayer.previous();
                break;
            case Qt.ForwardButton:
            case Qt.RightButton:
                activePlayer.next();
                break;
            case Qt.LeftButton:
                activePlayer.togglePlaying();
                break;
            }
        }
    }
}
