import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common

Rectangle {
    property int padding: 4
    implicitWidth: 1
    Layout.topMargin: padding
    Layout.bottomMargin: padding
    opacity: 0.4
    Layout.fillHeight: true
    color: Colors.colOutlineVariant
}
