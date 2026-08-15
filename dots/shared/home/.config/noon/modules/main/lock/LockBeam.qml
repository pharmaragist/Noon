import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root
    z: 999
    required property var context
    implicitHeight: 65
    implicitWidth: Sizes.beam.normal.width

    anchors {
        bottom: parent.bottom
        horizontalCenter: parent.horizontalCenter
        bottomMargin: -60 + Sizes.elevationMargin
    }

    StyledRect {
        id: bg

        z: 99
        implicitHeight: 65
        implicitWidth: Sizes.beam.normal.width
        radius: Rounding.full
        color: Colors.colLayer0
        
        anchors.centerIn: parent

        Item {
            id: icon
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: Padding.massive
            }
            implicitWidth: 40

            MaterialShape {
                z: 999
                implicitSize: 42
                _shape: "Cookie9Sided"
                anchors.centerIn: parent

                readonly property string inputText: inputField.text

                color: inputField.focus ? Colors.colPrimary : Colors.colLayer3
                onInputTextChanged: if (inputField.text.length === 0)
                    rotation = 0

                RotationAnimation on rotation {
                    running: inputField.text.length > 0
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 9000
                    easing.type: Easing.Linear
                }
                Behavior on color {
                    CAnim {}
                }
                Behavior on rotation {
                    Anim {}
                }
            }

            StyledText {
                z: 999
                anchors.centerIn: parent
                color: inputField.focus ? Colors.colOnPrimary : Colors.colOnLayer0
                animateChange: true
                text: HyprlandService.keyboardLayoutShortName
                font: Fonts.request("title", 18)
            }
        }

        M3PasswordTextEntry {
            id: inputField
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: enter.left
                left: icon.right
                rightMargin: Padding.small
                leftMargin: Padding.large
                margins: Padding.normal
            }
            enabled: !root.context.unlockInProgress
            leftPadding: Padding.massive * 1.5
            rightPadding: Padding.massive * 1.5
            inputMethodHints: Qt.ImhSensitiveData
            onAccepted: root.context.tryUnlock()
            onTextChanged: root.context.currentText = this.text

            Connections {
                function onCurrentTextChanged() {
                    inputField.text = root.context.currentText;
                }

                target: root.context
            }
        }

        GroupButtonWithIcon {
            id: enter
            buttonRadius: height / 2
            materialIcon: "arrow_upward"
            enabled: !root.context.unlockInProgress
            toggled: inputField.text.length > 0
            implicitSize: 45
            releaseAction: () => {
                root.context.tryUnlock();
            }

            anchors {
                right: parent.right
                rightMargin: Padding.normal
                verticalCenter: parent.verticalCenter
            }
        }
    }
    Anim on anchors.bottomMargin {
        from: -implicitHeight
        to: Sizes.elevationMargin
    }

    StyledRectangularShadow {
        target: bg
        transparency: 0.85
    }
}
