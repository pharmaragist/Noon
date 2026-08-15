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
    clip: true
    color: colors.colLayer2
    colors: BeatsService.colors

    topRadius: listMode ? (index === 0 ? Rounding.large : Rounding.tiny) : Rounding.huge
    bottomRadius: listMode ? (index === parent?.count - 1 ? Rounding.large : Rounding.tiny) : Rounding.huge

    signal preview(url: string, x: int, y: int)

    MouseArea {
        id: eventArea
        z: 99999
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        propagateComposedEvents: true
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        onClicked: {
            feedAnim.running = true;
            if (action)
                action();
        }
    }

    StyledRect {
        id: footer
        z: 999
        clip: true

        anchors.top: !root.listMode ? undefined : parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.left: root.listMode ? coverArt.right : parent.left

        color: root.colors.colLayer3
        width: parent.width - 50
        height: 45
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Padding.veryhuge
            anchors.leftMargin: Padding.veryhuge
            spacing: Padding.huge
            implicitHeight: 45
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: -Padding.tiny

                StyledText {
                    font: Fonts.request("title", Fonts.sizes.small)
                    text: root.title
                    Layout.fillWidth: true
                    truncate: true
                    color: root.colors.colOnLayer0
                }

                StyledText {
                    font.pixelSize: Fonts.sizes.verysmall
                    text: root.artist
                    Layout.fillWidth: true
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

    Item {
        id: coverArt
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        implicitWidth: height
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
