import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions
import qs.data

FloatingWindow {
    id: root
    minimumSize: Qt.size(800, 600)
    maximumSize: Qt.size(800, 600)
    color: Colors.m3.m3surface
    title: "Preview"

    function dismiss() {
        root.destroy();
    }
    onVisibleChanged: if (!visible)
        root.destroy()

    Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.topMargin: Padding.normal
                Layout.rightMargin: Padding.huge
                Layout.leftMargin: Padding.huge
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: Padding.normal

                Symbol {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "show_chart"
                    iconSize: 18
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    text: "Create your curve "
                    font: Fonts.request("title", "normal")
                    color: Colors.colOnSurfaceVariant
                }
                RippleButtonWithIcon {
                    implicitSize: 25
                    buttonRadius: Rounding.normal
                    toggled: true
                    materialIcon: "play_arrow"
                    downAction: () => {
                        curve.playPreview();
                    }
                }
            }

            CurveEditor {
                id: curve
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.margins: Padding.normal

                topRadius: Rounding.huge
                bottomRadius: Mem.hypr.rounding - Padding.normal
                onCurveValuesChanged: Mem.options.appearance.animations.userCurve = this.curveValues
            }
        }
    }
}
