import QtQuick

QtObject {
    id: root
    required property var target
    required property var data
    Component.onCompleted: assign()
    function assign() {
        for (const [key, value] of Object.entries(data)) {
            target[key] = Qt.binding(value);
        }
    }
}
