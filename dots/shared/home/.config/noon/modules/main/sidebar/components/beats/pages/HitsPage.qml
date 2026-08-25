import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "../"
import "./../hits"

StyledRect {
    id: root
    color: Colors.colLayer1
    radius: Rounding.verylarge
    property bool expanded
    property bool isSearching: BeatsService.hitsQuery.length > 0
    property rect previewOrigin: Qt.rect(0, 0, 0, 0)

    onIsSearchingChanged: controls.inputArea.forceActiveFocus()

    function loadMore() {
        if (BeatsService.isLoading)
            return;
        if (isSearching)
            BeatsService.search(controls.inputArea.text, true);
        else
            BeatsService.feed(false);
    }

    ScrollEdgeFade {
        target: grid
    }
    MaterialLoadingIndicator {
        anchors.top: parent.top
        anchors.topMargin: BeatsService.isLoading ? Padding.massive: - Padding.massive * 5
        anchors.horizontalCenter: parent.horizontalCenter
        loading: BeatsService.isLoading
        z: 999

        Behavior on anchors.topMargin {
            Anim {}
        }
    }

    StyledGridView {
        id: grid
        z: 1
        anchors.margins: Padding.huge
        anchors.fill: parent
        readonly property int columns: root.expanded ? 4 : 2
        cellWidth: width / columns
        cellHeight: cellWidth
        reuseItems: false
        _model: {
            if (root.isSearching)
                return BeatsService.searchResults;
            else if (Mem.states.services.beats.shuffleHits)
                return BeatsService.hits.sort(() => Math.random() - 0.5);
            else
                return BeatsService.hits;
        }
        delegate: TrackItem {
            id: delegated
            implicitSize: grid.cellWidth - Padding.large
            title: modelData.title
            artist: modelData.artist
            coverArt: modelData.thumbnail
            isPlaylist: modelData.isPlaylist
            eventArea.onClicked: event => {
                if (event.button === Qt.RightButton) {
                    menu.popup();
                    return;
                }
                BeatsService.previewURL(modelData.url);
                delegated.animate();
            }
            StyledMenu {
                id: menu
                z: 999
                content: [
                    {
                        "text": "Download",
                        "materialIcon": "download",
                        "action": () => {
                            if (modelData && modelData.url) {
                                DlpService.request({
                                    url: modelData?.url,
                                    audio: true,
                                    quality: "best",
                                    debug: true,
                                    toast: true,
                                    directory: Mem.beats.directory
                                });
                            }
                        }
                    },
                    {
                        "text": "Play",
                        "materialIcon": "play_arrow",
                        "action": () => {
                            if (modelData && modelData.url) {
                                BeatsService.previewURL(modelData.url);
                            }
                        }
                    }
                ]
            }
        }
        onContentYChanged: {
            if (contentHeight > 0 && contentY + height >= contentHeight - height * 0.25)
                root.loadMore();
        }
    }
    StyledRectangularShadow {
        target: controls
    }

    HitsControls {
        id: controls
    }
    StyledRect {
        z: controls.z - 1
        opacity: dismissArea.enabled ? 1 : 0
        anchors.fill: parent
        color: Colors.colScrim
    }
    MouseArea {
        id: dismissArea
        z: controls.z - 1
        preventStealing: true
        hoverEnabled: true
        enabled: controls._expanded
        anchors.fill: parent
        onClicked: {
            controls.mode = "options";
            controls._expanded = false;
        }
    }
}
