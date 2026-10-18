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

    Item {
        id: content
        width: Math.max(BeamData.activeHint?.length, inputField.text.length) > 18 ? 1000 : 375
        height: 70
        anchors.centerIn: parent
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
            implicitWidth: visible ? 36 : 0

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: visible ? Padding.gigantic : 0
            }

            Symbol {
                z: 999
                font.pixelSize: 18
                fill: 1
                color: inputField.focus ? Colors.colOnPrimary : Colors.colOnLayer3
                anchors.centerIn: parent
                text: BeamData.getIcon()
            }
            MaterialShape {
                anchors.centerIn: parent
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
                onInputTextChanged: if (inputField.text.length === 0)
                    rotation = 0

                Behavior on color {
                    CAnim {}
                }

                RotationAnimation on rotation {
                    running: inputField.text.length > 0
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 9000
                    easing.type: Easing.Linear
                }
            }
        }

        LayerRect {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: icon.right
                right: sendButton.left
                leftMargin: Padding.huge
                rightMargin: Padding.small
                margins: Padding.normal
            }
            colBackground: Colors.colLayer1
            radius: Rounding.full

            StyledTextField {
                id: inputField
                anchors.fill: parent
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
                leftPadding: Padding.massive
                rightPadding: Padding.massive + (appletsArea?.implicitWidth ?? 100)
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

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    right: parent.right
                    rightMargin: Padding.large
                }
            }
        }

        GroupButtonWithIcon {
            id: sendButton
            releaseAction: () => {
                content.sendMessage();
            }
            buttonRadius: width / 2
            colBackground: BeamData.query.length > 0 ? Colors.colPrimaryContainer : Colors.colLayer1
            iconSize: 22
            baseSize: 45
            animateIcon: true
            materialIcon: "arrow_upward"

            anchors {
                right: parent.right
                rightMargin: Padding.large
                verticalCenter: parent.verticalCenter
            }

            Behavior on opacity {
                Anim {}
            }
        }
    }
}
