import qs.services
import qs.common
import qs.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

StyledRect {
    id: root

    property string tool
    property var input
    property string output
    property string status
    property bool expanded: false
    property var messageData

    readonly property bool completed: status === "completed"
    readonly property bool pendingApproval: status === "pending" && (messageData?.functionPending ?? false) && callID === messageData?.permissionCallID

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
                "summary": (input?.pattern ?? "") + " " + (input?.path ?? "")
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
    clip: true
    color: Colors.colLayer2
    radius: Rounding.normal
    implicitWidth: parent?.width ?? 0
    implicitHeight: mainColumn?.implicitHeight

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Padding.tiny

        Item {
            Layout.fillWidth: true
            Layout.margins: Padding.normal
            height: 30
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
            RowLayout {
                anchors.fill: parent
                spacing: Padding.small

                Symbol {
                    text: root.currentTool.icon
                    font.pixelSize: 20
                    color: root.completed ? Colors.colOnLayer2 : Colors.colSubtext
                }

                StyledText {
                    text: root.tool
                    font: Fonts.request("mono", Fonts.sizes.normal)
                    color: Colors.colOnSurface
                }

                StyledText {
                    text: root.currentTool.summary
                    font.pixelSize: Fonts.sizes.small
                    color: Colors.colSubtext
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    maximumLineCount: 1
                }

                Symbol {
                    text: root.expanded ? "expand_less" : "expand_more"
                    font.pixelSize: Fonts.sizes.normal
                    color: Colors.colSubtext
                }
            }
        }

        RowLayout {
            visible: root.pendingApproval
            Layout.leftMargin: Padding.normal
            Layout.rightMargin: Padding.normal
            spacing: Padding.small

            StyledText {
                text: "Pending approval"
                font.pixelSize: Fonts.sizes.small
                color: Colors.colSubtext
                Layout.fillWidth: true
            }

            RippleButton {
                buttonText: "Reject"
                colBackground: Colors.colLayer3
                onClicked: Ai.rejectCommand(root.messageData)
            }
            RippleButton {
                buttonText: "Approve"
                colBackground: Colors.colLayer3
                onClicked: Ai.approveCommand(root.messageData)
            }
        }

        StyledLoader {
            shown: root.expanded
            animationDuration: Animations.durations.verysmall
            Layout.fillWidth: true
            Layout.leftMargin: Padding.normal
            Layout.rightMargin: Padding.normal
            Layout.bottomMargin: Padding.normal

            sourceComponent: StyledRect {
                color: Colors.colLayer3
                radius: Rounding.normal
                implicitHeight: outputText.implicitHeight + Padding.normal * 2
                TextArea {
                    id: outputText
                    anchors.fill: parent
                    anchors.margins: Padding.normal
                    text: root.output?.length > 0 ? root.output : "No output"
                    font: Fonts.request("mono", Fonts.sizes.small)
                    color: Colors.colOnSurface
                    wrapMode: Text.WrapAnywhere
                    textFormat: TextEdit.MarkdownText
                    background: null
                }
            }
        }
    }
}
