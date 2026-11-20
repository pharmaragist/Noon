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
    readonly property bool editing: actionBar.editing

    anchors.left: parent?.left
    anchors.right: parent?.right
    clip: true
    height: Math.max(contentCol.implicitHeight + Padding.silly, 55)

    HoverHandler {
        id: hovered
    }

    ColumnLayout {
        id: contentCol
        anchors.right: parent.right
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Padding.normal

        StyledText {
            visible: root.messageData?.queued ?? false
            Layout.rightMargin: Padding.massive + 5
            Layout.alignment: Qt.AlignRight
            text: "Queued"
            font.pixelSize: Fonts.sizes.small
            color: Colors.colSubtext
        }

        WrapperRectangle {
            Layout.maximumWidth: root.width - Padding.huge
            Layout.alignment: Qt.AlignRight
            Layout.rightMargin: Padding.huge
            color: Colors.colLayer2
            radius: Rounding.huge
            margin: Padding.large
            leftMargin: Padding.huge
            rightMargin: Padding.huge

            child: ColumnLayout {
                spacing: Padding.normal

                Repeater {
                    model: root.messageData?.attachments ?? []

                    delegate: StyledRect {
                        id: fileCard
                        required property var modelData
                        readonly property string path: String(modelData ?? "")
                        readonly property string fileName: FileUtils.fileNameForPath(path)
                        readonly property string extension: {
                            const idx = fileCard.fileName.lastIndexOf(".");
                            return idx > 0 ? fileCard.fileName.slice(idx + 1).toLowerCase() : "";
                        }
                        readonly property string iconName: {
                            const ext = fileCard.extension;
                            if (["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp"].includes(ext))
                                return "image";
                            if (["pdf", "md", "txt", "doc", "docx"].includes(ext))
                                return "description";
                            if (["zip", "tar", "gz", "7z"].includes(ext))
                                return "folder_zip";
                            return "draft";
                        }

                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: Rounding.normal
                        color: Colors.colLayer3
                        clip: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Padding.small
                            spacing: Padding.normal

                            StyledRect {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: Rounding.small
                                color: Colors.colSecondaryContainer

                                Symbol {
                                    anchors.centerIn: parent
                                    icon: fileCard.iconName
                                    iconSize: 17
                                    fill: 1
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: fileCard.fileName
                                    font: Fonts.request("main", "small")
                                    color: Colors.colOnLayer3
                                    truncate: true
                                }
                                StyledText {
                                    visible: fileCard.extension.length > 0
                                    text: fileCard.extension.toUpperCase()
                                    font.pixelSize: Fonts.sizes.verysmall
                                    color: Colors.colSubtext
                                }
                            }
                        }
                    }
                }

                MessageTextBlock {
                    Layout.fillWidth: true
                    focus: root.editing
                    editing: root.editing
                    renderMarkdown: root.renderMarkdown
                    enableMouseSelection: root.enableMouseSelection
                    segmentContent: root.messageData?.content ?? ""
                    messageData: root.messageData
                    done: root.messageData?.done ?? false
                    forceDisableChunkSplitting: root.messageData?.content?.includes("```") ?? true
                }
            }
        }

        MessageActionBar {
            id: actionBar
            Layout.alignment: Qt.AlignRight
            Layout.rightMargin: Padding.massive
            messageIndex: root.messageIndex
            messageData: root.messageData
        }
    }
}
