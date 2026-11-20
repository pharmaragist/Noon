pragma Singleton
pragma ComponentBehavior: Bound
import qs.common
import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property var list: store.events
    readonly property var store: Mem.todo
    // Helpers
    function getTasksOfDate(dateString) {
        const todayEvents = CalendarService.list.filter(e => e.start === dateString);
        const allTasks = TodoService?.list ?? [];
        const tasks = allTasks.map(item => ({
                    content: item?.content ?? "",
                    start: item?.due + '/' + DateTimeService.year ?? "",
                    isTask: true
                })).filter(task => task.start === dateString);
        return [...todayEvents, ...tasks];
    }

    function getUpcomingEvents(daysAhead) {
        let result = [];
        const base = new Date();
        for (let i = 1; i <= daysAhead; i++) {
            const d = new Date(base);
            d.setDate(base.getDate() + i);
            const dateString = d.getDate() + "/" + (d.getMonth() + 1) + "/" + d.getFullYear();
            const tasks = getTasksOfDate(dateString);
            for (const t of tasks)
                result.push({
                    content: t.content,
                    dateLabel: Qt.formatDateTime(d, "ddd d")
                });
        }
        return result;
    }

    function addEvent(desc, start, time, duration = 60, end = start) {
        store.events.push({
            content: desc,
            start: start,
            end: end,
            time: time,
            duration: duration
        });
    }

    function editEvent(index, newContent) {
        if (index < 0 || !newContent)
            return;
        store.events[index].content = newContent.trim();
    }

    function deleteEvent(index) {
        if (index >= 0 && index < list.length) {
            store.events.splice(index, 1).slice(0);
        }
    }

    function getEventsByDate(date) {
        return list.filter(e => e.start === date);
    }

    function formatEvents() {
        if (!list || list.length === 0)
            return "No Upcoming Events";
        let output = "Upcoming events:\n\n";
        list.forEach((event, i) => {
            output += `${i}. ${event.content} — ${event.start} ${event.time} (${event.duration}min)\n`;
        });
        return output;
    }
}
