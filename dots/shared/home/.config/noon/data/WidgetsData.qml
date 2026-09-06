import QtQuick
import Quickshell

import qs.common
import qs.services

QtObject {
    id: root
    readonly property var stock: [
        {
            id: "resources",
            expandable: true,
            name: "Resources",
            component: "Resources",
            icon: "memory"
        },
        {
            id: "battery",
            expandable: false,
            name: "Battery",
            component: "Battery",
            icon: "battery_full"
        },
        {
            id: "simple_clock",
            expandable: false,
            name: "Simple Clock",
            component: "ClockSimple",
            icon: "schedule"
        },
        {
            id: "bluetooth",
            expandable: false,
            name: "Bluetooth",
            component: "Bluetooth",
            icon: "bluetooth"
        },
        {
            id: "media",
            expandable: true,
            name: "Media View",
            component: "Media",
            icon: "music_note"
        },
        {
            id: "combo",
            expandable: true,
            name: "Clock & Weather",
            component: "ClockWeatherCombo",
            icon: "wb_twilight"
        },
        {
            id: "net",
            expandable: false,
            name: "Network Speed",
            component: "NetworkSpeed",
            icon: "network_check"
        },
        {
            id: "cal",
            expandable: true,
            name: "Google Calendar",
            component: "Calendar",
            icon: "calendar_today"
        },
        {
            id: "weather",
            expandable: false,
            name: "Simple Weather",
            component: "WeatherSimple",
            icon: "cloud"
        },
        {
            id: "dino",
            expandable: false,
            name: "Offline Dino",
            component: "Dino",
            icon: "joystick"
        }
    ]

    readonly property var mem: Mem.states.sidebar.widgets
    readonly property var plugins: Object.values(PluginsManager.desktopWidgetsPlugins ?? {})
    readonly property var db: [...stock, ...plugins]
    readonly property var desktopWidgets: {
        const items = mem?.items ?? [];
        return items.filter(w => w.desktop).map(w => {
            const widgetData = root.db.find(item => item.id === w.id);
            if (!widgetData || !(widgetData.enabled ?? true))
                return null;
            return {
                id: w.id,
                entry: widgetData.entry ?? false,
                isPlugin: widgetData.isPlugin ?? false,
                component: widgetData.component || "",
                expandable: widgetData.expandable,
                size: w.size ?? "normal",
                pin: w.pin,
                pill: w.pill
            };
        }).filter(w => w !== null);
    }
}
