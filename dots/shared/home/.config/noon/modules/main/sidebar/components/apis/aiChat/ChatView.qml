import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.common.widgets

StyledRect {
    id: chatView
    clip: true
    color: "transparent"
    radius: Rounding.small

    property alias listView: messageListView

    ListView {
        id: messageListView
        z: 0
        anchors.fill: parent
        spacing: Padding.veryhuge
        reuseItems: true
        cacheBuffer: height * 2
        ScrollBar.vertical: StyledScrollBar {}
        property bool userScrolledUp: false
        onMovementStarted: userScrolledUp = !atYEnd
        onMovementEnded: userScrolledUp = !atYEnd
        // Wheel/keyboard scrolling doesn't emit movement signals, so track the end directly.
        onAtYEndChanged: userScrolledUp = !atYEnd
        // Stick to the live end only while the user is already there;
        // never yank while they read history.
        onCountChanged: {
            if (!userScrolledUp)
                positionViewAtEnd();
        }
        // Streaming text grows contentHeight per chunk: follow only when stuck to bottom.
        onContentHeightChanged: if (!userScrolledUp)
            positionViewAtEnd()

        // ScriptModel diffs values into incremental insert/remove/move ops —
        // a raw JS array as model would tear down every delegate on each new
        // array identity. (values must stay unique: ids are always fresh.)
        // Per-message content updates still flow through touchMessage()
        // changing messageByID identity instead of the model.
        model: ScriptModel {
            values: Harness.messageIDs.filter(id => Harness.messageByID[id]?.visibleToUser ?? true)
        }

        Keys.onPressed: event => {
            if (event.modifiers === Qt.NoModifier) {
                if (event.key === Qt.Key_PageUp) {
                    contentY = Math.max(0, contentY - height / 2);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageDown) {
                    contentY = Math.min(contentHeight - height, contentY + height / 2);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Home) {
                    contentY = 0;
                    userScrolledUp = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_End) {
                    positionViewAtEnd();
                    userScrolledUp = false;
                    event.accepted = true;
                }
            }
        }
        Behavior on contentY {
            enabled: false
        }
        delegate: Item {
            required property var modelData
            required property int index

            readonly property var msg: Harness.messageByID[modelData]
            readonly property Component userComp: UserMessage {
                messageIndex: index
                messageData: msg
                messageInputField: root.inputField
            }
            readonly property Component aiComp: AiMessage {
                messageIndex: index
                messageData: msg
                messageInputField: root.inputField
            }

            anchors.left: parent?.left
            anchors.right: parent?.right
            implicitHeight: loader?.implicitHeight

            Loader {
                id: loader
                anchors.left: parent.left
                anchors.right: parent.right
                sourceComponent: parent.msg?.role === "user" ? userComp : aiComp
            }
        }
    }

    PagePlaceholder {
        z: 2
        shown: Harness.messageIDs.length === 0
        icon: "cognition"
        shape: MaterialShape.Shape.PixelCircle
        iconSize: 120
    }

}
