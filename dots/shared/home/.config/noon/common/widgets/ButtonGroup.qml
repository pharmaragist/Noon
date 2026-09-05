import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets

Rectangle {
    id: root

    default property alias buttonsData: gridLayout.data
    property real spacing: 5
    property real padding: 0
    property bool vertical: false
    property int clickIndex: gridLayout.clickIndex
    property real contentWidth: {
        if (!vertical) {
            let total = 0;
            for (let i = 0; i < gridLayout.children.length; ++i) {
                const child = gridLayout.children[i];
                total += child.baseWidth ?? child.implicitWidth ?? child.width;
            }
            return total + root.spacing * (gridLayout.children.length - 1);
        }
        let widest = 0;
        for (let i = 0; i < gridLayout.children.length; ++i) {
            const child = gridLayout.children[i];
            widest = Math.max(widest, child.baseWidth ?? child.implicitWidth ?? child.width);
        }
        return widest;
    }
    property real contentHeight: {
        if (vertical) {
            let total = 0;
            for (let i = 0; i < gridLayout.children.length; ++i) {
                const child = gridLayout.children[i];
                total += child.baseHeight ?? child.implicitHeight ?? child.height;
            }
            return total + root.spacing * (gridLayout.children.length - 1);
        }
        let tallest = 0;
        for (let i = 0; i < gridLayout.children.length; ++i) {
            const child = gridLayout.children[i];
            tallest = Math.max(tallest, child.baseHeight ?? child.implicitHeight ?? child.height);
        }
        return tallest;
    }

    topLeftRadius: gridLayout.children.length > 0 ? (gridLayout.children[0].radius + padding) : Rounding.small
    bottomLeftRadius: topLeftRadius
    topRightRadius: gridLayout.children.length > 0 ? (gridLayout.children[gridLayout.children.length - 1].radius + padding) : Rounding.small
    bottomRightRadius: topRightRadius
    color: "transparent"
    width: root.contentWidth + padding * 2
    implicitHeight: (vertical ? root.contentHeight : gridLayout.implicitHeight) + padding * 2
    implicitWidth: root.contentWidth + padding * 2
    children: [
        GridLayout {
            id: gridLayout

            property int clickIndex: -1
            property bool vertical: root.vertical

            anchors.fill: parent
            anchors.margins: root.padding
            columns: root.vertical ? 1 : Math.max(1, children.length)
            rows: root.vertical ? Math.max(1, children.length) : 1
            columnSpacing: root.vertical ? 0 : root.spacing
            rowSpacing: root.vertical ? root.spacing : 0
        }
    ]
}
