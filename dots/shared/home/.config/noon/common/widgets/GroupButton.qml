import qs.common
import qs.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets

Button {
    id: root
    property bool toggled
    property string buttonText
    property real buttonRadius: Rounding.small ?? 8
    property real buttonRadiusPressed: Rounding.small ?? 6
    property var downAction
    property var releaseAction
    property var altAction
    property var holdAction
    property var middleClickAction
    property bool bounce: true
    property int buttonTextPadding: Padding.small
    property real baseSize: -1
    property real baseWidth: baseSize > 0 ? baseSize : (contentItem?.contentWidth ?? contentItem.implicitWidth) + horizontalPadding
    property real baseHeight: baseSize > 0 ? baseSize : (contentItem?.contentHeight ?? contentItem.implicitHeight) + verticalPadding
    property real clickedWidth: (parentGroup?.vertical ?? false) ? baseWidth : baseWidth + 20
    property real clickedHeight: (parentGroup?.vertical ?? false) ? baseHeight + 20 : baseHeight
    property var parentGroup: root.parent
    property int clickIndex: parentGroup?.clickIndex ?? -1
    Layout.fillWidth: (clickIndex - 1 <= parentGroup.children.indexOf(root) && parentGroup.children.indexOf(root) <= clickIndex + 1)
    Layout.fillHeight: (clickIndex - 1 <= parentGroup.children.indexOf(root) && parentGroup.children.indexOf(root) <= clickIndex + 1)
    implicitWidth: (root.down && bounce) ? clickedWidth : baseWidth
    implicitHeight: (root.down && bounce) ? clickedHeight : baseHeight
    property var colors: Colors
    property int layerNumber: 1
    readonly property string colorName: "colLayer" + layerNumber
    property color colBackground: colors[(colorName + "Hover")] ?? "transparent"
    property color colBackgroundHover: colors[(colorName + "Hover")] ?? "#E5DFED"
    property color colBackgroundActive: colors[(colorName + "Active")] ?? "#D6CEE2"
    property color colBackgroundToggled: colors.colPrimary ?? "#65558F"
    property color colBackgroundToggledHover: colors.colPrimaryHover ?? "#77699C"
    property color colBackgroundToggledActive: colors.colPrimaryActive ?? "#D6CEE2"

    property real radius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property real leftRadius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property real rightRadius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property color color: root.enabled ? (root.toggled ? (root.down ? colBackgroundToggledActive : root.hovered ? colBackgroundToggledHover : colBackgroundToggled) : (root.down ? colBackgroundActive : root.hovered ? colBackgroundHover : colBackground)) : colBackground

    onDownChanged: {
        if (root.down && root.parent.clickIndex !== undefined) {
            root.parent.clickIndex = parent.children.indexOf(root);
        }
    }

    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }

    Behavior on leftRadius {
        Anim {}
    }
    Behavior on rightRadius {
        Anim {}
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressAndHold: root.holdAction()
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: event => {
            NoonUtils.playSound("task_added");
            if (event.button === Qt.RightButton) {
                if (root.altAction)
                    root.altAction();
                return;
            }
            if (event.button === Qt.MiddleButton) {
                if (root.middleClickAction)
                    root.middleClickAction();
                return;
            }
            root.down = true;
            if (root.downAction)
                root.downAction();
        }
        onReleased: event => {
            root.down = false;
            if (event.button != Qt.LeftButton)
                return;
            if (root.releaseAction)
                root.releaseAction();
            root.click();
        }
        onCanceled: event => {
            root.down = false;
        }
    }

    background: Rectangle {
        id: buttonBackground
        topLeftRadius: root.leftRadius
        topRightRadius: root.rightRadius
        bottomLeftRadius: root.leftRadius
        bottomRightRadius: root.rightRadius
        implicitHeight: 50

        color: root.color
        Behavior on color {
            CAnim {}
        }
    }

    contentItem: StyledText {
        leftPadding: root.buttonTextPadding
        text: root.buttonText
        color: root.toggled ? colors.colOnPrimary : colors.colOnLayer1
    }
}
