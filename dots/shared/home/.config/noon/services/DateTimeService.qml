pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.utils

Singleton {
    id: root
    property string uptime: "0h, 0m"
    readonly property string date: root.request("dddd, dd/MM")
    readonly property string day: root.request("dd")
    readonly property string month: root.request("MMMM")
    readonly property string year: root.request("yyyy")
    readonly property string minute: root.request("mm")
    readonly property string second: root.request("ss")
    readonly property alias clock: clock
    readonly property bool twelveHour: Mem.options.services.time.use12HourFormat ?? true
    readonly property string time: twelveHour ? root.request("hh:mm ap") : root.request("HH:mm")
    readonly property string hour: twelveHour ? root.request("hh AP").split(" ")[0] : root.request("HH")
    readonly property string dayTime: twelveHour ? root.request("AP") : ""
    readonly property string collapsedCalendarFormat: root.request("dd MMMM yyyy")

    function request(format) {
        if (!format || typeof format !== "string")
            return "";
        return Qt.formatDateTime(clock.date, format);
    }

    function getRelativeTime(timestamp) {
        const now = new Date();
        const savedTime = new Date(timestamp);
        const diff = Math.floor((now - savedTime) / 1000);

        if (diff < 60)
            return diff + "s ago";
        if (diff < 3600)
            return Math.floor(diff / 60) + "m ago";
        if (diff < 86400)
            return Math.floor(diff / 3600) + "h ago";
        return Qt.formatDate(savedTime, "MMM d, yyyy");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            fileUptime.reload();
            const uptimeSeconds = parseFloat(fileUptime.text().split(" ")[0]) || 0;

            const days = Math.floor(uptimeSeconds / 86400);
            const hours = Math.floor((uptimeSeconds % 86400) / 3600);
            const minutes = Math.floor((uptimeSeconds % 3600) / 60);

            const parts = [];
            if (days > 0)
                parts.push(`${days}d`);
            if (hours > 0)
                parts.push(`${hours}h`);
            if (minutes > 0 || parts.length === 0)
                parts.push(`${minutes}m`);

            root.uptime = parts.join(", ");
        }
    }

    FileView {
        id: fileUptime
        path: "/proc/uptime"
    }
}
