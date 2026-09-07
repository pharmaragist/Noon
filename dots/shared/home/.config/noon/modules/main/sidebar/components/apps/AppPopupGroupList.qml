import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

BottomDialog {
    id: popup
    property var appsData: []
    property string categoryTitle: ""
    z: 9999
    color: Colors.colLayer2
    clip: true
    baseHeight: parent?.height / 2.25
    onFocusChanged: focus ? appsList.forceActiveFocus() : null
    onShowChanged: !active ? parent?.gridView?.forceActiveFocus() : null

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.huge

        PageHeader {
            title: popup.categoryTitle
        }

        StyledListView {
            id: appsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            focus: true
            model: popup.appsData
            spacing: Padding.small
            hint: true
            hinter.color: Colors.colLayer2

            clip: true
            radius: Rounding.large
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 300
            animateAppearance: true
            animateMovement: true
            highlight: Item {
                z: 2
                width: appsList.width
                height: 60

                StyledRect {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: 40
                    radius: 6
                    width: 6
                    color: Colors.colSecondaryContainer
                }
            }

            delegate: StyledDelegateItem {
                id: delegateListItem
                required property var modelData
                required property int index
                iconSource: NoonUtils.iconPath(modelData?.icon) ?? ""
                title: modelData?.name ?? ""
                subtext: modelData?.description ?? ""
                height: 72
                mainScale: 1.15
                colBackground: index % 2 !== 0 ? "transparent" : Colors.colLayer3
                releaseAction: () => {
                    popup.show = false;
                    root.dismiss();
                    modelData.execute();
                }
                altAction: () => contextMenu.popup()
                AppContextMenu {
                    id: contextMenu
                    modelData: delegateListItem.modelData
                    onDismiss: root.dismiss()
                }
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Up) {
                    currentIndex = Math.max(0, currentIndex - 1);
                } else if (event.key === Qt.Key_Down) {
                    currentIndex = Math.min(count - 1, currentIndex + 1);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (currentItem)
                        currentItem.releaseAction();
                } else if (event.key === Qt.Key_Escape) {
                    popup.show = false;
                } else {
                    return;
                }
                event.accepted = true;
            }
        }
    }
}
