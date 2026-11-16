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
    readonly property string thinkSource: root.isLive ? Harness.liveThinkText : (root.messageData?.thinkText ?? "")
    readonly property bool thinkDone: root.isLive ? ((Harness.liveContent ?? "").length > 0) : true
    readonly property list<var> messageBlocks: ((root.thinkSource.trim().length > 0) ? [{
                type: "think",
                content: root.thinkSource,
                completed: root.thinkDone
            }] : []).concat(TextUtils.splitMarkdownBlocks(root.isLive ? Harness.liveContent : (root.messageData?.content ?? "")))

    readonly property var toolGroups: {
        const tools = root.messageData?.tools ?? [];
        if (tools.length === 0) return [];

        const groups = [];
        let current = [];

        for (let i = 0; i < tools.length; i++) {
            const t = tools[i];
            const needsApproval = (root.messageData?.functionPending ?? false) &&
                  t.callID !== "" &&
                  t.callID === root.messageData?.permissionCallID;

            if (needsApproval) {
                if (current.length > 0) {
                    groups.push(current);
                    current = [];
                }
                groups.push([t]);
            } else {
                current.push(t);
            }
        }
        if (current.length > 0) groups.push(current);
        return groups;
    }

    anchors.left: parent?.left
    anchors.right: parent?.right
    clip: true
    height: Math.max(columnLayout.implicitHeight + Padding.massive, 50)

    HoverHandler {
        id: hovered
    }

    ColumnLayout {
        id: columnLayout
        anchors.right: parent.right
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Padding.normal

        MessageLoadingIndicator {
            id: loading
            visible: loading.loading
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            messageData: root.messageData
            blockCount: root.messageBlocks.length
            done: root.isLive ? Harness.liveDone : (root.messageData?.done ?? true)
            queued: root.messageData?.queued ?? false
        }

        StyledText {
            visible: root.messageData?.queued ?? false
            Layout.alignment: Qt.AlignLeft
            text: "Queued"
            font.pixelSize: Fonts.sizes.small
            color: Colors.colSubtext
        }

        Repeater {
            model: root.toolGroups
            delegate: Loader {
                required property var modelData
                property var items: modelData
                Layout.fillWidth: true
                sourceComponent: modelData.length > 1 ? groupComp : singleComp
            }
        }

        Component {
            id: singleComp
            ToolCallBlock {
                property var item: parent.items[0]
                tool: item?.tool ?? ""
                callID: item?.callID ?? ""
                input: item?.input ?? ""
                output: item?.output ?? ""
                status: item?.status ?? ""
                raw: item
                messageData: root.messageData
            }
        }

        Component {
            id: groupComp
            ToolCallGroup {
                tools: parent.items
                messageData: root.messageData
            }
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
                            renderMarkdown: root.renderMarkdown && (modelData.content ?? "").length < 8000
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
            readonly property bool hasText: ((root.isLive ? Harness.liveContent : (root.messageData?.content ?? "")).trim().length > 0)
            visible: (root.isLive ? Harness.liveDone : (messageData?.done ?? true)) && hasText
            Layout.leftMargin: Padding.large
            Layout.alignment: Qt.AlignLeft
            messageIndex: root.messageIndex
            messageData: root.messageData
        }
    }
}
