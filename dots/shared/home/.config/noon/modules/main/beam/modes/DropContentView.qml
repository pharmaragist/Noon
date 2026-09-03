import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.services
import qs.data

RowLayout {
    anchors.fill: parent

    anchors.leftMargin: Padding.silly
    anchors.rightMargin: Padding.massive
    spacing: Padding.massive
    z: 999
    MaterialShapeWrappedSymbol {
        _shape: "Pill"
        iconSize: 120
        text: "bookmark_add"
        color: Colors.colPrimary
        colSymbol: Colors.colOnPrimary
    }

    ColumnLayout {
        Layout.fillWidth: true

        StyledText {
            font: Fonts.request("title", "title")
            text: "Drop Here !"
            color: Colors.colPrimary
        }
        StyledText {
            font: Fonts.request("banner", "subTitle")
            text: "You can drop your files now"
            color: Colors.colOnLayer0
        }
    }
}
