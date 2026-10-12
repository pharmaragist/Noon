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
    property bool wasUnlocking: false
    property bool failing: false
    implicitHeight: 100
    implicitWidth: parent?.width

    anchors {
        bottom: parent.bottom
        horizontalCenter: parent.horizontalCenter
        bottomMargin: -60 + Sizes.elevationMargin
    }

    Connections {
        target: root.context

        function onUnlockInProgressChanged() {
            const inProgress = root.context.unlockInProgress;
            if (!inProgress && root.wasUnlocking) {
                root.failing = true;
                inputField.shake();
                failTimer.restart();
            }
            root.wasUnlocking = inProgress;
        }
    }

    Timer {
        id: failTimer
        interval: 320
        onTriggered: {
            inputField.clear();
            root.failing = false;
            inputField.forceActiveFocus();
        }
    }

    StyledRect {
        id: bg

        z: 99
        implicitHeight: 70
        implicitWidth: 600
        radius: Rounding.full
        color: Colors.colLayer0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Padding.huge
            anchors.rightMargin: Padding.huge
            spacing: Padding.large

            Item {
                id: icon
                implicitWidth: 42
                implicitHeight: 42
                Layout.alignment: Qt.AlignVCenter
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
                    font: Fonts.request("title", 18, {
                        weight: 900
                    })
                }
            }

            M3PasswordTextEntry {
                id: inputField
                enabled: !root.context.unlockInProgress && !root.failing
                leftPadding: Padding.massive * 1.5
                rightPadding: Padding.massive * 1.5
                inputMethodHints: Qt.ImhSensitiveData
                onAccepted: root.context.tryUnlock()
                onTextChanged: root.context.currentText = this.text
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.margins: Padding.large
                Layout.leftMargin: 0
                Layout.rightMargin: 0

                shapeSize: 24
                shapeSizeActive: 40

                Connections {
                    function onCurrentTextChanged() {
                        inputField.text = root.context.currentText;
                    }

                    target: root.context
                }
            }
            ButtonGroup {
                Repeater {
                    id: rptr
                    model: [
                        {
                            icon: "logout",
                            releaseAction: () => NoonUtils.execDetached(["loginctl", "kill-user", Quickshell.env("USER")])
                        },
                        {
                            icon: "restart_alt",
                            releaseAction: () => NoonUtils.execDetached(["systemctl", "reboot"])
                        },
                        {
                            icon: "power_settings_new",
                            releaseAction: () => NoonUtils.execDetached(["systemctl", "poweroff"])
                        },
                    ]
                    delegate: GroupButtonWithIcon {
                        required property var modelData
                        required property int index
                        buttonRadius: height / 2
                        materialIcon: modelData?.icon
                        implicitSize: 45
                        iconSize: 18
                        onClicked: modelData.releaseAction()
                    }
                }
            }

            GroupButtonWithIcon {
                id: enter
                buttonRadius: height / 2
                materialIcon: "arrow_upward"
                enabled: !root.context.unlockInProgress && !root.failing
                toggled: inputField.text.length > 0
                implicitSize: 45
                releaseAction: () => root.context.tryUnlock()
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
