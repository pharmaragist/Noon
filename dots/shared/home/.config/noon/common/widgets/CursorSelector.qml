import QtQuick.Layouts
import QtQuick
import Noon.Widgets
import QtQuick.Controls
import qs.common
import qs.common.widgets
import qs.services
import Quickshell

Item {
    id: root
    anchors.fill: parent
    implicitHeight: 115

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.topMargin: Padding.huge
            Layout.alignment: Qt.AlignBottom
            Layout.preferredHeight: 50
            Layout.fillWidth: true

            PathView {
                id: carousel
                anchors.fill: parent
                anchors.leftMargin: prevBtn.width + Padding.massive
                anchors.rightMargin: nextBtn.width + Padding.massive

                pathItemCount: 3
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                model: CursorsService?.cursors

                Component.onCompleted: syncIndex()
                onModelChanged: carousel.syncIndex()

                function syncIndex() {
                    if (carousel.model)
                        carousel.currentIndex = carousel.model.findIndex(i => i === Mem.hypr.cursor_theme);
                }

                path: Path {
                    startX: 0
                    startY: carousel.height / 2
                    PathLine {
                        x: carousel.width
                        y: carousel.height / 2
                    }
                }

                delegate: Item {
                    id: delegateItem
                    required property var modelData
                    required property int index

                    readonly property bool isCurrent: modelData === Mem.hypr.cursor_theme

                    width: carousel.width / 3
                    height: carousel?.height

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Item {
                            width: Math.max(50, Mem.hypr.cursor_size * 1.5)
                            height: Math.max(50, Mem.hypr.cursor_size * 1.5)
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                            CursorImage {
                                anchors.centerIn: parent
                                implicitWidth: Mem.hypr.cursor_size
                                implicitHeight: Mem.hypr.cursor_size
                                theme: modelData
                                cursor: "left_ptr"
                                size: Mem.hypr.cursor_size
                                scale: mouseArea.containsPress ? 0.85 : (mouseArea.containsMouse || delegateItem.isCurrent ? 1.2 : 1.0)
                                transformOrigin: Item.Bottom

                                Behavior on scale {
                                    Anim {}
                                }
                            }
                        }

                        StyledRect {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: delegateItem.isCurrent ? 20 : 0
                            implicitHeight: 4
                            radius: 2
                            color: Colors.colSecondary
                            opacity: delegateItem.isCurrent ? 1 : 0
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            carousel.currentIndex = delegateItem.index;
                            Mem.hypr.cursor_theme = modelData.trim();
                        }
                    }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: parent.width / 2
                z: 10
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Colors.colLayer3
                    }
                    GradientStop {
                        position: 1
                        color: Colors.methods.transparentize(Colors.colLayer3)
                    }
                }
            }

            Rectangle {
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                width: parent.width / 2
                z: 10
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Colors.methods.transparentize(Colors.colLayer3)
                    }
                    GradientStop {
                        position: 1
                        color: Colors.colLayer3
                    }
                }
            }

            Symbol {
                id: prevBtn
                icon: "chevron_left"
                iconSize: 24
                color: Colors.colOnSurfaceVariant
                z: 20
                anchors {
                    left: parent.left
                    leftMargin: Padding.huge
                    verticalCenter: parent.verticalCenter
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        carousel.decrementCurrentIndex();
                        if (carousel.currentItem?.modelData) {
                            Mem.hypr.cursor_theme = carousel.currentItem.modelData.trim();
                        }
                    }
                }
            }

            Symbol {
                id: nextBtn
                icon: "chevron_right"
                iconSize: 24
                color: Colors.colOnSurfaceVariant
                z: 20
                anchors {
                    right: parent.right
                    rightMargin: Padding.huge
                    verticalCenter: parent.verticalCenter
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        carousel.incrementCurrentIndex();
                        if (carousel.currentItem?.modelData) {
                            Mem.hypr.cursor_theme = carousel.currentItem.modelData.trim();
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.preferredHeight: 50
            Layout.fillWidth: true
            Layout.leftMargin: Padding.massive
            Layout.rightMargin: Padding.massive

            StyledText {
                text: "Size "
                Layout.fillWidth: true
                color: Colors.colOnSurfaceVariant
                font: Fonts.request("normal", "normal")
            }
            StyledSpinBox {
                from: 15
                to: 50
                value: Mem.hypr.cursor_size
                onValueChanged: Mem.hypr.cursor_size = value
            }
        }
    }
}
