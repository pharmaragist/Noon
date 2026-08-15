import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.common
import qs.common.widgets
import qs.services
import qs.store
import qs.modules.main.bar.components
import "../widgets"

Item {
    id: root
    readonly property string widgetsPath: "../widgets/"
    readonly property var widgetObjects: WidgetsData.desktopWidgets
    readonly property bool rightMode: BarData.position === "right"
    anchors.top: parent.top
    anchors.left: !rightMode ? parent.left : undefined
    anchors.right: rightMode ? parent.right : undefined
    implicitWidth: 400
    onRightModeChanged: ldr.reload()

    StyledLoader {
        id: ldr
        anchors.fill: parent
        active: Mem.options.desktop.widgets.enabled
        sourceComponent: StyledFlow {
            id: flow
            anchors.fill: parent
            anchors.margins: Padding.large
            spacing: Padding.huge
            layoutDirection: root.rightMode ? Qt.RightToLeft : Qt.LeftToRight
            Repeater {
                model: ScriptModel {
                    values: root.widgetObjects
                }
                delegate: Item {
                    id: delegated
                    required property var modelData

                    function sizePerRow(size) {
                        switch (size) {
                        case "small":
                            return 4;
                        case "large":
                        case "xlarge":
                            return 1;
                        default:
                            return 2;
                        }
                    }

                    function slotHeight(size) {
                        switch (size) {
                        case "small":
                            return 100;
                        case "xlarge":
                            return 2 * 200 + (parent?.spacing ?? 0);
                        default:
                            return 200;
                        }
                    }

                    width: (parent?.width - parent?.spacing * (sizePerRow(modelData?.size ?? "normal") - 1)) / sizePerRow(modelData?.size ?? "normal")
                    height: slotHeight(modelData?.size ?? "normal")

                    SizeOverlay {
                        id: sizeOvl
                        widgetData: delegated.modelData
                        radius: loader._item.radius ?? Rouding.large
                        colors: loader._item.colors ?? Colors
                    }

                    MouseArea {
                        z: 99999
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.RightButton | Qt.MiddleButton
                        onPressed: event => {
                            if (event.button === Qt.RightButton) {
                                sizeOvl.show = !sizeOvl.show;
                            }
                        }
                    }

                    StyledLoader {
                        id: loader
                        anchors.fill: parent
                        source: modelData.isPlugin ? modelData.entry : root.widgetsPath + modelData.component + ".qml"
                        onLoaded: {
                            _item.widgetData = Qt.binding(() => modelData);
                            if ("window" in _item)
                                _item.window = Qt.binding(() => root);
                        }
                    }
                }
            }
        }
    }
}
