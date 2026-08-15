import qs.services
import qs.common
import qs.common.widgets
import QtQuick
import QtQuick.Layouts
StyledRect {
    id: button
    property string day
    property int isToday
    property bool bold
    property bool hasEvents: false
    property string dateString
    property var releaseAction
    property var window
    property var getTasksOfDate
    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitSize: 24
    color: (isToday === 1) ? Colors.colPrimary : (hoverArea.containsMouse ? Colors.colSurfaceContainerHigh : "transparent")
    radius: Rounding.normal
    Behavior on color {
        CAnim {}
    }
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.releaseAction()
    }
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 1
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: button.day
            horizontalAlignment: Text.AlignHCenter
            color: (isToday === 1) ? Colors.m3.m3onPrimary : (isToday === 0) ? Colors.colOnLayer1 : Colors.colOutlineVariant
            font: Fonts.request("main", Fonts.sizes.verysmall, { weight: bold ? 800 : 500 })
        }
        Item {
            visible: button.hasEvents && isToday !== -1
            implicitWidth: 3
            implicitHeight: 3
            Layout.alignment: Qt.AlignHCenter
            Rectangle {
                anchors.fill: parent
                radius: Rounding.full
                color: (isToday === 1) ? Colors.m3.m3onPrimary : Colors.colPrimary
            }
        }
    }
    StyledPopupPanel {
        hoverTarget: hoverArea
        window: button.window
        ColumnLayout {
            spacing: Padding.large
            StyledText {
                Layout.preferredHeight: 45
                leftPadding: Padding.huge
                text: button.day + " Events."
                color: Colors.colOnLayer0
                font.pixelSize: Fonts.sizes.huge
            }
            ItemSeparator {}
                ColumnLayout {
                    spacing: Padding.tiny
                    Repeater {
                        id: tasksRepeater
                        model: ScriptModel {
                            values: button.getTasksOfDate ? button.getTasksOfDate(button.dateString) : []
                        }
                        delegate: ColumnLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        RowLayout {
                            Layout.fillWidth: true
                            StyledRadioButton {}
                            StyledText {
                                text: modelData.content
                                Layout.fillWidth: true
                                truncate: true
                            }
                        }
                        ItemSeparator {}
                    }
                }
            }
        }
    }
    component ItemSeparator: Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.leftMargin: Padding.massive
        Layout.rightMargin: Padding.massive
        visible: index !== tasksRepeater.count - 1
        color: Colors.colLayer3
        radius: 6
        height: 1
    }
}
