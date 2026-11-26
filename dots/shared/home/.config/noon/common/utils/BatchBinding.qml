import QtQuick

QtObject {
    id: root
    required property var target
    required property var data

    Component.onCompleted: assign()
    onDataChanged: assign()

    function assign() {
        if (!target || !data)
            return;
        for (const key of Object.keys(data)) {
            target[key] = Qt.binding(() => {
                const value = data[key];
                return typeof value === "function" ? value() : value;
            });
        }
    }
}
