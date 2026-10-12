import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.data

Repeater {
    id: root
    property bool vertical: false
    property var panel
    delegate: StyledLoader {
        id: loader
        required property var modelData
        visible: this.active
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        Layout.fillHeight: true
        Layout.fillWidth: true

        binds: {
            "position": () => BarData.position,
            "barSize": () => BarData.currentBarExclusiveSize,
            "bar": () => panel,
            "verticalMode": () => root.vertical,
            "vertical": () => root.vertical
        }

        source: {
            const component = (root.vertical ? BarData.contentTable[modelData] : BarData.horizontalSubstitutions[modelData]) ?? BarData.contentTable[modelData];
            return sanitizeSource("", component);
        }

        onLoaded: if (ready) {
            // loader.active = Qt.binding(() => loader.item.visible);

            BarData.layoutProps.forEach(prop => {
                Layout[prop] = Qt.binding(() => loader.item?.Layout?.[prop]);
            });
        }
    }
}
