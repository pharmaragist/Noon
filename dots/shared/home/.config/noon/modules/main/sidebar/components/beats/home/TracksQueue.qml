import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.functions
import qs.services

StyledRect {
    id: root

    z: 99
    topRadius: Rounding.massive
    color: colors.colLayer1
    colors: parent.colors
    clip: true

    property int moveSrc: -1
    property var moveSrcItem: null

    StyledListView {
        id: list
        radius: Rounding.huge
        hinter.color: root.color
        anchors.fill: parent
        anchors.margins: Padding.normal
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 250
        highlightMoveVelocity: -1
        keyNavigationEnabled: true
        focus: true
        currentIndex: model.findIndex(t => t?.title === BeatsService?.player?.trackTitle) ?? 0

        _model: BeatsService.queue

        highlight: Item {
            z: 2
            width: list.width
            height: 60
            StyledRect {
                anchors.left: parent.left
                anchors.leftMargin: Padding.huge
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                radius: 6
                width: 6
                color: root.colors.colPrimary
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (list.currentItem) {
                    let currentTrack = list.model[list.currentIndex];
                    if (currentTrack)
                        BeatsService.playTrackByFile(currentTrack.file);
                }
                event.accepted = true;
            }
        }

        delegate: StyledRect {
            required property var modelData
            required property int index

            anchors.right: parent?.right
            anchors.left: parent?.left
            height: 60
            color: root.moveSrc === index ? colors.colSecondaryContainer : "transparent"

            Rectangle {
                visible: index !== list.count - 1
                anchors.bottom: parent?.bottom
                anchors.left: parent?.left
                anchors.right: parent?.right
                anchors.leftMargin: Padding.massive
                anchors.rightMargin: Padding.massive
                height: 1
                color: colors.colOutline
            }

            RLayout {
                anchors.fill: parent
                anchors.rightMargin: Padding.normal
                anchors.leftMargin: Padding.normal
                spacing: Padding.massive

                Item {
                    height: 24
                    width: 6
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: modelData?.title
                        truncate: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        color: colors.colOnLayer2
                        font: Fonts.request("main", "normal")
                    }
                    StyledText {
                        text: modelData?.artist
                        truncate: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        color: colors.colSubtext
                        font: Fonts.request("main", "small")
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.moveSrc = index;
                        root.moveSrcItem = modelData;
                    } else if (root.moveSrc >= 0) {
                        if (root.moveSrc !== index && root.moveSrcItem)
                            BeatsService.moveQueueItemByMpdIdx(root.moveSrcItem.index, modelData.index);
                        root.moveSrc = -1;
                        root.moveSrcItem = null;
                    } else {
                        list.currentIndex = index;
                        BeatsService.playTrackByFile(modelData?.file);
                    }
                }
            }
        }
    }
}
