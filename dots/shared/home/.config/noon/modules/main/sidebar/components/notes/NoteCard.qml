import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects

StyledRect {
    id: root
    required property var modelData
    signal clicked
    radius: Rounding.verylarge
    implicitHeight: Math.max(100, content.implicitHeight + Padding.massive)
    color: Colors.colLayer2
    clip: true

    gradient: Gradient {
        GradientStop {
            position: 1
            color: Colors.methods.transparentize(Colors.colPrimaryContainer, 0.75)
        }
        GradientStop {
            position: 0.6
            color: Colors.colLayer2
        }
    }
    MouseArea {
        anchors.fill: parent
        z: 1000
        hoverEnabled: true
        onClicked: if (modelData?.name)
            root.clicked()
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Padding.large
        spacing: Padding.small

        StyledText {
            leftPadding: Padding.large
            font: Fonts.request("title", "huge")
            text: modelData?.name ?? "New Note"
            color: Colors.colPrimary
            truncate: true
            Layout.fillWidth: true
        }

        StyledTextArea {
            visible: text.length.trim() > 0
            font: Fonts.request("reading", "large")
            text: modelData?.content ?? ""
            color: Colors.colOnLayer2
            Layout.fillWidth: true
            Layout.fillHeight: true
            readOnly: true
            textFormat: TextEdit.MarkdownText
        }

        StyledText {
            font: Fonts.request("main", "normal", {
                weight: 800
            })
            text: modelData?.lastSaved ?? ""
            color: Colors.colSubtext
            truncate: true
            leftPadding: Padding.large
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
