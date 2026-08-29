import qs.services
import qs.common
import qs.common.widgets
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root
    clip: true
    visible: repeater?.count > 1
    radius: Rounding.full
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: Math.max(iconSize * 2, playerSelector.width + Padding.massive)
    implicitHeight: Math.min(48, iconSize * 1.5)
    Layout.bottomMargin: -10
    color: root.colors.colLayer2

    property var colors: MediaPlayerService?.colors
    readonly property int iconSize: 24

    Rectangle {
        id: activeIndicator
        z: 1
        implicitHeight: iconSize
        implicitWidth: iconSize
        anchors.verticalCenter: parent.verticalCenter
        radius: Rounding.full
        color: colors.colPrimary

        readonly property int selectedIndex: MediaPlayerService?.selectedPlayerIndex ?? 0

        x: {
            repeater.count;
            const item = repeater.itemAt(selectedIndex);
            return playerSelector.x + (item ? item.x : 0);
        }

        Behavior on x {
            enabled: repeater.count > 1
            Anim {}
        }

        SequentialAnimation {
            id: stretchAnim
            Anim {
                target: activeIndicator
                property: "width"
                to: iconSize * 1.5
                duration: Animations.durations.verysmall
            }
            Anim {
                target: activeIndicator
                property: "width"
                to: iconSize
                duration: Animations.durations.large
            }
        }

        onSelectedIndexChanged: {
            if (repeater.count > 1)
                stretchAnim.restart();
        }
    }

    RLayout {
        id: playerSelector
        anchors.centerIn: parent
        z: 2
        spacing: Padding.verysmall

        Repeater {
            id: repeater
            model: MediaPlayerService?.players

            delegate: Item {
                id: symbolItem
                required property var modelData
                required property int index
                readonly property bool isSelected: index === activeIndicator.selectedIndex
                height: iconSize
                width: iconSize

                Symbol {
                    anchors.centerIn: parent
                    fill: 1
                    font.pixelSize: 16
                    text: MediaPlayerService.getIconForPlayer(modelData)
                    color: symbolItem.isSelected ? root.colors.colOnPrimary : root.colors.colOnLayer2
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: MediaPlayerService.selectedPlayerIndex = index
                    StyledToolTip {
                        extraVisibleCondition: parent.containsMouse
                        content: modelData?.identity ?? modelData.desktopEntry
                    }
                }
            }
        }
    }
}
