import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import qs.common.widgets

StyledTextField {
    id: root

    property color colBackground: Colors.colLayer2
    property color colShape: Colors.colPrimary
    property color colPlaceholder: Colors.colOnLayer2
    property int radius: Rounding.verylarge
    property int shapeSize: 18
    property int shapeSizeActive: 34
    property real shakeX: 0

    readonly property int count: text.length
    readonly property var shapes: ["PuffyDiamond", "Cookie7Sided", "Clover4Leaf", "Gem", "Slanted", "PixelTriangle", "Cookie9Sided", "Oval", "Heart", "SoftBurst", "Cookie12Sided", "Arch", "Pill", "Sunny", "Ghostish", "Clover8Leaf", "Square", "Cookie4Sided", "Pentagon", "SoftBoom", "Triangle", "Boom", "Flower", "Diamond", "Puffy", "PixelCircle", "ClamShell", "VerySunny", "Bun", "Cookie6Sided", "SemiCircle", "Arrow", "Fan", "Burst"]

    function clear() {
        text = ""
    }

    function shake() {
        shakeAnim.restart()
    }

    function syncShapes() {
        const target = text.length
        while (shapeModel.count > target)
            shapeModel.remove(shapeModel.count - 1)
        while (shapeModel.count < target)
            shapeModel.append({ pop: shapeModel.count === target - 1 })
    }

    objectName: "passwordInput"
    echoMode: TextInput.Password
    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
    placeholderText: "Enter your password .."
    placeholderTextColor: colPlaceholder
    leftPadding: Padding.massive
    rightPadding: Padding.massive
    color: "transparent"
    selectionColor: "transparent"
    selectedTextColor: "transparent"
    selectByMouse: false
    persistentSelection: false
    cursorDelegate: Item {}
    clip: true

    onTextChanged: syncShapes()

    Keys.onEscapePressed: focus = false
    Keys.onPressed: event => {
        if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut))
            event.accepted = true
    }

    background: StyledRect {
        color: root.colBackground
        radius: root.radius
    }

    ListModel {
        id: shapeModel
    }

    Item {
        id: viewport
        z: 999
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Padding.massive
        height: root.shapeSizeActive
        clip: true
        transform: Translate {
            x: root.shakeX
        }

        Row {
            id: shapesRow
            height: parent.height
            spacing: Padding.small
            x: Math.min(0, viewport.width - width)

            Behavior on x {
                Anim {}
            }

            Repeater {
                model: shapeModel

                delegate: MaterialShape {
                    id: shape
                    required property int index
                    required property bool pop
                    anchors.verticalCenter: parent.verticalCenter
                    _shape: root.shapes[index % root.shapes.length]
                    implicitSize: pop ? 0 : root.shapeSize
                    color: root.colShape

                    Component.onCompleted: {
                        if (pop)
                            popAnim.start()
                    }

                    SequentialAnimation {
                        id: popAnim
                        NumberAnimation {
                            target: shape
                            property: "implicitSize"
                            to: root.shapeSizeActive
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: shape
                            property: "implicitSize"
                            to: root.shapeSize
                            duration: 240
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeX"; to: -12; duration: 50 }
        NumberAnimation { target: root; property: "shakeX"; to: 12; duration: 70 }
        NumberAnimation { target: root; property: "shakeX"; to: -8; duration: 60 }
        NumberAnimation { target: root; property: "shakeX"; to: 8; duration: 60 }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 50 }
    }
}
