import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import qs.services

Rectangle {
    
    

    id: root

    property bool isInput: true 
    property string placeholderText
    property string text: ""
    property var inputTextArea: isInput ? inputLoader.item : undefined
    readonly property string displayedText: isInput ? inputLoader.item.text : root.text.length > 0 ? outputLoader.item.text : ""
    default property alias actionButtons: actions.buttonsData

    signal inputTextChanged 

    Layout.fillWidth: true
    implicitHeight: Math.max(100, inputColumn.implicitHeight)
    color: isInput ? Colors.colLayer1 : Colors.colSurfaceContainer
    radius: Rounding.verylarge

    ColumnLayout {
        id: inputColumn

        anchors.fill: parent
        spacing: 0

        Loader {
            id: inputLoader

            active: root.isInput
            visible: root.isInput
            Layout.fillWidth: true

            
            sourceComponent: StyledTextArea {
                id: inputTextArea

                placeholderText: root.placeholderText
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                font: Fonts.request("main", Fonts.sizes.small)
                color: Colors.colOnLayer1
                padding: 15
                background: null
                onTextChanged: root.inputTextChanged()
            }
        }

        Loader {
            id: outputLoader

            active: !root.isInput
            visible: !root.isInput
            Layout.fillWidth: true

            
            sourceComponent: StyledText {
                id: outputTextArea

                padding: 15
                wrapMode: Text.Wrap
                font.pixelSize: Fonts.sizes.small
                color: root.text.length > 0 ? Colors.colOnLayer1 : Colors.colSubtext
                text: root.text.length > 0 ? root.text : root.placeholderText
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 10

            Loader {
                active: root.isInput
                visible: root.isInput
                Layout.leftMargin: 10

                sourceComponent: StyledText {
                    text: qsTr("%1 characters").arg(inputLoader.item.text.length)
                    color: Colors.colOnLayer1
                    font.pixelSize: Fonts.sizes.verysmall
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ButtonGroup {
                id: actions
            }
        }
    }
}
