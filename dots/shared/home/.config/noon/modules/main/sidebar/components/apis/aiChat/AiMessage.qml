import qs.services
import qs.common
import qs.common.widgets
import qs.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property int messageIndex
    property var messageData
    property var messageInputField
    property bool enableMouseSelection: false
    property bool renderMarkdown: true
    property bool editing: false

    readonly property bool isLive: root.messageData ? !root.messageData.done : false
    readonly property list<var> messageBlocks: TextUtils.splitMarkdownBlocks(
        root.isLive ? Harness.liveContent : (root.messageData?.content ?? ""))

    anchors.left: parent?.left
    anchors.right: parent?.right
    clip: true
    height: Math.max(columnLayout.implicitHeight + Padding.massive, 50)

    HoverHandler {
        id: hovered
    }

    MessageLoadingIndicator {
        id: loading
        messageData: root.messageData
        blockCount: root.messageBlocks.length
        done: root.isLive ? Harness.liveDone : (root.messageData?.done ?? true)
        queued: root.messageData?.queued ?? false
    }

    ColumnLayout {
        id: columnLayout
        anchors.right: parent.right
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Padding.normal

        StyledText {
            visible: root.messageData?.queued ?? false
            Layout.alignment: Qt.AlignLeft
            text: "Queued"
            font.pixelSize: Fonts.sizes.small
            color: Colors.colSubtext
        }

        ColumnLayout {
            spacing: Padding.small
            Layout.fillWidth: true

            Repeater {
                model: ScriptModel {
                    values: root.messageBlocks
                }
                delegate: DelegateChooser {
                    role: "type"

                    DelegateChoice {
                        roleValue: "text"
                        MessageTextBlock {
                            editing: root.editing
                            renderMarkdown: root.renderMarkdown
                            enableMouseSelection: root.enableMouseSelection
                            segmentContent: modelData.content
                            messageData: root.messageData
                            done: root.isLive ? Harness.liveDone : (root.messageData?.done ?? false)
                            thinking: root.isLive ? Harness.liveThinking : false
                            forceDisableChunkSplitting: root.messageData?.content?.includes("```") ?? true
                        }
                    }

                    DelegateChoice {
                        roleValue: "code"
                        MessageCodeBlock {
                            editing: root.editing
                            enableMouseSelection: root.enableMouseSelection
                            segmentContent: modelData.content
                            segmentLang: modelData.lang
                            messageData: root.messageData
                            thinking: root.isLive ? Harness.liveThinking : false
                        }
                    }

                    DelegateChoice {
                        roleValue: "think"
                        MessageThinkBlock {
                            editing: actionBar.editing
                            renderMarkdown: root.renderMarkdown
                            enableMouseSelection: root.enableMouseSelection
                            segmentContent: modelData.content
                            messageData: root.messageData
                            done: root.isLive ? Harness.liveDone : (root.messageData?.done ?? false)
                            completed: modelData.completed ?? false
                        }
                    }
                }
            }
        }

        Repeater {
            model: root.messageData?.tools ?? []
            delegate: ToolCallBlock {
                required property var modelData
                Layout.fillWidth: true
                tool: modelData?.tool ?? ""
                callID: modelData?.callID ?? ""
                input: modelData?.input ?? ""
                output: modelData?.output ?? ""
                status: modelData.status
                raw: modelData
                messageData: root.messageData
            }
        }

        Flow {
            visible: (root.messageData?.annotationSources?.length ?? 0) > 0
            spacing: 5
            Layout.fillWidth: true

            Repeater {
                model: ScriptModel {
                    values: root.messageData?.annotationSources ?? []
                }
                delegate: AnnotationSourceButton {
                    required property var modelData
                    displayText: modelData.text
                    url: modelData.url
                }
            }
        }

        MessageActionBar {
            id: actionBar
            // Tool-only step bubbles (one db row per tool call, no text)
            // get no bar: copy of "" is useless and N steps meant N bars.
            // Delete/regenerate stay on the text bubbles.
            readonly property bool hasText: ((root.isLive ? Harness.liveContent : (root.messageData?.content ?? "")).trim().length > 0)
            visible: (root.isLive ? Harness.liveDone : (messageData?.done ?? true)) && hasText
            Layout.leftMargin: Padding.large
            Layout.alignment: Qt.AlignLeft
            messageIndex: root.messageIndex
            messageData: root.messageData
        }
    }
}
