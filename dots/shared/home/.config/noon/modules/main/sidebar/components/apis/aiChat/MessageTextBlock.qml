import qs.services
import qs.common
import qs.common.widgets
import qs.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

ColumnLayout {
    id: root

    property bool editing: false
    property bool renderMarkdown: false
    property bool enableMouseSelection: false
    property string segmentContent: ""
    property var messageData: {}
    property bool done: true
    property bool thinking: false
    property bool forceDisableChunkSplitting: false
    property font font: Fonts.request("reading", Fonts.sizes.verylarge * Mem.states.sidebar.apis.fontScale)
    property string shownText: ""
    property bool fadeChunkSplitting: !forceDisableChunkSplitting && !editing && !/\n\|/.test(shownText)

    property var _formulaMap: ({})

    Layout.fillWidth: true
    spacing: 0

    function processText(input) {
        if (!input)
            return "";

        const parts = input.split(/(\$\$[\s\S]*?\$\$)/g);
        let result = "";
        for (let i = 0; i < parts.length; i++) {
            const p = parts[i];
            if (p.startsWith("$$") && p.endsWith("$$")) {
                const formula = p.slice(2, -2).trim();
                if (formula) {
                    const [hash, ready] = LatexService.requestRender(formula);
                    const imagePath = `${LatexService.latexOutputPath}/${hash}.png`;
                    if (_formulaMap[hash] !== undefined) {
                        result += `![formula](${_formulaMap[hash]})`;
                    } else {
                        _formulaMap[hash] = imagePath;
                        if (ready)
                            result += `![formula](${imagePath})`;
                    }
                }
            } else {
                result += p;
            }
        }
        return result;
    }

    function computeChunks() {
        if (!root.shownText)
            return [];
        return root.fadeChunkSplitting ? root.shownText.split(/\n\n(?= {0,2})|\n(?= {0,2}[-\*])/g).filter(line => line.trim() !== "") : [root.shownText];
    }

    onEditingChanged: {
        shownText = processText(segmentContent);
    }

    onSegmentContentChanged: {
        if (segmentContent) {
            _formulaMap = ({});
            shownText = processText(segmentContent);
        }
    }

    onShownTextChanged: {
        chunksModel.values = computeChunks();
    }

    onFadeChunkSplittingChanged: {
        chunksModel.values = computeChunks();
    }

    Timer {
        id: _refreshTimer
        interval: 50
        onTriggered: root.shownText = root.processText(root.segmentContent)
    }

    Connections {
        target: LatexService
        function onRenderFinished(hash) {
            if (root._formulaMap[hash] !== undefined)
                _refreshTimer.start();
        }
    }

    Repeater {
        id: textLinesRepeater

        model: ScriptModel {
            id: chunksModel
            values: []
        }

        delegate: TextArea {
            id: textArea

            required property int index
            required property string modelData

            Layout.fillWidth: true
            readOnly: !editing
            selectByMouse: enableMouseSelection || editing
            renderType: Text.NativeRendering
            font: root.font
            selectedTextColor: Colors.m3.m3onSecondaryContainer
            selectionColor: Colors.colSecondaryContainer
            wrapMode: TextEdit.Wrap
            color: root.thinking ? Colors.colSubtext : Colors.colOnLayer1
            textFormat: renderMarkdown ? TextEdit.MarkdownText : TextEdit.PlainText
            text: modelData

            onTextChanged: {
                if (root.editing)
                    segmentContent = text;
            }

            onLinkActivated: link => {
                Qt.openUrlExternally(link);
                Ipc.call(["sidebar", "hide"]);
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : (enableMouseSelection || editing) ? Qt.IBeamCursor : Qt.ArrowCursor
            }
        }
    }
}
