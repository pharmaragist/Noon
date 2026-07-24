import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.common.functions

StyledRect {
    id: root
    property var account: AuthManager.oauthData[0]?.account ?? {}
    color: "transparent" // Colors.colLayer2
    radius: Rounding.verylarge

    Layout.fillWidth: true
    height: 80

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        // anchors.leftMargin: Padding.veryhuge
        // anchors.rightMargin: Padding.veryhuge
        anchors.verticalCenter: parent.verticalCenter
        spacing: Padding.huge

        StyledRect {
            implicitSize: 70
            color: Colors.colLayer1
            radius: Rounding.full
            clip: true

            StyledRect {
                z: 99999
                anchors.fill: parent
                color: Colors.colScrim
                opacity: hA.containsMouse ? 0.65 : 0

                Symbol {
                    z: 1
                    icon: "camera_alt"
                    iconSize: 26
                    anchors.centerIn: parent
                }
            }

            CroppedImage {
                z: 1
                anchors.fill: parent
                visible: account.image.length > 0
                source: account?.image
            }

            Symbol {
                z: 0
                // visible: !FileUtils.exists(account.image)
                anchors.centerIn: parent
                font.pixelSize: 30
                color: Colors.colPrimary
                fill: 1
                icon: "person"
            }

            MouseArea {
                id: hA
                z: 999
                anchors.fill: parent
                hoverEnabled: true
                onClicked: NoonUtils.execDetached([Directories.scriptsDir + "/set_face.sh"])
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft
            spacing: 0
            StyledText {
                truncate: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: StringUtils.capitalizeFirstLetter(account.name)
                color: Colors.colOnLayer2
                font: Fonts.request("title", "huge")
            }

            StyledText {
                truncate: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: account.handler
                color: Colors.colSubtext
                font: Fonts.request("title", "small")
            }
        }
    }
}
