import qs.services
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import org.kde.syntaxhighlighting as KDE

StyledRect {
    id: root

    property bool editing: parent?.editing ?? false
    property bool enableMouseSelection: parent?.enableMouseSelection ?? false
    property var segmentContent: parent?.segmentContent ?? ({})
    property var segmentLang: parent?.segmentLang ?? "txt"
    property bool isCommandRequest: segmentLang === "command"
    property var displayLang: (isCommandRequest ? "bash" : segmentLang)
    property var messageData: parent?.messageData ?? {}
    property bool thinking: false

    implicitHeight: Math.max(100, contentCol.implicitHeight + Padding.huge)
    Layout.fillWidth: true
    color: Colors.colLayer1
    radius: Rounding.huge
    enableBorders: true

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumHeight: 40
            Layout.preferredHeight: 40

            spacing: Padding.huge
            Layout.topMargin: Padding.small
            Layout.leftMargin: Padding.huge
            Layout.rightMargin: Padding.huge

            StyledText {
                leftPadding: Padding.large
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                Layout.fillWidth: true
                truncate: true
                font: Fonts.request("title", "large")
                color: Colors.colOnLayer2
                text: root.displayLang ? KDE.Repository.definitionForName(root.displayLang).name : "plain"
            }

            ButtonGroup {
                Layout.alignment: Qt.AlignVCenter
                AiMessageControlButton {
                    id: copyCodeButton
                    buttonIcon: activated ? "inventory" : "content_copy"

                    onClicked: {
                        Quickshell.clipboardText = segmentContent;
                        copyCodeButton.activated = true;
                        copyIconTimer.restart();
                    }

                    Timer {
                        id: copyIconTimer
                        interval: 1500
                        repeat: false
                        onTriggered: {
                            copyCodeButton.activated = false;
                        }
                    }
                    StyledToolTip {
                        text: qsTr("Copy code")
                    }
                }
                AiMessageControlButton {
                    id: saveCodeButton
                    buttonIcon: activated ? "check" : "download"

                    onClicked: {
                        const downloadPath = Paths.methods.trim(Paths.standard.downloads);
                        NoonUtils.execDetached(`echo '${TextUtils.shellSingleQuoteEscape(segmentContent)}' > '${downloadPath}/code.${segmentLang || "txt"}'`);
                        Quickshell.execDetached(["notify-send", qsTr("Code saved to file"), qsTr("Saved to %1").arg(`${downloadPath}/code.${segmentLang || "txt"}`), "-a", "Shell"]);
                        saveCodeButton.activated = true;
                        saveIconTimer.restart();
                    }

                    Timer {
                        id: saveIconTimer
                        interval: 1500
                        repeat: false
                        onTriggered: {
                            saveCodeButton.activated = false;
                        }
                    }
                    StyledToolTip {
                        text: qsTr("Save to Downloads")
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 0

            ScrollView {
                Layout.margins: Padding.large
                Layout.leftMargin: Padding.huge
                Layout.rightMargin: Padding.huge
                Layout.fillWidth: true
                implicitHeight: codeTextArea.contentHeight + 1
                contentWidth: codeTextArea.contentWidth - 1

                clip: true

                TextArea {
                    id: codeTextArea
                    Layout.fillWidth: true
                    readOnly: !editing
                    selectByMouse: enableMouseSelection || editing
                    renderType: Text.NativeRendering
                    font: Fonts.request("mono", "large", {
                        "hintingPreference": Font.PreferNoHinting
                    })
                    selectedTextColor: Colors.m3.m3onSecondaryContainer
                    selectionColor: Colors.colSecondaryContainer

                    color: root.thinking ? Colors.colSubtext : Colors.colOnLayer1

                    text: segmentContent
                    onTextChanged: segmentContent = text

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            const cursor = codeTextArea.cursorPosition;
                            codeTextArea.insert(cursor, "    ");
                            codeTextArea.cursorPosition = cursor + 4;
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_C) && event.modifiers == Qt.ControlModifier) {
                            codeTextArea.copy();
                            event.accepted = true;
                        }
                    }

                    SyntaxHighlighter {
                        textEdit: codeTextArea
                        _definition: root.displayLang || "plaintext"
                    }
                }
            }

            Loader {
                active: root.isCommandRequest && root.messageData.functionPending
                visible: active
                Layout.fillWidth: true
                Layout.margins: 6
                Layout.topMargin: 0
                sourceComponent: RowLayout {
                    Item {
                        Layout.fillWidth: true
                    }
                    ButtonGroup {
                        GroupButton {
                            contentItem: StyledText {
                                text: qsTr("Reject")
                                font.pixelSize: Fonts.sizes.small
                                color: Colors.colOnLayer2
                            }
                            onClicked: Ai.rejectCommand(root.messageData)
                        }
                        GroupButton {
                            toggled: true
                            contentItem: StyledText {
                                text: qsTr("Approve")
                                font.pixelSize: Fonts.sizes.small
                                color: Colors.colOnPrimary
                            }
                            onClicked: Ai.approveCommand(root.messageData)
                        }
                    }
                }
            }
        }
    }
}
