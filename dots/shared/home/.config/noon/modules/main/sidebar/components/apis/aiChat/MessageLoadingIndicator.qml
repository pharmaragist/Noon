import qs.common
import qs.common.widgets
import QtQuick

Item {
    id: loadingIndicator
    property var messageData
    property int blockCount: 0
    property bool done: false
    property bool queued: false
    property bool loading: blockCount === 0 && !done && !queued
    anchors.left: parent.left
    implicitHeight: 40
    implicitWidth: 40

    MaterialLoadingIndicator {
        visible: loading
        loading: loadingIndicator.loading
        implicitSize: 35
        anchors.centerIn: parent
    }
}
