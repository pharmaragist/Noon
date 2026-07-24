import QtQuick.Layouts
import QtQuick
import QtQuick.Controls
import Quickshell

import qs.store
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.services

ShaderRect {
    id: root
    property bool reveal
    required property var mainBg
    readonly property bool isPlugin: BeamData?.config?.isPlugin ?? false
    readonly property bool shown: reveal && (hintText.length > 0)
    readonly property string hintText: BeamData.getHint() ?? ""
    readonly property var appData: hintText.length > 0 ? DesktopEntries.byId(hintText) : null

    z: -1
    visible: height > 10
    opacity: shown ? 1 : 0

    anchors.bottom: mainBg.top
    anchors.bottomMargin: 3
    anchors.horizontalCenter: parent.horizontalCenter

    implicitWidth: mainBg?.implicitWidth
    implicitHeight: !shown ? 0 : Math.max(136, Math.min(Sizes.beamPopupExpanded.height, popupText.contentHeight + Padding.massive))

    topRadius: mainBg.bottomRadius
    bottomRadius: shown ? Rounding.tiny : mainBg.bottomRadius

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.margins: Padding.massive
        spacing: Padding.massive

        StyledLoader {
            visible: active
            active: BeamData.activeState === "launch"
            sourceComponent: BeamIconPopupItem {}
            onLoaded: if ("content" in _item)
                _item.content = BeamData.config?.data || {}
        }

        StyledFlickable {
            Layout.fillHeight: true
            Layout.fillWidth: true

            contentHeight: hintContent.implicitHeight
            clip: true

            ColumnLayout {
                id: hintContent
                anchors.fill: parent
                spacing: 0

                StyledTextArea {
                    id: popupText
                    wrapMode: root.width === Sizes.beamPopupExpanded.width ? Text.Wrap : Text.NoWrap
                    textFormat: Text.PlainText
                    text: root.hintText
                    Layout.fillWidth: true
                    font: Fonts.request("mono", "subTitle")
                    horizontalAlignment: Text.AlignLeft

                    SyntaxHighlighter {
                        textEdit: popupText
                        _definition: isPlugin ? "bash" : "plaintext"
                    }
                }

                StyledText {
                    id: popupDescriptionText
                    visible: !!text
                    leftPadding: Padding.large
                    horizontalAlignment: Text.AlignLeft
                    Layout.fillWidth: true
                    truncate: true
                    text: root.appData?.comment || BeamData.activeState
                    color: Colors.colSubtext
                    font: Fonts.request("mono", "huge")
                }
            }
        }
    }

    Behavior on bottomRadius {
        Anim {
            duration: Animations.durations.verylarge
        }
    }
}
