import QtQuick
import qs.data
import qs.common.widgets
import qs.common

StyledMenu {
    id: root

    required property var widgetData

    readonly property string widgetId: widgetData.id
    readonly property var store: Mem.states.sidebar.widgets
    readonly property var rec: store.items.find(w => w.id === widgetId)
    readonly property bool isPinned: rec?.pin ?? false
    readonly property bool isDesktop: rec?.desktop ?? false
    readonly property bool isPill: rec?.pill ?? false

    function toggle(field) {
        let items = store.items.slice();
        let rec = items.find(w => w.id === widgetId);
        if (rec) {
            rec[field] = !rec[field];
            store.items = items;
        }
        root.close();
    }

    function setSize(size) {
        let items = store.items.slice();
        let rec = items.find(w => w.id === widgetId);
        if (rec) {
            rec.size = size;
            store.items = items;
        }
        root.close();
    }

    content: {
        let items = [
            {
                text: isPinned ? "Unpin" : "Pin",
                materialIcon: "push_pin",
                action: () => toggle("pin")
            },
            {
                text: isDesktop ? "Remove from desktop" : "Send to desktop",
                materialIcon: "open_in_new",
                action: () => toggle("desktop")
            },
            {
                text: isPill ? "Square" : "Pill",
                materialIcon: isPill ? "capture" : "pill",
                visible: (rec?.size ?? "normal") === "small",
                action: () => toggle("pill")
            },
            {
                text: "Disable",
                materialIcon: "visibility_off",
                action: () => toggle("enabled")
            }
        ];

        const sizes = ["small", "normal", "large", "xlarge"];
        for (let size of sizes) {
            items.push({
                text: size.charAt(0).toUpperCase() + size.slice(1),
                materialIcon: (rec?.size ?? "normal") === size ? "radio_button_checked" : "radio_button_unchecked",
                action: () => setSize(size)
            });
        }

        return items;
    }
}
