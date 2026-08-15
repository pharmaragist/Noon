import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.store

Repeater {
    id: root
    property bool vertical: false
    property var panel
    delegate: StyledLoader {
        id: loader
        required property var modelData

        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        Layout.fillHeight: true
        Layout.fillWidth: true

        binds: {
            "barSize": () => BarData.currentBarExclusiveSize,
            "bar": () => barRoot,
            "verticalMode": () => root.vertical,
            "vertical": () => root.vertical
        }

        source: {
            const component = (root.vertical ? BarData.contentTable[modelData] : BarData.horizontalSubstitutions[modelData]) ?? BarData.contentTable[modelData];
            return sanitizeSource("", component);
        }

        onLoaded: if (ready) {
            loader.active = Qt.binding(() => item.visible);

            BarData.layoutProps.forEach(prop => {
                Layout[prop] = Qt.binding(() => item?.Layout?.[prop]);
            });
        }
    }
}
