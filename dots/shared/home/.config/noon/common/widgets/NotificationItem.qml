import qs.common
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    property var notificationObject
    property bool expanded: false
    property bool onlyNotification: false
    property bool popup: false
    property real fontSize: Fonts.sizes.small
    property real padding: onlyNotification ? 0 : 8
    property real dragConfirmThreshold: 70
    property real dismissOvershoot: notificationIcon.implicitWidth + 20

    readonly property var qmlParent: parent?.parent ?? null
    readonly property int dragIndexDiff: Math.abs((qmlParent?.dragIndex ?? -1) - index)
    readonly property real dragDistance: qmlParent?.dragDistance ?? 0
    readonly property real xOffset: {
        if (dragIndexDiff === 0) return Math.max(0, dragDistance);
        if (dragDistance > dragConfirmThreshold) return 0;
        if (dragIndexDiff === 1) return Math.max(0, dragDistance * 0.3);
        if (dragIndexDiff === 2) return Math.max(0, dragDistance * 0.1);
        return 0;
    }
    readonly property string formattedBody: {
        const body = notificationObject?.body ?? "";
        const app = (notificationObject?.appName || notificationObject?.summary || "").toLowerCase();
        const browsers = ["brave", "chrome", "chromium", "vivaldi", "opera", "microsoft edge"];

        if (browsers.some(b => app.includes(b))) {
            const lines = body.split("\n\n");
            if (lines.length > 1 && lines[0].startsWith("<a"))
                return lines.slice(1).join("\n\n").replace(/\n/g, "<br/>");
        }
        return body.replace(/\n/g, "<br/>");
    }

    implicitHeight: background.implicitHeight

    function destroyWithAnimation() {
        qmlParent?.resetDrag();
        background.anchors.leftMargin = background.anchors.leftMargin;
        destroyAnimation.start();
    }

    SequentialAnimation {
        id: destroyAnimation
        Anim {
            target: background.anchors
            property: "leftMargin"
            to: root.width + root.dismissOvershoot
        }
        onFinished: root.popup
            ? Notifications.omitNotification(notificationObject.notificationId)
            : Notifications.dismissNotification(notificationObject.notificationId)
    }

    DragManager {
        id: dragManager
        anchors.fill: root
        anchors.leftMargin: root.expanded ? -notificationIcon.implicitWidth : 0
        interactive: root.expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.destroyWithAnimation();
        }
        onDraggingChanged: {
            if (dragging && root.qmlParent)
                root.qmlParent.dragIndex = root.index ?? root.parent.children.indexOf(root);
        }
        onDragDiffXChanged: if (root.qmlParent) root.qmlParent.dragDistance = dragDiffX
        onDragReleased: diffX => diffX > root.dragConfirmThreshold ? root.destroyWithAnimation() : resetDrag()
    }

    NotificationAppIcon {
        id: notificationIcon
        anchors {
            right: background.left
            top: background.top
            rightMargin: 10
        }
        image: notificationObject?.image ?? ""
        opacity: !root.onlyNotification && image !== "" && root.expanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { Anim {} }
    }

    Rectangle {
        id: background
        width: parent.width
        anchors.left: parent.left
        anchors.leftMargin: root.xOffset
        radius: Rounding.small
        implicitHeight: root.expanded ? contentColumn.implicitHeight + root.padding * 2 : summaryRow.implicitHeight
        color: {
            if (!root.expanded || root.onlyNotification)
                return Colors.methods.transparentize(Colors.colSurfaceContainerHighest);
            return notificationObject?.urgency === NotificationUrgency.Critical
                ? Colors.methods.mix(Colors.colSecondaryContainer, Colors.colLayer2, 0.35)
                : Colors.colSurfaceContainerHigh;
        }

        Behavior on anchors.leftMargin { enabled: !dragManager.dragging; Anim {} }
        Behavior on implicitHeight { Anim {} }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: root.expanded ? root.padding : 0
            spacing: 3

            Behavior on anchors.margins { Anim {} }

            RowLayout {
                id: summaryRow
                visible: !root.onlyNotification || !root.expanded
                Layout.fillWidth: true
                implicitHeight: summaryText.implicitHeight

                StyledText {
                    id: summaryText
                    visible: !root.onlyNotification
                    font.pixelSize: root.fontSize
                    color: Colors.colOnLayer2
                    elide: Text.ElideRight
                    text: root.notificationObject?.summary ?? ""
                }

                StyledText {
                    Layout.fillWidth: true
                    opacity: !root.expanded ? 1 : 0
                    visible: opacity > 0
                    font.pixelSize: root.fontSize
                    color: Colors.colSubtext
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    maximumLineCount: 1
                    textFormat: Text.StyledText
                    text: root.formattedBody

                    Behavior on opacity { Anim {} }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                opacity: root.expanded ? 1 : 0
                visible: opacity > 0

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: root.fontSize
                    color: Colors.colSubtext
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    textFormat: Text.RichText
                    text: `<style>img{max-width:300px;}</style>${root.formattedBody}`

                    onLinkActivated: link => {
                        Qt.openUrlExternally(link);
                        Ipc.call(["sidebar", "hide"]);
                    }

                    PointingHandLinkHover {}
                }

                StyledFlickable {
                    id: actionsFlickable
                    Layout.fillWidth: true
                    implicitHeight: actionRowLayout.implicitHeight
                    contentWidth: actionRowLayout.implicitWidth
                    clip: !root.onlyNotification

                    RowLayout {
                        id: actionRowLayout
                        readonly property bool noActions: (notificationObject?.actions?.length ?? 0) === 0
                        readonly property color iconColor: notificationObject?.urgency === NotificationUrgency.Critical
                            ? Colors.m3.m3onSurfaceVariant
                            : Colors.m3.m3onSurface

                        NotificationActionButton {
                            Layout.fillWidth: true
                            buttonText: "Close"
                            urgency: notificationObject.urgency
                            implicitWidth: actionRowLayout.noActions
                                ? (actionsFlickable.width - actionRowLayout.spacing) / 2
                                : contentItem.implicitWidth + leftPadding + rightPadding
                            onClicked: root.destroyWithAnimation()

                            contentItem: Symbol {
                                font.pixelSize: Fonts.sizes.large
                                horizontalAlignment: Text.AlignHCenter
                                color: actionRowLayout.iconColor
                                text: "close"
                            }
                        }

                        Repeater {
                            model: notificationObject?.actions ?? []
                            NotificationActionButton {
                                Layout.fillWidth: true
                                buttonText: modelData.text
                                urgency: notificationObject.urgency
                                onClicked: Notifications.attemptInvokeAction(notificationObject.notificationId, modelData.identifier)
                            }
                        }

                        NotificationActionButton {
                            Layout.fillWidth: true
                            urgency: notificationObject.urgency
                            implicitWidth: actionRowLayout.noActions
                                ? (actionsFlickable.width - actionRowLayout.spacing) / 2
                                : contentItem.implicitWidth + leftPadding + rightPadding
                            onClicked: {
                                Quickshell.clipboardText = notificationObject.body;
                                copyIcon.text = "inventory";
                                copyIconTimer.restart();
                            }

                            Timer {
                                id: copyIconTimer
                                interval: 1500
                                onTriggered: copyIcon.text = "content_copy"
                            }

                            contentItem: Symbol {
                                id: copyIcon
                                font.pixelSize: Fonts.sizes.large
                                horizontalAlignment: Text.AlignHCenter
                                color: actionRowLayout.iconColor
                                text: "content_copy"
                            }
                        }
                    }
                }
            }
        }
    }
}
