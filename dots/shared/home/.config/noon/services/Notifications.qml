pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.common
import qs.common.utils

Singleton {
    id: root

    readonly property var states: Mem?.states?.services?.notifications ?? null
    readonly property bool silent: states?.silent ?? false
    readonly property var list: states?.list ?? []

    readonly property bool popupInhibited: (Globals?.sidebarRightOpen ?? false) || silent

    readonly property var popupList: list.filter(n => n.popup)
    readonly property var groupsByAppName: groupFor(list)
    readonly property var popupGroupsByAppName: groupFor(popupList)
    readonly property var appNameList: Object.keys(groupsByAppName).sort((a, b) => groupsByAppName[b].time - groupsByAppName[a].time)
    readonly property var popupAppNameList: Object.keys(popupGroupsByAppName).sort((a, b) => popupGroupsByAppName[b].time - popupGroupsByAppName[a].time)

    property int _idOffset: 0

    function groupFor(items) {
        const groups = {};
        for (const n of items) {
            if (!groups[n.appName])
                groups[n.appName] = { appName: n.appName, appIcon: n.appIcon, notifications: [], time: 0 };
            groups[n.appName].notifications.push(n);
            groups[n.appName].time = Math.max(groups[n.appName].time, n.time);
        }
        return groups;
    }

    function plainNotif(notification, id) {
        return {
            notificationId: id,
            actions: Array.from(notification.actions ?? [], a => ({ identifier: a.identifier, text: a.text })),
            appIcon: notification.appIcon ?? "",
            appName: notification.appName ?? "",
            body: notification.body ?? "",
            image: notification.image ?? "",
            summary: notification.summary ?? "",
            urgency: notification.urgency,
            time: Date.now(),
            popup: false
        };
    }

    function serverNotif(id) {
        const i = notifServer.trackedNotifications.values.findIndex(n => n.id + root._idOffset === id);
        return i !== -1 ? notifServer.trackedNotifications.values[i] : null;
    }

    function discardNotification(id) {
        if (root.list.some(n => n.notificationId === id))
            states.list = root.list.filter(n => n.notificationId !== id);
        serverNotif(id)?.dismiss();
    }

    function discardAllNotifications() {
        states.list = [];
        notifServer.trackedNotifications.values.forEach(n => n.dismiss());
    }

    function attemptInvokeAction(id, identifier) {
        const srv = serverNotif(id);
        const action = srv?.actions.find(a => a.identifier === identifier);
        if (action)
            action.invoke();
        discardNotification(id);
    }

    Component.onCompleted: {
        const ids = root.list.map(n => n.notificationId);
        root._idOffset = ids.length ? Math.max(...ids) : 0;
    }

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            const newNotif = plainNotif(notification, notification.id + root._idOffset);

            if (!root.silent)
                NoonUtils.playSound("notif_1");

            if (!root.popupInhibited) {
                newNotif.popup = true;
                NoonUtils.inlineTimer(() => {
                    newNotif.popup = false;
                    discardNotification(newNotif.notificationId);
                }, Math.max(5000, Math.min(10000, notification.expireTimeout)));
            }

            states.list = [...root.list, newNotif];
        }
    }
}
