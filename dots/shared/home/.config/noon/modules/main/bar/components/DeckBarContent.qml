import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets
import "./../components"

Item {
    id: root
    required property var panel

    anchors {
        fill: parent
        rightMargin: Padding.massive
        leftMargin: Padding.massive
    }
    TaskBar {
        anchors.centerIn: parent
        height: parent.height * 0.8
    }

    RLayout {
        anchors.fill: parent
        spacing: Padding.large

        Logo {}

        HSeparator {}

        ActiveWindow {}

        Spacer {}

        Media {
            visible: MediaPlayerService.players.length > 0
        }

        GP {
            Layout.alignment: Qt.AlignRight
            implicitWidth: rLay.implicitWidth + Padding.massive * 2
            RSLayout {
                id: rLay
                SysTray {
                    bar: root.panel
                }
                StatusIcons {}
                HSeparator {}
                Clock {}
            }
        }
    }

    component Clock: StyledText {
        Layout.alignment: Qt.AlignRight
        text: DateTimeService.time
        color: Colors.colOnLayer1
        font: Fonts.request("main", "normal")

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: NoonUtils.callIpc("sidebar reveal Notifs")
        }
    }

    component RSLayout: RLayout {
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        spacing: Padding.large
    }

    component GP: StyledRect {
        Layout.minimumWidth: 100
        Layout.topMargin: Padding.normal
        Layout.bottomMargin: Padding.normal
        Layout.fillHeight: true
        color: Colors.colLayer2
        radius: Rounding.verylarge
    }
}
