import QtQuick.Controls.Material
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

ComboBox {
    id: root
    implicitHeight: 45
    implicitWidth: 110
    Material.theme: Material[Colors.mode]
    property var _model: []
    property bool showDisplayIcon: true

    readonly property var currentInfo: {
        if (!Array.isArray(_model) || _model.length === 0) return null;
        if (typeof _model[0] === "object")
            return _model.find(i => i.name === displayText);
        else
            return _model.find(i => i === displayText);
    }
    function processText(text) {
        return Fonts.methods.separateCamelCase(text);
    }
    model: _model

    delegate: ItemDelegate {
        id: delegated
        width: ListView.view.width
        height: 45
        highlighted: root.highlightedIndex === index
        readonly property bool isSelected: index === root.currentIndex
        contentItem: RowLayout {
            anchors.centerIn: parent
            spacing: Padding.normal

            Symbol {
                text: isSelected ? "check" : modelData?.icon ?? ""
                font.pixelSize: 24
                color: delegated.highlighted ? Colors.m3.m3onPrimary : Colors.colOnSurface
                fill: delegated.highlighted ? 1 : 0
            }

            StyledText {
                Layout.fillWidth: true
                property string candidate: modelData?.name ?? modelData ?? ""
                text: root.processText(candidate)
                font: Fonts.request("main", 14)
                truncate: true
                color: delegated.highlighted ? Colors.m3.m3onPrimary : Colors.colOnSurface
            }
        }

        background: Rectangle {
            color: parent.highlighted ? Colors.m3.m3primary : "transparent"
            radius: Rounding.large
        }
    }

    contentItem: RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Padding.huge

        Symbol {
            visible: !!currentInfo?.icon && root.showDisplayIcon
            icon: currentInfo?.icon || ""
            iconSize: 16
        }

        StyledText {
            Layout.fillWidth: true
            font: Fonts.request("main", 14)
            text: root.processText(root.displayText)
            color: Colors.colOnLayer2
            truncate: true
        }
    }

    background: Rectangle {
        color: Colors.colLayer4
        radius: height / 2
    }

    MouseArea {
        anchors.fill: parent
        onClicked: popup.visible ? popup.close() : popup.open()
    }

    popup: Popup {
        id: popup
        padding: Padding.normal
        implicitWidth: Math.max(root.width + padding * 6, 180)
        implicitHeight: Math.min(contentItem.implicitHeight + padding, 300)
        height: 0
        opacity: 0
        scale: 0.95
        x: (root.width - width) / 2
        y: -padding
        closePolicy: Popup.NoAutoClose

        onAboutToShow: {
            height = 0;
            opacity = 0;
            scale = 0.95;
            openAnim.restart();
        }

        onAboutToHide: {
            closeAnim.restart();
        }

        background: StyledRect {
            color: Colors.colLayer4
            radius: Rounding.verylarge
        }

        contentItem: StyledListView {
            clip: true
            hint: false
            radius: Rounding.large
            implicitHeight: contentHeight
            currentIndex: root.highlightedIndex
            spacing: Padding.tiny
            model: root.popup.visible ? root.delegateModel : []
        }

        ParallelAnimation {
            id: openAnim
            PropertyAnimation {
                target: popup
                property: "height"
                to: popup.implicitHeight
                duration: 220
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                target: popup
                property: "opacity"
                to: 1
                duration: 160
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                target: popup
                property: "scale"
                to: 1
                duration: 220
                easing.type: Easing.OutBack
            }
        }

        ParallelAnimation {
            id: closeAnim
            PropertyAnimation {
                target: popup
                property: "opacity"
                to: 0
                duration: 140
                easing.type: Easing.InCubic
            }
            PropertyAnimation {
                target: popup
                property: "scale"
                to: 0.96
                duration: 140
                easing.type: Easing.InCubic
            }
            PropertyAnimation {
                target: popup
                property: "y"
                to: popup.y + 6
                duration: 140
                easing.type: Easing.InCubic
            }
            onStopped: {
                popup.visible = false;
            }
        }
    }
}
