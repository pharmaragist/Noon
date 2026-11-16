import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.services
import qs.data
import "../applets"

ContentViewItem {
    id: view
    readonly property alias focusItem: inputField

    RowLayout {
        id: content
        width: Math.max(BeamData.activeHint?.length, inputField.text.length) > 18 ? 1000 : 450
        height: 70
        anchors.centerIn: parent
        spacing: Padding.normal

        function sendMessage() {
            BeamData.executeCommand();
            BeamData.reset();
            view.dismiss();
            inputField.text = "";
        }

        Binding {
            target: BeamData
            property: "query"
            value: inputField.text
        }

        Item {
            id: icon
            visible: Mem.options.beam.appearance?.enableEmblem ?? true
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.leftMargin: Padding.gigantic

            Symbol {
                z: 999
                font.pixelSize: 18
                fill: 1
                color: inputField.focus ? Colors.colOnPrimary : Colors.colOnLayer3
                anchors.centerIn: parent
                text: BeamData.getIcon()
            }

            MaterialShape {
                anchors.fill: parent
                implicitSize: 36
                color: inputField.focus ? Colors.colPrimary : Colors.colLayer3
                shape: BeamData.getShape()

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Globals.main.beam.reason = "hints"

                    StyledToolTip {
                        content: "Need Help ? Click for cheats"
                        extraVisibleCondition: parent.containsMouse
                    }
                }

                readonly property alias inputText: inputField.text

                Behavior on color {
                    CAnim {}
                }
            }
        }

        LayerRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Padding.normal
            Layout.bottomMargin: Padding.normal
            Layout.leftMargin: icon.visible ? Padding.small : Padding.gigantic
            colBackground: Colors.colLayer1
            radius: Rounding.full

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Padding.massive
                anchors.rightMargin: Padding.large
                spacing: Padding.small

                StyledTextField {
                    id: inputField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focus: root.reveal
                    placeholderText: BeamData.config?.placeholder ?? "Ask Me "
                    text: BeamData.query
                    background: null
                    selectionColor: Colors.colPrimaryContainer
                    selectedTextColor: Colors.m3.m3onPrimaryContainer
                    color: Colors.colOnLayer0
                    placeholderTextColor: Colors.colSubtext
                    selectByMouse: true
                    leftPadding: 0
                    rightPadding: 0
                    font: Fonts.request("main", "large")

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape:
                            view.dismiss();
                            event.accepted = true;
                            break;
                        case Qt.Key_Return:
                            content.sendMessage();
                            event.accepted = true;
                            break;
                        case Qt.Key_Tab:
                            const hint = BeamData.activeHint;
                            if (hint) {
                                BeamData.query = BeamData.autocomplete(hint);
                                event.accepted = true;
                            }
                            break;
                        }
                    }
                }

                AppletsFactory {
                    id: appletsArea
                    Layout.fillHeight: true
                }
            }
        }

        GroupButtonWithIcon {
            id: pinButton
            buttonRadius: width / 2
            iconSize: 22
            baseSize: 45
            animateIcon: true
            materialIcon: "push_pin"
            toggled: Globals.main.beam.pinned
            releaseAction: () => {
                Globals.main.beam.pinned = !Globals.main.beam.pinned
            }
        }

        GroupButtonWithIcon {
            id: sendButton
            Layout.rightMargin: Padding.large
            buttonRadius: width / 2
            toggled: BeamData.query.length > 0
            iconSize: 22
            baseSize: 45
            animateIcon: true
            materialIcon: "arrow_upward"
            colBackgroundToggled: Colors.colPrimaryContainer
            releaseAction: () => {
                content.sendMessage();
            }
        }
    }
}
