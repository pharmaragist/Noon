import qs.common
import qs.common.widgets
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    Layout.fillHeight: true
    Layout.fillWidth: true
    hoverEnabled: true

    ColumnLayout {
        id: colLayout
        anchors.left: parent.left
        anchors.leftMargin: Padding.large
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        StyledText {
            id: appId
            Layout.fillWidth: true
            font: Fonts.request("main", "small")
            color: Colors.colSubtext
            truncate: true
            text: MonitorsInfo.topLevel?.appId ?? qsTr("Desktop")
        }

        StyledText {
            Layout.maximumWidth: 240
            Layout.fillWidth: true
            font: Fonts.request("title", "normal")
            color: Colors.colOnLayer0
            truncate: true
            text: MonitorsInfo.topLevel?.title ?? `${qsTr("Workspace")} ${MonitorsInfo.focused?.activeWorkspace?.id ?? 0}`
        }
    }
}
