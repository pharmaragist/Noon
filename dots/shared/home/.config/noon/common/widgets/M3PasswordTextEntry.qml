import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import qs.common.widgets





StyledTextField {
    id: root
    property color colBackground: Colors.colLayer2
    property color colText: Colors.colOnLayer2
    property color colSelectionColor: Colors.colSecondaryContainer
    property color colSelectionText: Colors.colOnSecondaryContainer
    property int radius: Rounding.verylarge
    color: "transparent"
    objectName: "searchInput"
    placeholderText: "Enter Your Password .. "
    selectionColor: "transparent"
    selectedTextColor: "transparent"
    selectByMouse: true
    font.pixelSize: 0
    clip: true
    Keys.onEscapePressed: focus = false
    background: StyledRect {
        color: root.colBackground
        radius: root.radius
    }
    RowLayout {
        id: shapesRow
        z: 999
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        anchors.margins: Padding.massive
        spacing: Padding.small
        readonly property int count: root.text.length
        readonly property var shapes: ["PuffyDiamond", "Cookie7Sided", "Clover4Leaf", "Gem", "Slanted", "PixelTriangle", "Cookie9Sided", "Oval", "Heart", "SoftBurst", "Cookie12Sided", "Arch", "Pill", "Sunny", "Ghostish", "Clover8Leaf", "Square", "Cookie4Sided", "Pentagon", "SoftBoom", "Triangle", "Boom", "Flower", "Diamond", "Puffy", "PixelCircle", "ClamShell", "VerySunny", "Bun", "Cookie6Sided", "SemiCircle", "Arrow", "Fan", "Burst"]

        Repeater {
            id: shapeRepeater
            model: ScriptModel {
                values: root.text
            }
            delegate: MaterialShape {
                required property var modelData
                required property int index
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                _shape: shapesRow.shapes[index]
                implicitSize: (index === shapesRow?.count ?? false) ? 34 : 18
                color: Colors.colPrimary
                Behavior on implicitSize {
                    Anim {}
                }
            }
        }
        Spacer {}
    }
}
