import Noon.Utils
import QtQuick
import QtQuick.Layouts
import qs.common

Item {
    id: root
    z: 99999
    anchors.fill: parent
    implicitHeight: list.contentHeight + Padding.large
    readonly property var pData: parser.data
    readonly property TomlParser parser: TomlParser {
        path: Paths.wallpapers.matugenConfig
    }

    StyledListView {
        id: list
        anchors.fill: parent
        anchors.margins: Padding.large
        hint: false
        clip: true
        radius: Rounding.verytiny
        spacing: 4
        interactive: false
        model: parser.data

        delegate: Item {
            id: delegateRoot

            required property var modelData
            required property int index

            readonly property bool isEnabled: modelData?.enabled ?? false

            anchors.left: parent?.left
            anchors.right: parent?.right
            implicitHeight: contentLayout.implicitHeight + (Padding.normal * 2)

            RowLayout {
                id: contentLayout
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: Padding.normal
                }
                spacing: Padding.normal

                StyledText {
                    Layout.fillWidth: true
                    text: methods.camelCaseFromSnakeCase(delegateRoot.modelData?.name, true) ?? ""
                    font: Fonts.request("main", "large")
                    color: Colors.colOnSurface
                }

                StyledSwitch {
                    checked: delegateRoot.isEnabled
                    onToggled: {
                        parser.setTemplateEnabled(delegateRoot.index, checked);
                        parser.saveTemplates();
                    }
                }
            }
        }
    }
}
