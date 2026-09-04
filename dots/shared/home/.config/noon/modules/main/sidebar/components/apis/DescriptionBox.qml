import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root

    property alias text: tagDescriptionText.text
    property bool showArrows: true
    property bool showTab: true

    visible: tagDescriptionText.text.length > 0
    Layout.fillWidth: true
    implicitHeight: tagDescriptionBackground.implicitHeight

    Rectangle {
        id: tagDescriptionBackground

        color: Colors.colLayer2
        anchors.fill: parent
        radius: Rounding.huge
        implicitHeight: Math.max(40, Padding.large + descriptionRow.implicitHeight * 2)

        RowLayout {
            id: descriptionRow
            spacing: Padding.large

            anchors {
                fill: parent
                leftMargin: Padding.massive
                rightMargin: Padding.massive
            }

            StyledText {
                id: tagDescriptionText

                Layout.fillWidth: true
                font: Fonts.request("main", "normal")
                color: Colors.colOnLayer2
                wrapMode: Text.Wrap
            }

            KeyboardKey {
                visible: root.showArrows
                key: "↑"
            }

            KeyboardKey {
                visible: root.showArrows
                key: "↓"
            }

            StyledText {
                visible: root.showArrows && root.showTab
                text: qsTr("or")
                font: Fonts.request("main", "normal")
            }

            KeyboardKey {
                id: tagDescriptionKey

                visible: root.showTab
                key: "Tab"
                horizontalPadding: Padding.huge
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
