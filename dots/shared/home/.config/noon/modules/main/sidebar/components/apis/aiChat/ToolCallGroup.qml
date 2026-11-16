import qs.services
import qs.common
import qs.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var tools: []
    property var messageData
    property bool expanded: false

    readonly property bool anyPending: {
        for (let i = 0; i < tools.length; i++) {
            if (tools[i]?.status === "pending") return true;
        }
        return false;
    }

    readonly property string headerSummary: {
        const counts = {};
        for (let i = 0; i < tools.length; i++) {
            const name = this.methods.capitalizeFirstLetter(tools[i]?.tool ?? "tool");
            counts[name] = (counts[name] ?? 0) + 1;
        }
        return Object.entries(counts)
        .map(([name, count]) => count > 1 ? `${name} (${count})` : name)
        .join(", ");
    }

    Layout.fillWidth: true
    implicitHeight: columnLayout.implicitHeight

    ColumnLayout {
        id: columnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Padding.small

        Item {
            Layout.preferredHeight: 40
            Layout.maximumHeight: 40
            Layout.fillWidth: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }

            RowLayout {
                anchors.fill: parent
                spacing: Padding.large

                StyledRect {
                    implicitHeight: 35
                    radius: height / 2
                    implicitWidth: pillRow.implicitWidth + Padding.massive
                    color: Colors.colLayer1

                    RowLayout {
                        id: pillRow
                        anchors.centerIn: parent

                        Item {
                            width: 24
                            height: 24
                            rotation: root.expanded ? 0 : 180
                            Behavior on rotation { Anim {} }

                            Symbol {
                                anchors.centerIn: parent
                                icon: "keyboard_arrow_down"
                                iconSize: 24
                                fill: 1
                                color: Colors.colOnLayer1
                            }
                        }

                        Symbol {
                            text: "stacks"
                            iconSize: 20
                            color: Colors.colOnLayer1
                        }

                        Symbol {
                            text: root.anyPending ? "hourglass_empty" : "done"
                            iconSize: 20
                            color: root.anyPending ? Colors.colTertiary : Colors.colSubtext
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    truncate: true
                    Layout.rightMargin: Padding.large
                    text: `${root.tools.length} tool calls · ${root.headerSummary}`
                    font: Fonts.request("mono", "normal")
                }
            }
        }

        Revealer {
            reveal: root.expanded
            Layout.fillWidth: true
            vertical: true

            revealChild: ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Padding.large
                spacing: Padding.small

                Repeater {
                    model: root.tools
                    delegate: ToolCallBlock {
                        required property var modelData
                        Layout.fillWidth: true
                        tool: modelData?.tool ?? ""
                        callID: modelData?.callID ?? ""
                        input: modelData?.input ?? ""
                        output: modelData?.output ?? ""
                        status: modelData?.status ?? ""
                        raw: modelData
                        messageData: root.messageData
                    }
                }
            }
        }
    }
}
