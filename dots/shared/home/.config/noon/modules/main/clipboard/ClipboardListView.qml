import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services
import qs.common.widgets
import qs.common.utils

Item {
    function focusView() {
        list.currentIndex = 0;
        list.forceActiveFocus();
    }

    function navigateUp() {
        if (list.currentIndex > 0)
            list.currentIndex--;
    }

    function navigateDown() {
        if (list.currentIndex < list.count - 1)
            list.currentIndex++;
    }

    function navigateLeft() {
    }
    function navigateRight() {
    }

    function dispatchCurrent() {
        if (list.currentIndex >= 0 && list.currentIndex < list.count)
            root.dispatch(list.model.values[list.currentIndex].text);
    }

    StyledListView {
        id: list
        spacing: 2
        hint: false
        anchors.fill: parent
        keyNavigationEnabled: false
        _model: {
            const entries = ClipboardService.entries;
            if (!entries.length)
                return [];

            const query = searchInput.text.trim().toLowerCase();
            if (!query)
                return entries;

            return entries.filter(item => item.text.toLowerCase().includes(query));
        }
        clip: true
        radius: Rounding.huge
        currentIndex: -1
        delegate: StyledRect {
            id: delegate
            required property var modelData
            required property int index
            readonly property bool isHovered: hoverArea.containsMouse
            readonly property bool isSelected: list.currentIndex === index && list.activeFocus
            readonly property bool isColor: Colors.methods.isValidColor(modelData?.text)
            readonly property bool isImage: false

            color: isSelected ? Colors.colPrimaryContainer : (isColor ? modelData.text.trim() : Colors.colLayer2)
            anchors.left: parent?.left
            anchors.right: parent?.right
            implicitHeight: modelData.isImage ? 160 : Math.max(52, displayText.contentHeight + Padding.huge)
            topRadius: index === 0 ? Rounding.huge : 2
            bottomRadius: index === list?.count - 1 ? Rounding.huge : 2

            StyledLoader {
                shown: delegate.modelData?.isImage ?? false
                anchors.fill: parent
                sourceComponent: StyledImage {
                    id: image
                    anchors.fill: parent
                    source: "file://" + delegate.modelData?.imagePath
                    fillMode: Image.PreserveAspectFit
                    cache: false
                }
            }

            StyledText {
                id: displayText
                visible: !modelData.isImage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Padding.huge
                anchors.verticalCenter: parent.verticalCenter
                text: modelData?.text ?? ""
                font: Fonts.request("reading", "large")
                color: isColor ? Colors.methods.getReadableColOn(delegate.color, 0.45) : Colors.colOnLayer2
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: if (!!modelData.text.trim()) {
                    list.currentIndex = index;
                    ClipboardService.copy(modelData.text)
                    root.dispatch(modelData.text);
                }
            }
        }
    }
}
