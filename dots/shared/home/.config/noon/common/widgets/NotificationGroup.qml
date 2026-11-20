import qs.common
import qs.services
import "notification_utils.js" as NotificationUtils
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var notificationGroup
    property var notifications: notificationGroup?.notifications ?? []
    property int notificationCount: notifications.length
    property bool multipleNotifications: notificationCount > 1
    property bool expanded: false
    property bool popup: false
    property bool omitOnDestroy: false
    property real padding: Padding.verylarge
    property int radius: Rounding.verylarge
    property color color: popup ? Colors.colLayer0 : Colors.colLayer2
    property real dragConfirmThreshold: 70
    property real dismissOvershoot: 20

    readonly property var qmlParent: parent?.parent ?? null
    readonly property int dragIndexDiff: Math.abs((qmlParent?.dragIndex ?? -1) - index)
    readonly property real dragDistance: qmlParent?.dragDistance ?? 0
    readonly property real xOffset: {
        if (dragIndexDiff === 0)
            return Math.max(0, dragDistance);
        if (dragDistance > dragConfirmThreshold)
            return 0;
        if (dragIndexDiff === 1)
            return Math.max(0, dragDistance * 0.3);
        if (dragIndexDiff === 2)
            return Math.max(0, dragDistance * 0.1);
        return 0;
    }

    implicitHeight: background.implicitHeight
    onPopupChanged: if (popup &&  !expanded && !!notificationGroup)
        NoonUtils.inlineTimer(() => root?.destroyWithAnimation(true), Mem.options.osd.timeout ?? 3000);

    function destroyWithAnimation(omit = root.popup) {
        omitOnDestroy = omit;
        qmlParent?.resetDrag();
        background.anchors.leftMargin = background.anchors.leftMargin;
        destroyAnimation.start();
    }

    function toggleExpanded() {
        implicitHeightAnim.enabled = expanded;
        expanded = !expanded;
    }

    SequentialAnimation {
        id: destroyAnimation
        Anim {
            target: background.anchors
            property: "leftMargin"
            to: root.width + root.dismissOvershoot
        }
        onFinished: notifications.forEach(n => Qt.callLater(() => omitOnDestroy ? Notifications.omitNotification(n.notificationId) : Notifications.dismissNotification(n.notificationId)))
    }

    DragManager {
        id: dragManager
        anchors.fill: parent
        interactive: !root.expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.toggleExpanded();
            else if (mouse.button === Qt.MiddleButton)
                root.destroyWithAnimation();
        }
        onDraggingChanged: {
            if (dragging && root.qmlParent)
                root.qmlParent.dragIndex = root.index ?? root.parent.children.indexOf(root);
        }
        onDragDiffXChanged: if (root.qmlParent)
            root.qmlParent.dragDistance = dragDiffX
        onDragReleased: diffX => diffX > root.dragConfirmThreshold ? root.destroyWithAnimation() : resetDrag()
    }

    StyledRectangularShadow {
        target: background
        visible: root.popup
    }

    Rectangle {
        id: background
        width: parent.width
        color: root.color
        radius: root.radius
        clip: true
        anchors.left: parent.left
        anchors.leftMargin: root.xOffset
        implicitHeight: root.expanded ? row.implicitHeight + root.padding * 2 : Math.min(80, row.implicitHeight + root.padding * 2)

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging
            Anim {}
        }
        Behavior on implicitHeight {
            id: implicitHeightAnim
            Anim {}
        }

        RowLayout {
            id: row
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: root.padding
            }
            spacing: 10

            NotificationAppIcon {
                Layout.alignment: Qt.AlignTop
                image: root.multipleNotifications ? "" : (root.notifications[0]?.image ?? "")
                appIcon: root.notificationGroup?.appIcon
                summary: root.notifications[root.notificationCount - 1]?.summary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: {
                    if (!root.expanded || !root.multipleNotifications)
                        return 2;
                    return root.notifications[root.notificationCount - 1]?.image !== "" ? 35 : 5;
                }

                Behavior on spacing {
                    Anim {}
                }

                RowLayout {
                    id: topRow
                    Layout.fillWidth: true
                    spacing: Padding.small

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: (root.multipleNotifications ? root.notificationGroup?.appName : root.notifications[0]?.summary) || ""
                        font.pixelSize: root.multipleNotifications ? Fonts.sizes.verysmall : Fonts.sizes.small
                        color: root.multipleNotifications ? Colors.colSubtext : Colors.colOnLayer2
                    }

                    StyledText {
                        Layout.rightMargin: 10
                        text: NotificationUtils.getFriendlyNotifTimeString(root.notificationGroup?.time)
                        font.pixelSize: Fonts.sizes.verysmall
                        color: Colors.colSubtext
                    }

                    NotificationGroupExpandButton {
                        count: root.notificationCount
                        expanded: root.expanded
                        fontSize: Fonts.sizes.verysmall
                        onClicked: root.toggleExpanded()
                    }
                }

                StyledListView {
                    id: notificationsColumn
                    Layout.fillWidth: true
                    implicitHeight: contentHeight
                    interactive: false
                    spacing: root.expanded ? 5 : 3
                    _model: root.expanded ? [...root.notifications].reverse() : [...root.notifications].reverse().slice(0, 2)

                    Behavior on spacing {
                        Anim {}
                    }

                    delegate: NotificationItem {
                        required property int index
                        required property var modelData
                        notificationObject: modelData
                        expanded: root.expanded
                        onlyNotification: root.notificationCount === 1
                        popup: root.popup
                        opacity: !root.expanded && index === 1 && root.notificationCount > 2 ? 0.5 : 1
                        visible: root.expanded || index < 2
                        anchors.left: parent?.left
                        anchors.right: parent?.right
                    }
                }
            }
        }
    }
}
