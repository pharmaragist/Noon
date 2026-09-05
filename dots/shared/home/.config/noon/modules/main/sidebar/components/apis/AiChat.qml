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
    property var suggestionList: []

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
            name: "skill",
            description: qsTr("Choose Skill"),
            execute: args => Harness.setSkill(args[0])
        },
        {
            name: "clear",
            description: qsTr("Clear chat history"),
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

    function sendText(text) {
        if (text.trim().length === 0)
            return;
        const parts = text.trim().split(" ");
        const cmd = root.allCommands.find(c => c.name === parts[0].substring(1));
        text.startsWith(root.commandPrefix) && cmd ? cmd.execute(parts.slice(1)) : Harness.sendUserMessage(text);
        chatView.listView.positionViewAtEnd();
    }

    function handleCommandSuggestions(query) {
        const source = root.allCommands.map(cmd => ({
                    name: cmd.name,
                    prepared: Fuzzy.prepare(cmd.name)
                }));
        const results = query.length === 0 ? root.allCommands.map(cmd => ({
                    target: cmd.name
                })) : Fuzzy.go(query, source, {
            all: true,
            key: "name"
        });
        root.suggestionList = results.map(r => ({
                    name: root.commandPrefix + r.target,
                    displayName: root.commandPrefix + r.target,
                    description: root.allCommands.find(c => c.name === r.target)?.description ?? ""
                }));
    }

    function handleModelSuggestions() {
        const query = messageInputField.text.split(" ")[1] ?? "";
        const source = Harness.modelList.map(m => ({
                    name: m,
                    prepared: Fuzzy.prepare(m)
                }));
        const results = query.length === 0 ? Harness.modelList.map(m => ({
                    target: m
                })) : Fuzzy.go(query, source, {
            all: true,
            key: "name"
        });
        const isFirst = messageInputField.text.trim().split(" ").length === 1;
        root.suggestionList = results.map(r => ({
                    name: (isFirst ? root.commandPrefix + "model " : "") + r.target,
                    displayName: r.target,
                    description: qsTr("Set model to %1").arg(r.target)
                }));
    }

    function handleEffortSuggestions() {
        const query = messageInputField.text.split(" ")[1] ?? "";
        const list = Harness.effortOptions.length > 0 ? Harness.effortOptions : Harness.effortList;
        const source = list.map(m => ({
                    name: m,
                    prepared: Fuzzy.prepare(m)
                }));
        const results = query.length === 0 ? list.map(m => ({
                    target: m
                })) : Fuzzy.go(query, source, {
            all: true,
            key: "name"
        });
        const isFirst = messageInputField.text.trim().split(" ").length === 1;
        root.suggestionList = results.map(r => ({
                    name: (isFirst ? root.commandPrefix + "effort " : "") + r.target,
                    displayName: r.target,
                    description: qsTr("Set effort to %1").arg(r.target)
                }));
    }

    function handleSkillsSuggestions() {
        const query = messageInputField.text.split(" ")[1] ?? "";
        const source = Harness.skills.map(f => ({
                    name: f,
                    prepared: Fuzzy.prepare(f)
                }));
        const results = query.length === 0 ? Harness.skills.map(f => ({
                    target: f
                })) : Fuzzy.go(query, source, {
            all: true,
            key: "name"
        });
        const isFirst = messageInputField.text.trim().split(" ").length === 1;
        root.suggestionList = results.map(r => ({
                    name: (isFirst ? root.commandPrefix + "skill " : "") + r.target,
                    displayName: r.target,
                    description: qsTr("Load %1 skill").arg(r.target)
                }));
    }

    function handleSessionsSuggestions() {
        const query = messageInputField.text.split(" ")[1] ?? "";
        const source = Harness.sessions.map(s => ({
                    name: s.title,
                    prepared: Fuzzy.prepare(s.title),
                    obj: s
                }));
        const results = query.length === 0 ? Harness.sessions.map(s => ({
                    target: s
                })) : Fuzzy.go(query, source, {
            all: true,
            key: "name"
        }).map(r => ({
                    target: r.obj?.obj
                }));
        const isFirst = messageInputField.text.trim().split(" ").length === 1;
        root.suggestionList = results.map(r => ({
                    name: (isFirst ? root.commandPrefix + "session " : "") + r.target.id,
                    displayName: r.target.title,
                    description: qsTr("Session from %1").arg(root.friendlySessionTime(r.target.updated))
                }));
    }

    readonly property var argHandlers: ({
            "model": handleModelSuggestions,
            "effort": handleEffortSuggestions,
            "skill": handleSkillsSuggestions,
            "session": handleSessionsSuggestions
        })

    function friendlySessionTime(ts) {
        const secs = Math.max(0, Math.floor((new Date() - new Date(ts)) / 1000));
        if (secs < 60)
            return "just now";
        const mins = Math.floor(secs / 60);
        if (mins < 60)
            return mins + " min ago";
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return hours + " h ago";
        const days = Math.floor(hours / 24);
        if (days < 7)
            return days + " d ago";
        return Qt.formatDateTime(new Date(ts), "MMM d, yyyy");
    }

    function updateSuggestions() {
        suggestions.selectedIndex = 0;
        suggestions.pageOffset = 0;
        const trimmed = messageInputField.text.trim();
        const words = trimmed.split(" ");
        const commandWord = words[0].substring(1);
        const hasArg = words.length > 1;

        if (!trimmed.startsWith(root.commandPrefix)) {
            root.suggestionList = [];
            return;
        }

        if (hasArg) {
            const handler = root.argHandlers[commandWord];
            handler ? handler() : (root.suggestionList = []);
        } else {
            const isExact = root.allCommands.some(c => c.name === commandWord);
            isExact && root.argHandlers[commandWord] ? root.argHandlers[commandWord]() : handleCommandSuggestions(commandWord);
        }
    }

    Keys.onPressed: event => {
        messageInputField.forceActiveFocus();
        if (event.modifiers & Qt.ControlModifier) {
            switch (event.key) {
            case Qt.Key_L:
                Harness.clearMessages();
                break;
            case Qt.Key_R:
                Harness.regenerate(Harness.messageIDs.length - 1);
                break;
            case Qt.Key_O:
                root.expandRequested();
                break;
            }
            event.accepted = true;
        }
    }

    // File managers copy files as a text/uri-list
    // ("file:///a\nfile:///b"). Detect that shape so plain Ctrl+V drops
    // local paths instead of raw URIs; otherwise returns [] and the field
    // keeps its default paste behavior.
    function clipboardFilePaths() {
        const lines = (Quickshell.clipboardText || "").split("\n").map(l => l.trim()).filter(l => l.length > 0);
        if (lines.length === 0 || !lines.every(l => l.startsWith("file://")))
            return [];
        return lines.map(l => {
            let p;
            try {
                p = decodeURIComponent(l.replace(/^file:\/\//, ""));
            } catch (e) {
                p = l.replace(/^file:\/\//, "");
            }
            return p.includes(" ") ? `"${p}"` : p;
        });
    }

    function handleInputKeyPress(event) {
        switch (event.key) {
        case Qt.Key_Tab:
            suggestions.acceptSelectedWord();
            event.accepted = true;
            break;
        case Qt.Key_Up:
            if (suggestions.visible) {
                suggestions.move(-1);
                event.accepted = true;
            }
            break;
        case Qt.Key_Down:
            if (suggestions.visible) {
                suggestions.move(1);
                event.accepted = true;
            }
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (event.modifiers & Qt.ShiftModifier) {
                messageInputField.insert(messageInputField.cursorPosition, "\n");
            } else {
                let text = messageInputField.text;
                if (suggestions.visible && suggestions.selectedIndex !== -1)
                    text = suggestions.acceptSelectedWord();
                messageInputField.clear();
                root.sendText(text);
            }
            event.accepted = true;
            break;
        default:
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                if (event.modifiers & Qt.ShiftModifier) {
                    messageInputField.text += Quickshell.clipboardText;
                    event.accepted = true;
                    return;
                }
                const paths = root.clipboardFilePaths();
                if (paths.length > 0) {
                    messageInputField.insert(messageInputField.cursorPosition, paths.join(" "));
                    event.accepted = true;
                }
            }
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
            text: root.suggestionList[suggestions.selectedIndex]?.description ?? ""
            showArrows: root.suggestionList.length > 1
            pageText: root.suggestionList.length > suggestions.pageSize ? `${suggestions.pageOffset + 1}-${Math.min(suggestions.pageOffset + suggestions.pageSize, root.suggestionList.length)}/${root.suggestionList.length}` : ""
        }

        LayerRect {
            colBackground: Colors.colLayer2
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

                FlowButtonGroup {
                    id: suggestions
                    visible: root.suggestionList.length > 0 && messageInputField.text.length > 0
                    property int selectedIndex: 0
                    property int pageSize: 10
                    property int pageOffset: 0
                    Layout.fillWidth: true

                    spacing: Padding.normal
                    Layout.topMargin: Padding.normal
                    Layout.leftMargin: Padding.small
                    Layout.rightMargin: Padding.small

                    function acceptSuggestion(word) {
                        const words = messageInputField.text.trim().split(/\s+/);
                        words[words.length - 1] = word;
                        messageInputField.text = words.join(" ") + " ";
                        messageInputField.cursorPosition = messageInputField.text.length;
                        messageInputField.forceActiveFocus();
                        return messageInputField.text;
                    }

                    function move(delta) {
                        const len = root.suggestionList.length;
                        if (len === 0) {
                            selectedIndex = 0;
                            return;
                        }
                        const next = selectedIndex + delta;
                        if (next < 0 || next >= len)
                            return;
                        selectedIndex = next;
                        pageOffset = Math.max(0, Math.min(Math.floor(next / pageSize) * pageSize, len - pageSize));
                    }

                    function acceptSelectedWord() {
                        if (selectedIndex >= 0 && selectedIndex < root.suggestionList.length)
                            return suggestions.acceptSuggestion(root.suggestionList[selectedIndex].name);
                        return null;
                    }

                    Repeater {
                        id: suggestionRepeater
                        model: root.suggestionList.slice(suggestions.pageOffset, suggestions.pageOffset + suggestions.pageSize)
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
                        color: activeFocus ? Colors.m3.m3onSurface : Colors.m3.m3onSurfaceVariant
                        placeholderText: qsTr('Ask %1 AnyThing ... "%2" for commands').arg(Harness.getModel().name.split('/')[1]).arg(root.commandPrefix)
                        background: null
                        font: Fonts.request("main", "large")
                        onTextChanged: {
                            if (text.length === 0) {
                                root.suggestionList = [];
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
