import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets

StyledRect {
    id: root

    required property var modelData
    required property int index
    readonly property alias eventArea: eventArea
    property string title
    property string artist
    property string coverArt
    property bool isPlaylist
    property var action
    property bool listMode: false
    property int margins: listMode ? Padding.small : Padding.large
    readonly property real fontScale: listMode ? 1 : 0.9

    clip: true
    color: "transparent"
    colors: MediaPlayerService?.colors
    radius: listMode ? Rounding.large : Rounding.huge

    // topRadius: listMode ? (index === 0 ? Rounding.large : Rounding.verytiny) : Rounding.huge
    // bottomRadius: listMode ? (index === parent?.count - 1 ? Rounding.large : Rounding.verytiny) : Rounding.huge

    signal preview(url: string, x: int, y: int)

    MouseArea {
        id: eventArea
        z: 99
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        propagateComposedEvents: true
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        onClicked: event => {
            root.animate();
            if (action)
                action(event);
        }
    }

    StyledRect {
        id: footer
        z: 999
        clip: true

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.left: root.listMode ? coverArt.right : parent.left
        anchors.leftMargin: root.listMode ? Padding.small : 0
        leftRadius: root.listMode ? Rounding.verytiny : 0

        color: root.colors.colLayer2
        width: parent.width - 50
        height: !root.listMode ? 50 : parent.height
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Padding.veryhuge
            anchors.leftMargin: Padding.veryhuge
            spacing: Padding.huge
            implicitHeight: 50

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                StyledText {
                    font: Fonts.request("title", 18 * root.fontScale)
                    text: root.title
                    Layout.preferredHeight: 21
                    Layout.fillWidth: true
                    truncate: true
                    color: root.colors.colOnLayer0
                }

                StyledText {
                    font: Fonts.request("main", 14 * root.fontScale)
                    text: root.artist
                    Layout.fillWidth: true
                    Layout.preferredHeight: 21
                    truncate: true
                    opacity: 0.75
                    color: root.colors.colOnLayer0
                }
            }
            Symbol {
                visible: root.isPlaylist
                font.pixelSize: 20
                text: "list"
                color: root.colors.colOnLayer0
            }
        }
    }

    StyledRect {
        id: coverArt
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        implicitWidth: height
        leftRadius: listMode ? Rounding.large : 0
        rightRadius: listMode ? Rounding.verytiny : 0
        color: root.colors.colLayer2
        clip: true

        Symbol {
            text: "music_note"
            visible: !modelData.thumbnail
            anchors.centerIn: parent
            font.pixelSize: root.listMode ? 28 : 54
            color: root.colors.colSecondary
        }

        StyledImage {
            anchors.fill: parent
            source: Qt.resolvedUrl(root?.coverArt) || ""
            cache: true
        }
    }
    function animate() {
        feedAnim.running = true;
    }
    SequentialAnimation {
        id: feedAnim
        running: false
        NumberAnimation {
            target: root
            property: "scale"
            to: 0.94
            duration: 150
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: 200
        }
    }
}
