import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

StyledRect {
    id: root
    z: 9999
    required property var widgetData
    property bool isLarge: /large/.test(widgetData.size) ?? false
    property bool show: false

    anchors.fill: parent
    opacity: show ? 1 : 0
    color: Colors.t(root.colors.colSecondaryContainer, 0.55)

    function setField(field, value) {
        const store = Mem?.states?.sidebar?.widgets;
        let items = store.items.slice();
        let rec = items.find(w => w.id === widgetData.id);
        if (rec) {
            rec[field] = value;
            store.items = items;
        }
        root.show = false;
    }


    Timer {
        running: root.show
        interval: 1500
        onTriggered: root.show = false
    }

    GridLayout {
        columns: root.isLarge ? 4 : 2
        rows: 2
        anchors.centerIn: parent
        rowSpacing: root.isLarge ? Padding.normal : Padding.tiny
        columnSpacing: root.isLarge ? Padding.normal : Padding.tiny

        Repeater {
            model: ["small", "normal", "large", "xlarge"]
            delegate: RippleButton {
                id: btn
                required property var modelData
                implicitSize: 45
                buttonRadius: Rounding.huge
                colors: root.colors

                StyledText {
                    anchors.centerIn: parent
                    text: btn.modelData[0].toUpperCase()
                    color: root.colors.colOnLayer3
                    font: Fonts.request("title", 18)
                }

                releaseAction: () => root.setField("size", btn.modelData);
            }
        }
    }
}
