import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.common
import qs.common.widgets
import qs.common.functions
import "aiChat"

SidebarItemContainer {
    id: root

    property real padding: Padding.huge
    property alias focusItem: messageInputField
    property var inputField: messageInputField
    property string commandPrefix: "/"
    property bool isRecording: false

    readonly property var allCommands: [
        {
            name: "new",
            description: qsTr("Start New Session"),
            execute: args => Harness.newSession()
        },
        {
            name: "session",
            description: qsTr("Select Session"),
            execute: args => Harness.loadChat(args.join(" ").trim())
        },
        {
            name: "scale",
            description: qsTr("Change response's font scale by decimal."),
            execute: args => Mem.states.sidebar.apis.fontScale = args.join(" ").trim()
        },
        {
            name: "model",
            description: qsTr("Choose model"),
            execute: args => Harness.setModel(args[0])
        },
        {
            name: "effort",
            description: qsTr("Choose effort"),
            execute: args => Harness.setEffort(args[0])
        },
        {
            name: "agent",
            description: qsTr("Choose agent mode (plan/build)"),
            execute: args => Harness.setAgent(args[0])
        },
        {
            name: "skill",
            description: qsTr("Arm Skill (agent loads it via skill tool)"),
            execute: args => Harness.setSkill(args[0])
        },
        {
            name: "status",
            description: qsTr("Show effective model/effort/agent/skill/session"),
            execute: () => Harness.showStatus()
        },
        {
            name: "clear",
            description: qsTr("Clear visible messages (agent memory kept, use /new for fresh)"),
            execute: () => Harness.clearMessages()
        },
        {
            name: "more",
            description: qsTr("Load older messages"),
            execute: () => Harness.loadMoreMessages()
        },
        {
            name: "test",
            description: qsTr("Send LaTeX test messages"),
            execute: () => {
                Harness.clearMessages();
                const tests = ["Inline: $$E = mc^2$$", "Quadratic: $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$", "Integral: $$\\int_{a}^{b} f(x)\\,dx = F(b) - F(a)$$", "Matrix: $$\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}$$", "Summation: $$\\sum_{k=1}^{n} \\frac{1}{k} \\approx \\ln(n) + \\gamma$$", "Greek: $$\\alpha \\beta \\gamma \\delta \\epsilon \\theta \\pi \\sigma \\omega \\phi \\psi \\mu$$", "Limit: $$\\lim_{x \\to 0} \\frac{\\sin x}{x} = 1$$", "Trig: $$\\sin^2 \\theta + \\cos^2 \\theta = 1$$", "Nested fraction: $$\\frac{1 + \\frac{1}{x}}{1 - \\frac{1}{x}}$$", "Piecewise: $$f(x) = \\begin{cases} x^2 & x \\ge 0 \\\\ -x & x < 0 \\end{cases}$$", "Decorations: $$\\hat{a} \\; \\bar{b} \\; \\vec{c} \\; \\dot{d} \\; \\ddot{e}$$", "Binomial: $$\\binom{n}{k} = \\frac{n!}{k!(n-k)!}$$", "Text in math: $$\\text{area} = \\pi r^2 \\quad \\text{for } r \\ge 0$$", "Set builder: $$\\{ x \\in \\mathbb{R} \\mid |x| < 1 \\}$$",];
                tests.forEach(t => Harness.addMessage(t, "ai"));
            }
        }
    ]

    ChatUtils {
        id: utils
        inputField: messageInputField
        suggestionsView: suggestions
        scrollView: chatView.listView
        commands: root.allCommands
        commandPrefix: root.commandPrefix
        onExpandRequested: root.expandRequested()
    }

    // Ready surface: thin delegations only, logic lives in utils.
    function sendText(text) {
        utils.sendText(text);
    }

    function updateSuggestions() {
        utils.updateSuggestions();
    }

    function handleInputKeyPress(event) {
        utils.handleInputKeyPress(event);
    }

    Keys.onPressed: event => utils.handleGlobalKey(event)

    Connections {
        target: Harness
        function onPermissionAsked(title) {
            utils.notifyPermissionAsked(title);
        }
    }

    Connections {
        target: SpeechService
        enabled: SpeechService.isListening
        function onSpeechChanged() {
            if (SpeechService.speech.length > 0) {
                messageInputField.text = SpeechService.speech;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.padding

        ChatView {
            id: chatView
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        DescriptionBox {
            text: utils.suggestionList[suggestions.selectedIndex]?.description ?? ""
            showArrows: utils.suggestionList.length > 1
            pageText: utils.suggestionList.length > suggestions.pageSize ? `${suggestions.pageOffset + 1}-${Math.min(suggestions.pageOffset + suggestions.pageSize, utils.suggestionList.length)}/${utils.suggestionList.length}` : ""
        }

        LayerRect {
            colBackground: messageInputField.focus ? Colors.colLayer3 : Colors.colLayer2
            Layout.fillWidth: true
            radius: Rounding.huge
            implicitHeight: Math.max(inputAreaCol.implicitHeight + Padding.huge, 45)
            clip: true

            ColumnLayout {
                id: inputAreaCol
                spacing: Padding.huge

                anchors {
                    fill: parent
                    margins: Padding.normal
                }

                StyledRect {
                    implicitHeight: 50
                    Layout.fillWidth: true
                    radius: Rounding.large
                    color: Colors.colSecondaryContainer
                    visible: Harness.pendingPermission !== null

                    RowLayout {
                        anchors.fill: parent

                        anchors.leftMargin: Padding.huge
                        anchors.rightMargin: Padding.large

                        anchors.margins: Padding.normal
                        spacing: Padding.small

                        Symbol {
                            icon: "key"
                            iconSize: 20
                            fill: 1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.rightMargin: Padding.small
                            truncate: true
                            text: (Harness.pendingPermission?.title ?? "") + " needs approval"
                            font: Fonts.request("main", "normal")
                            color: Colors.colOnSecondaryContainer
                        }
                        RippleButtonWithIcon {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitSize: 34
                            materialIcon: "close"
                            downAction: () => Harness.answerPending(false)
                        }
                        RippleButtonWithIcon {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            toggled: true
                            implicitSize: 34
                            materialIcon: "check"
                            downAction: () => Harness.answerPending(true)
                        }
                        RippleButtonWithIcon {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitSize: 34
                            materialIcon: "done_all"
                            colBackground: Colors.colSuccess
                            iconColor: Colors.colOnSuccess
                            downAction: () => Harness.answerAll()
                        }
                    }
                }

                FlowButtonGroup {
                    id: suggestions
                    visible: utils.suggestionList.length > 0 && messageInputField.text.length > 0
                    property int selectedIndex: 0
                    property int pageSize: 10
                    property int pageOffset: 0
                    Layout.fillWidth: true

                    spacing: Padding.normal
                    Layout.topMargin: Padding.normal
                    Layout.leftMargin: Padding.small
                    Layout.rightMargin: Padding.small

                    function acceptSuggestion(word) {
                        return utils.acceptSuggestion(word);
                    }

                    function move(delta) {
                        utils.moveSelection(delta);
                    }

                    function acceptSelectedWord() {
                        return utils.acceptSelectedWord();
                    }

                    Repeater {
                        id: suggestionRepeater
                        model: utils.suggestionList.slice(suggestions.pageOffset, suggestions.pageOffset + suggestions.pageSize)
                        delegate: ApiCommandButton {
                            id: commandButton
                            readonly property bool isSelected: suggestions.selectedIndex === suggestions.pageOffset + index
                            colBackground: isSelected ? Colors.colSecondary : Colors.colSecondaryContainer
                            bounce: false
                            contentItem: StyledText {
                                font: Fonts.request("mono", "normal")
                                color: isSelected ? Colors.colOnSecondary : Colors.colOnSecondaryContainer
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.displayName ?? modelData.name
                            }
                            onHoveredChanged: if (commandButton.hovered)
                                suggestions.selectedIndex = suggestions.pageOffset + index
                            onClicked: suggestions.acceptSuggestion(modelData.name)
                        }
                    }
                }

                RowLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 0

                    StyledTextArea {
                        id: messageInputField
                        wrapMode: TextArea.Wrap
                        Layout.fillWidth: true
                        padding: Padding.normal
                        color: Colors.m3.m3onSurfaceVariant
                        placeholderText: "Its " + Harness.getModel().name.split('/')[1]
                        background: null
                        font: Fonts.request("main", "large")
                        onTextChanged: {
                            if (text.length === 0) {
                                utils.suggestionList = [];
                                return;
                            }
                            root.updateSuggestions();
                        }
                        Keys.onPressed: event => root.handleInputKeyPress(event)
                    }

                    Item {
                        id: sendButton
                        implicitHeight: 50
                        implicitWidth: 50
                        readonly property bool toggled: Harness.isResponding || messageInputField.text.length > 0

                        SequentialAnimation {
                            loops: Animation.Infinite
                            running: SpeechService.isListening || Harness.isResponding || root.isRecording
                            PropertyAction {
                                target: shape
                                property: "rotation"
                                value: 0
                            }
                            Anim {
                                target: shape
                                property: "rotation"
                                from: 0
                                to: 360
                                duration: 4500
                            }
                            onStopped: shape.rotation = 0
                        }

                        MaterialShape {
                            id: shape
                            implicitSize: 38
                            anchors.centerIn: parent
                            shape: {
                                if (!Harness.isResponding && messageInputField.text.length === 0)
                                    return MaterialShape.Shape.Cookie6Sided;
                                if (Harness.isResponding)
                                    return MaterialShape.Shape.Cookie12Sided;
                                return MaterialShape.Shape.Clover8Leaf;
                            }
                            color: Colors.colPrimary
                            Behavior on rotation {
                                enabled: !Harness.isResponding
                                Anim {}
                            }
                        }

                        Symbol {
                            text: {
                                if (!Harness.isResponding && messageInputField.text.length === 0)
                                    return "mic";
                                if (Harness.isResponding)
                                    return "stop";
                                return "arrow_upward";
                            }
                            fill: 1
                            font.pixelSize: 18
                            anchors.centerIn: parent
                            color: Colors.colOnPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: sendButton.toggled
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (Harness.isResponding) {
                                    Harness.stop();
                                } else if (messageInputField.text.length > 0) {
                                    const text = messageInputField.text;
                                    messageInputField.clear();
                                    root.sendText(text);
                                } else {
                                    console.log("Listening...");
                                    SpeechService.listen();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
