import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.utils
import qs.common.widgets
import qs.data
import qs.services

PanelRect {
    id: root
    property bool reveal
    required property var target
    readonly property bool isPlugin: BeamData?.config?.isPlugin ?? false
    readonly property bool morphed: (target?.grow ?? 1) > 0.85
    readonly property bool shown: reveal && morphed && (hintText.length > 0)
    readonly property string hintText: BeamData.activeHint ?? ""
    readonly property var appEntry: BeamData.suggestedApp
    z: target.z - 1

    anchors.bottomMargin: 2
    anchors.bottom: target?.top
    anchors.right: target?.right
    anchors.left: target?.left

    visible: height > bottomRadius
    topRadius: target.bottomRadius
    bottomRadius: shown ? Rounding.tiny : target.bottomRadius
    height: !shown ? 0 : Math.max(100, Math.min(600, popupText.contentHeight))
    animationDuration: target?.animationDuration

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.margins: Padding.huge
        spacing: Padding.verylarge

        StyledIconImage {
            source: root.appEntry?.icon
            visible: BeamData.activeState === "launch"
            implicitSize: 64
            Layout.leftMargin: Padding.huge
        }

        StyledFlickable {
            Layout.fillHeight: true
            Layout.fillWidth: true

            contentHeight: popupText.implicitHeight
            clip: true

            StyledTextArea {
                id: popupText
                wrapMode: root.width === 1200 ? Text.Wrap : Text.NoWrap
                color: Colors.colOnLayer0
                textFormat: Text.PlainText
                text: root.hintText
                Layout.fillWidth: true
                font: Fonts.request("main", "title")
                horizontalAlignment: Text.AlignLeft

                SyntaxHighlighter {
                    textEdit: popupText
                    _definition: isPlugin ? "bash" : "plaintext"
                }
            }
        }
    }
}
