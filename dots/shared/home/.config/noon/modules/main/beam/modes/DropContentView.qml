import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.services
import qs.data

ContentViewItem {
    Item {
        width: 600
        height: 200

        RowLayout {
            anchors.fill: parent
            anchors.margins: Padding.large
            anchors.leftMargin: Padding.silly
            anchors.rightMargin: Padding.silly

            spacing: Padding.massive
            z: 999

            MaterialShapeWrappedSymbol {
                _shape: "Pill"
                iconSize: 80
                text: "bookmark_add"
                color: Colors.colPrimary
                colSymbol: Colors.colOnPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true

                StyledText {
                    font: Fonts.request("title", 48)
                    text: "Drop Here !"
                    color: Colors.colPrimary
                }
                StyledText {
                    font: Fonts.request("banner", 24)
                    text: "You can drop your files now"
                    color: Colors.colOnLayer0
                }
            }
        }
    }
}
