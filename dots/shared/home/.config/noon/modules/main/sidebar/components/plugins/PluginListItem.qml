import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.functions
import qs.data
import qs.services

StyledRect {
    id: root
    property string icon
    property string shape
    property string name
    property string group
    property string subtext
    property bool enabled
    color: Colors.m3.m3surfaceContainerHigh

    implicitHeight: 72
    anchors.right:parent?.right
    anchors.left:parent?.left

    MouseArea {
        anchors.fill: parent
        onClicked: stateSwitch.clicked()
    }


    RLayout {
        anchors.fill: parent
        anchors.margins:Padding.small
        anchors.leftMargin:Padding.huge
        anchors.rightMargin:Padding.huge

        MaterialShapeWrappedSymbol {
            id: shape
            text: root.icon
            iconSize: 18
            padding: 12
            shape: MaterialShape.Shape[root.shape]
        }

        spacing: Padding.large

        CLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                truncate: true
                text: root.name
                color: Colors.colOnLayer3
                font.pixelSize: Fonts.sizes.normal
                Layout.maximumWidth: 100
            }

            StyledText {
                truncate: true
                visible: text.length > 0
                text: root.subtext
                color: Colors.colSubtext
                font.pixelSize: Fonts.sizes.small
                Layout.maximumWidth: 100
            }
        }

        Spacer {}

        StyledSwitch {
            id: stateSwitch
            scale: 0.85
            checked: root.enabled
            onClicked: root.enabled ? PluginsManager.disable(root.group, root.name) : PluginsManager.enable(root.group, root.name)
        }

        GroupButtonWithIcon {
            buttonRadius: Rounding.verysmall
            implicitSize: 32
            colBackground: Colors.colError
            colSymbol: Colors.colOnError
            materialIcon: "delete"
            Layout.rightMargin: Padding.veryhuge
            releaseAction: () => PluginsManager.remove(root.group, root.name)
        }
    }
}
