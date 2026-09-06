import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.services
import qs.data
import "../applets"

StyledRect {
    id: view
    readonly property alias focusItem: inputField
    readonly property string transcribedText: SpeechService?.speech
    color: "transparent"

    function sendMessage() {
        BeamData.executeCommand();
        BeamData.reset();
        hide();
        inputField.text = "";
    }

    Binding {
        target: inputField
        property: "text"
        value: transcribedText
    }

    Binding {
        target: BeamData
        property: "query"
        value: inputField.text
    }
    RowLayout {
        anchors.fill: parent
        anchors.topMargin: Padding.large
        anchors.bottomMargin: Padding.large

        spacing: Padding.normal

        PanelRect {
            Layout.fillHeight: true
            implicitSize: height
            radius: height / 2
            enableBorders: true

            Symbol {
                z: 999
                font.pixelSize: 24
                fill: 1
                animateChange: true
                color: inputField.focus ? Colors.colPrimary : Colors.colOnLayer3
                anchors.centerIn: parent
                text: BeamData.getIcon()
            }
        }

        PanelRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: height / 2
            enableBorders: true

            StyledTextField {
                id: inputField

                anchors.fill: parent
                anchors.leftMargin: Padding.huge
                anchors.rightMargin: Padding.huge

                z: 10
                focus: root.reveal
                placeholderText: BeamData.config?.placeholder ?? "Ask any thing ..."
                text: BeamData.query
                background: null
                selectionColor: Colors.colPrimaryContainer
                selectedTextColor: Colors.m3.m3onPrimaryContainer
                color: Colors.colOnLayer0
                placeholderTextColor: Colors.colSubtext
                selectByMouse: true
                leftPadding: Padding.large
                rightPadding: Padding.large
                font: Fonts.request("main", Fonts.sizes.large)

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.hide();
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                        view.sendMessage();
                        event.accepted = true;
                        break;
                    case Qt.Key_Tab:
                        const hint = BeamData.activeHint;
                        if (hint) {
                            BeamData.query = BeamData.autocomplete(hint);
                            event.accepted = true;
                        }
                        break;
                    default:
                        if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_S) {
                            root.takeScreenshot();
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        PanelRect {
            Layout.fillHeight: true
            radius: height / 2
            enableBorders: true
            implicitWidth: children[1]?.implicitWidth + Padding.silly
            AppletsFactory {
                id: appletsArea
                anchors.centerIn: parent
            }
        }
    }
}
