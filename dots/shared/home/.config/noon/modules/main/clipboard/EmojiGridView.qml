import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services
import qs.common.widgets
import qs.common.utils

StyledRect {
    color: Colors.colLayer2
    radius: Rounding.huge

    function focusView() {
        gridView.currentIndex = 0;
        gridView.forceActiveFocus();
    }

    function navigateUp() {
        if (gridView.currentIndex >= gridView.columns)
            gridView.currentIndex -= gridView.columns;
    }

    function navigateDown() {
        if (gridView.currentIndex < 0)
            gridView.currentIndex = 0;
        else if (gridView.currentIndex + gridView.columns < gridView.count)
            gridView.currentIndex += gridView.columns;
    }

    function navigateLeft() {
        if (gridView.currentIndex > 0)
            gridView.currentIndex--;
    }

    function navigateRight() {
        if (gridView.currentIndex < gridView.count - 1)
            gridView.currentIndex++;
    }

    function dispatchCurrent() {
        if (gridView.currentIndex >= 0 && gridView.currentIndex < gridView.count) {
            const data = gridView.model.values[gridView.currentIndex];
            root.dispatch(data.emoji);
            EmojisService.recordEmojiUse(data.emoji);
        }
    }

    StyledGridView {
        id: gridView
        anchors.fill: parent
        columns: 5
        clip: true
        keyNavigationEnabled: false
        currentIndex: -1
        _model: {
            const all = EmojisService.list;
            const q = searchInput.text.toLowerCase().trim();

            if (q === "") {
                const frequent = EmojisService.frequentEmojis;
                if (frequent.length > 0) {
                    const freqObjs = frequent.map(fChar => all.find(e => e.emoji === fChar)).filter(Boolean);
                    const others = all.filter(e => !frequent.includes(e.emoji));
                    return [...freqObjs, ...others].slice(0, 150);
                }
                return all.slice(0, 150);
            }

            return all.filter(e => e.name.toLowerCase().includes(q) || e.category.toLowerCase().includes(q) || e.subcategory.toLowerCase().includes(q) || e.emoji.includes(q)).slice(0, 100);
        }

        delegate: StyledRect {
            id: emojiButton
            required property int index
            required property var modelData

            implicitHeight: gridView.cellHeight
            implicitWidth: gridView.cellWidth
            property bool isSelected: gridView.currentIndex === index && gridView.activeFocus

            color: isSelected ? Colors.colPrimaryContainer : (eventArea.containsMouse ? Colors.colPrimaryContainerHover : "transparent")

            MouseArea {
                id: eventArea
                hoverEnabled: true
                anchors.fill: parent
                onReleased: if (!!modelData.emoji.trim()) {
                    root.dispatch(modelData.emoji)
                    EmojisService.recordEmojiUse(modelData.emoji);
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: modelData.emoji
                font.pixelSize: Math.round(emojiButton.implicitHeight / 1.5)
            }

            SequentialAnimation {
                running: isSelected || eventArea.containsMouse
                StyledPropertyAnimation {
                    target:emojiButton
                    property: "radius"
                    from: 0
                    to: Rounding.massive
                }
            }
        }
    }
}
