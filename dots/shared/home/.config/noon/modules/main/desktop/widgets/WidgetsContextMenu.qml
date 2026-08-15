import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.store
import qs.common
import qs.common.widgets
import qs.modules.main.desktop.widgets

StyledMenu {
    id: root
    required property var modelData
    readonly property string widgetId: modelData.id
    readonly property var store: Mem?.states?.sidebar?.widgets
    readonly property var rec: store?.items?.find(w => w.id === widgetId)
    readonly property bool isPill: rec?.pill ?? false

    function setField(field, value) {
        let items = store.items.slice();
        let rec = items.find(w => w.id === widgetId);
        if (rec) {
            rec[field] = value;
            store.items = items;
        }
        root.close();
    }

    content: {
        let items = [
            {
                text: root.isPill ? "Square" : "Pill",
                materialIcon: root.isPill ? "capture" : "pill",
                visible: (rec?.size ?? "normal") === "small",
                action: () => root.setField("pill", !root.isPill)
            },
            {
                text: "Remove",
                materialIcon: "close",
                action: () => root.setField("desktop", false)
            }
        ];

        const sizes = ["small", "normal", "large", "xlarge"];
        for (let size of sizes) {
            items.push({
                text: size.charAt(0).toUpperCase() + size.slice(1),
                materialIcon: (rec?.size ?? "normal") === size ? "radio_button_checked" : "radio_button_unchecked",
                action: () => root.setField("size", size)
            });
        }

        return items;
    }
}
