import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.qmlmodels
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
                const tests = [
                    "Inline: $$E = mc^2$$",
                    "Quadratic: $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$",
                    "Integral: $$\\int_{a}^{b} f(x)\\,dx = F(b) - F(a)$$",
                    "Matrix: $$\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}$$",
                    "Summation: $$\\sum_{k=1}^{n} \\frac{1}{k} \\approx \\ln(n) + \\gamma$$",
                    "Greek: $$\\alpha \\beta \\gamma \\delta \\epsilon \\theta \\pi \\sigma \\omega \\phi \\psi \\mu$$",
                    "Limit: $$\\lim_{x \\to 0} \\frac{\\sin x}{x} = 1$$",
                    "Trig: $$\\sin^2 \\theta + \\cos^2 \\theta = 1$$",
                    "Nested fraction: $$\\frac{1 + \\frac{1}{x}}{1 - \\frac{1}{x}}$$",
                    "Piecewise: $$f(x) = \\begin{cases} x^2 & x \\ge 0 \\\\ -x & x < 0 \\end{cases}$$",
                    "Decorations: $$\\hat{a} \\; \\bar{b} \\; \\vec{c} \\; \\dot{d} \\; \\ddot{e}$$",
                    "Binomial: $$\\binom{n}{k} = \\frac{n!}{k!(n-k)!}$$",
                    "Text in math: $$\\text{area} = \\pi r^2 \\quad \\text{for } r \\ge 0$$",
                    "Set builder: $$\\{ x \\in \\mathbb{R} \\mid |x| < 1 \\}$$"
                ];
                tests.forEach(t => Harness.addMessage(t, "ai"));
            }
        }
    ]

    function sendText(text) {
        const trimmed = text.trim();
        const paths = Harness._pendingAnnotations.map(u => u.replace(/^file:\/\//, ""));
        const payload = paths.length > 0
            ? (trimmed.length > 0 ? trimmed + "\n\nAttachments:\n" + paths.join("\n") : paths.join("\n"))
            : text;

        utils.sendText(payload);
        Harness.clearAnnotations();
    }

    function updateSuggestions() {
        utils.updateSuggestions();
    }

    function handleInputKeyPress(event) {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
            if (suggestions.visible) {
                utils.handleInputKeyPress(event);
                return;
            }
            if (messageInputField.text.trim().length > 0 || Harness._pendingAnnotations.length > 0) {
                const text = messageInputField.text;
                messageInputField.clear();
                root.sendText(text);
                event.accepted = true;
                return;
            }
        }
        utils.handleInputKeyPress(event);
    }

    function tryPasteAttachment() {
        const clip = (Quickshell.clipboardText ?? "").trim();
        if (clip.includes("file://")) {
            const lines = clip.split(/\r?\n/).map(s => s.trim()).filter(s => s.startsWith("file://"));
            return Harness.addAnnotations(lines);
        }

        const isCliphistBinary = /^\[\[ binary data .+ \]\]$/.test(clip);
        const top = ClipboardService.entries[0];
        if ((clip.length === 0 || isCliphistBinary) && top?.isImage) {
            const imgUri = ClipboardService.latestImageUri();
            if (imgUri.length > 0)
                return Harness.addAnnotations([imgUri]);
        }

        return false;
    }

    Keys.onPressed: event => utils.handleGlobalKey(event)

    ChatUtils {
        id: utils
        inputField: messageInputField
        suggestionsView: suggestions
        scrollView: chatView.listView
        commands: root.allCommands
        commandPrefix: root.commandPrefix
        onExpandRequested: root.expandRequested()
    }

    Connections {
        target: Harness
        function onPermissionAsked(title) {
            utils.notifyPermissionAsked(title);
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => {
            if (drop.hasUrls && !Harness.addAnnotations(drop.urls)) {
                messageInputField.text += " " + drop.urls.join(" ");
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
            pageText: utils.suggestionList.length > suggestions.pageSize
                ? `${suggestions.pageOffset + 1}-${Math.min(suggestions.pageOffset + suggestions.pageSize, utils.suggestionList.length)}/${utils.suggestionList.length}`
                : ""
        }

        LayerRect {
            colBackground: dropArea.containsDrag ? Colors.colLayer3Active : messageInputField.focus ? Colors.colLayer3 : Colors.colLayer2
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
                        anchors {
                            fill: parent
                            topMargin: Padding.normal
                            bottomMargin: Padding.normal
                            leftMargin: Padding.huge
                            rightMargin: Padding.large
                        }
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

                StyledRect {
                    id: annotationsArea
                    readonly property bool hasAttachments: Harness._pendingAnnotations.length > 0

                    radius: Rounding.large
                    color: Colors.colLayer2
                    Layout.fillWidth: true
                    implicitHeight: hasAttachments ? 75 : 0
                    opacity: hasAttachments ? 1 : 0
                    visible: implicitHeight > 0
                    clip: true
                    bouncy: false

                    ScrollEdgeFade {
                        target: annotationsList
                        color: Colors.colLayer3
                    }

                    ListView {
                        id: annotationsList
                        anchors.fill: parent
                        anchors.margins: Padding.small
                        orientation: ListView.Horizontal
                        spacing: Padding.small
                        model: ScriptModel {
                            values: Harness._pendingAnnotations.map(uri => {
                                const ext = FileUtils.getEscapedFileExtension(uri).toLowerCase();
                                return {
                                    uri: uri,
                                    extension: ext,
                                    isImage: ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "avif"].includes(ext)
                                };
                            })
                        }
                        delegate: DelegateChooser {
                            role: "isImage"

                            DelegateChoice {
                                roleValue: true
                                AttachmentShell {
                                    required property var modelData
                                    implicitWidth: 75
                                    uri: modelData.uri

                                    Image {
                                        id: thumb
                                        anchors.fill: parent
                                        source: modelData.uri
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                        sourceSize.width: 150
                                        sourceSize.height: 150

                                        Timer {
                                            interval: 120
                                            repeat: true
                                            running: thumb.status === Image.Error || thumb.status === Image.Null
                                            property int attempts: 0
                                            onTriggered: {
                                                if (++attempts > 15) {
                                                    stop();
                                                    return;
                                                }
                                                const src = thumb.source;
                                                thumb.source = "";
                                                thumb.source = src;
                                            }
                                        }
                                    }
                                }
                            }

                            DelegateChoice {
                                roleValue: false
                                AttachmentShell {
                                    required property var modelData
                                    implicitWidth: 200
                                    uri: modelData.uri

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            topMargin: Padding.tiny
                                            bottomMargin: Padding.tiny
                                            leftMargin: Padding.large
                                            rightMargin: Padding.large
                                        }
                                        spacing: Padding.large

                                        Rectangle {
                                            width: 45
                                            height: 45
                                            color: Colors.colSecondaryContainer
                                            radius: Rounding.small

                                            Symbol {
                                                anchors.centerIn: parent
                                                icon: "folder"
                                                iconSize: 24
                                                color: Colors.colOnSecondaryContainer
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: FileUtils.getEscapedFileName(modelData.uri)
                                                font: Fonts.request("title", "small")
                                                color: Colors.colOnLayer3
                                                truncate: true
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.extension
                                                font: Fonts.request("normal", "small")
                                                color: Colors.colSubtext
                                            }
                                        }
                                    }
                                }
                            }
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
                        Keys.onPressed: event => {
                            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                                if (root.tryPasteAttachment()) {
                                    event.accepted = true;
                                    return;
                                }
                            }
                            root.handleInputKeyPress(event);
                        }
                    }

                    RippleButtonWithIcon {
                        materialIcon: "crop_free"
                        implicitSize: 35
                        Layout.rightMargin: 4
                        buttonRadius: Rounding.large
                        colBackground: "transparent"
                        onClicked: Harness.captureWindowAnnotation()
                    }

                    Item {
                        id: sendButton
                        implicitHeight: 50
                        implicitWidth: 50
                        readonly property bool hasContent: messageInputField.text.length > 0 || Harness._pendingAnnotations.length > 0
                        readonly property bool toggled: Harness.isResponding || hasContent

                        SequentialAnimation {
                            loops: Animation.Infinite
                            running: Harness.isResponding || root.isRecording
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
                                if (!Harness.isResponding && !sendButton.hasContent)
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
                                if (!Harness.isResponding && !sendButton.hasContent)
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
                                } else if (sendButton.hasContent) {
                                    const text = messageInputField.text;
                                    messageInputField.clear();
                                    root.sendText(text);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component AttachmentShell: Item {
        id: shell
        required property string uri
        default property alias content: body.data

        anchors.top: parent?.top
        anchors.bottom: parent?.bottom

        RippleButtonWithIcon {
            z: 2
            implicitSize: 26
            layerNumber: 2
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: -Padding.small
            materialIcon: "close"
            releaseAction: () => Harness.removeAnnotation(shell.uri)
        }

        StyledRect {
            id: body
            z: 1
            color: Colors.colLayer3
            radius: Rounding.normal
            anchors.fill: parent
            clip: true
        }
    }
}
