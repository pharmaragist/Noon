import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.services
import qs.store
import "../applets"

PanelRect {
    id: view
    readonly property alias focusItem: inputField
    readonly property string transcribedText: SpeechService?.speech

    function sendMessage() {
        BeamData.executeCommand();
        BeamData.reset();
        hide();
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

    Symbol {
        z: 999
        font.pixelSize: 18
        fill: 1
        color: inputField.focus ? Colors.colOnPrimary : Colors.colOnLayer3
        anchors.centerIn: icon
        text: BeamData.getIcon()
    }

    MaterialShape {
        id: icon
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: Padding.gigantic
        }
        implicitSize: 36
        color: inputField.focus ? Colors.colPrimary : Colors.colLayer3
        shape: BeamData.getShape()

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: Globals.main.beam.showCheats = !Globals.main.beam.showCheats
            cursorShape: Qt.PointingHandCursor

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
            running: BeamData.activeState !== BeamData.defaultState && inputField.text.length > 0
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 9000
            easing.type: Easing.Linear
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
        AppletsFactory {
            id: appletsArea
        }

        GroupButtonWithIcon {
            id: osrButton
            z: 999
            visible: false
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                rightMargin: Padding.large
            }
            buttonRadius: Rounding.silly
            releaseAction: () => root.takeScreenshot()
            colBackground: "transparent"
            materialIcon: "screenshot_region"
            baseSize: 40
            enabled: !ScreenShotService.isBusy
            
            Behavior on opacity {
                Anim {}
            }
        }
    }

    GroupButtonWithIcon {
        id: sendButton
        releaseAction: () => {
            SpeechService.listen();
            NoonUtils.callIpc("noon reveal_beam dictate");
        }
        buttonRadius: width / 2
        colBackground: BeamData.query.length > 0 ? Colors.colPrimaryContainer : Colors.colLayer1
        iconSize: 22
        baseSize: 45
        animateIcon: true
        materialIcon: BeamData.query.length === 0 && BeamData.activeState === "ai" ? "mic" : root.isResponding ? "stop" : "arrow_upward"

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
