import QtQuick
import QtQuick.Layouts
import qs.data
import qs.common
import qs.common.widgets

StyledRect {
    id: root
    property var barRoot
    property int barSize: -1
    property bool vertical: false
    property bool verticalMode: false
    property bool active: BarData.currentModeInfo.appearance.barGroup
    property color colBackground: Colors.colSurfaceContainer
    property string position: "top"
    readonly property real padding: Padding.small
    color: active ? colBackground : "transparent"
    radius: Rounding.large
    clip: true
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    Layout.topMargin: if (!vertical)
        padding
    Layout.bottomMargin: if (!vertical)
        padding
    Layout.rightMargin: if (vertical)
        padding
    Layout.leftMargin: if (vertical)
        padding
}
