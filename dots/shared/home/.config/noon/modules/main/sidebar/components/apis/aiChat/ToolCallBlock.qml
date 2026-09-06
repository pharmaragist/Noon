import qs.services
import qs.common
import qs.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string tool
    property string callID
    property var input
    property string output
    property string status
    property bool expanded: false
    property var messageData
    property var raw

    readonly property bool isPending: status === "pending"
    readonly property bool completed: status === "completed"
    // NOTE: no isPending gate — the agent always emits tool_call_update
    // (in_progress) before asking permission, so gating on "pending" hid
    // the buttons exactly when they were needed. The permissionCallID
    // match alone identifies the awaiting call.
    readonly property bool pendingApproval: (messageData?.functionPending ?? false) && root.callID !== "" && root.callID === messageData?.permissionCallID

    readonly property string statusIcon: isPending ? "hourglass_empty" : (completed ? "done" : "")
    readonly property string statusTint: isPending ? Colors.colTertiary : Colors.colSubtext

    readonly property var dict: ({
            "bash": {
                "icon": "terminal",
                "summary": input?.command ?? ""
            },
            "webfetch": {
                "icon": "language",
                "summary": input?.url ?? ""
            },
            "write": {
                "icon": "edit_document",
                "summary": (input?.content ?? "").split("\n")[0]
            },
            "grep": {
                "icon": "search",
                "summary": input?.pattern ?? ""
            },
            "glob": {
                "icon": "folder_open",
                "summary": input?.pattern ?? ""
            },
            "skill": {
                "icon": "auto_awesome",
                "summary": input?.name ?? ""
            }
        })

    readonly property var currentTool: dict[tool] ?? ({
            "icon": "build",
            "summary": JSON.stringify(input ?? {})
        })

    Layout.fillWidth: true
    implicitHeight: columnLayout.implicitHeight

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
    }

    ColumnLayout {
        id: columnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Padding.large

        RowLayout {
            Layout.preferredHeight: 40
            Layout.maximumHeight: 40
            Layout.fillWidth: true
            spacing: Padding.large

            StyledRect {
                implicitHeight: 35
                radius: height / 2
                implicitWidth: children[1].implicitWidth + Padding.massive
                color: Colors.colLayer1
                RowLayout {
                    anchors.centerIn: parent
                    Item {
                        width: 24
                        height: 24
                        rotation: root.expanded ? 0 : 180

                        Behavior on rotation {
                            Anim {}
                        }

                        Symbol {
                            anchors.centerIn: parent
                            icon: "keyboard_arrow_down"
                            iconSize: 24
                            fill: 1
                            color: Colors.colOnLayer1
                            rotation: root.expanded ? 0 : 180
                        }
                    }

                    Symbol {
                        text: root.currentTool?.icon
                        iconSize: 20
                        color: Colors.colOnLayer1
                    }

                    Symbol {
                        visible: text.length > 0
                        text: root.statusIcon
                        iconSize: 20
                        color: root.statusTint
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                truncate: true
                Layout.rightMargin: Padding.large
                Layout.alignment: Qt.AlignLeft
                text: this.methods.capitalizeFirstLetter(root.tool)
                font: Fonts.request("mono", "normal")
            }
        }

        Revealer {
            reveal: root.expanded
            Layout.fillWidth: true
            vertical: true
            revealChild: StyledRect {
                color: Colors.colLayer1
                radius: Rounding.normal
                implicitHeight: metaText.implicitHeight + 2 * Padding.large
                Layout.fillWidth: true

                StyledText {
                    id: metaText
                    anchors.fill: parent
                    anchors.margins: Padding.large
                    text: root.currentTool?.summary.length > 0 ? root.currentTool?.summary + (root.output?.length > 0 ? "\n" + root.output : "") : root.output
                    font: Fonts.request("mono", "normal")
                    color: Colors.colOnLayer1
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}
