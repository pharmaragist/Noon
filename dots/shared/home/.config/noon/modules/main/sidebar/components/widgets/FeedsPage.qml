import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.functions
import qs.common.widgets
import qs.services

SidebarItemContainer {
    id: root
    property int selectedTabIndex: 0
    readonly property var tabButtonList: RssService.targets.map(target => ({
                name: target.label ?? "",
                icon: "",
                model: target.feed ?? []
            }))

    color: Colors.colLayer1

    GroupButtonWithIcon {
        z: 999
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: Padding.huge
        toggled: enabled
        enabled: !RssService.isLoading
        implicitSize: 60
        materialIcon: "refresh"
        releaseAction: () => RssService.loadRss()
    }
    PagePlaceholder {
        anchors.centerIn: parent
        shown: RssService.targets.length === 0
        icon: "rss_feed"
        title: "No Feeds Yet"
        description: "Add feed URLs to the RSS service and refresh"
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.large
        spacing: Padding.gigantic
        visible: RssService.targets.length > 0
        StyledSwipeView {
            id: swipeView
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.selectedTabIndex
            onCurrentIndexChanged: root.selectedTabIndex = currentIndex
            Repeater {
                model: root.tabButtonList
                delegate: FeedPageComponent {}
            }
        }
        PrimaryTabBar {
            tabButtonList: root.tabButtonList
            currentIndex: root.selectedTabIndex
            externalTrackedTab: root.selectedTabIndex
            onCurrentIndexChanged: root.selectedTabIndex = currentIndex
        }
    }
    component FeedPageComponent: Item {
        required property var modelData

        StyledListView {
            id: listRoot
            anchors.fill: parent
            hinter.color: Colors.colLayer1
            clip: true
            spacing: Padding.large
            _model: modelData.model
            delegate: FeedsItem {
                id: delegateRoot
                required property var modelData
                width: listRoot.width
                post: modelData
            }
        }
    }
}
