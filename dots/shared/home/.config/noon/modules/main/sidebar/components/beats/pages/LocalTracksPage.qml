import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.functions
import qs.services
import "../local"
import "../"

StyledRect {
    id: root

    signal dismiss
    signal searchFocusRequested
    signal contentFocusRequested
    signal expandRequested

    property bool expanded
    property string debouncedQuery

    Connections {
        target: controls.inputArea
        function onTextChanged() {
            NoonUtils.inlineTimer(() => {
                root.debouncedQuery = controls.inputArea.text;
            }, 200);
        }
    }

    function shuffle(list) {
        const arr = list.slice();
        for (let i = arr.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const tmp = arr[i];
            arr[i] = arr[j];
            arr[j] = tmp;
        }
        return arr;
    }

    ScriptModel {
        id: filteredModel
        values: {
            const query = (root.debouncedQuery ?? "").trim().toLowerCase();
            const shuffleEnabled = Mem.states?.services?.beats?.shuffleTracks ?? false;
            const all = BeatsService.library || [];
            const startsMatches = [];
            const includesMatches = [];

            for (let i = 0; i < all.length; i++) {
                const t = all[i];
                if (!t || typeof t !== "object" || !(t.title || t.file))
                    continue;

                if (query.length === 0) {
                    startsMatches.push(t);
                    continue;
                }

                const title = (t.title ?? "").toLowerCase();
                const artist = (t.artist ?? "").toLowerCase();

                if (title.startsWith(query) || artist.startsWith(query))
                    startsMatches.push(t);
                else if (title.includes(query) || artist.includes(query))
                    includesMatches.push(t);
            }

            if (query.length === 0 && shuffleEnabled)
                return root.shuffle(startsMatches);

            return startsMatches.concat(includesMatches);
        }
    }

    StyledRectangularShadow {
        target: controls
    }

    LocalControls {
        id: controls
    }

    function createPlaylistFromModel() {
        var playlist = [];
        var values = filteredModel.values || [];
        for (var i = 0; i < values.length; i++) {
            var item = values[i];
            if (item && item.title)
                playlist.push(item.title);
        }
        return playlist.join(",");
    }

    function playResults() {
        if (controls.inputArea.text.length > 0) {
            BeatsService.playCustomPlaylist(createPlaylistFromModel());
        }
    }

    function createPlaylist(fileName) {
        if (fileName) {
            BeatsService.playTrackByFile(fileName);
        }
    }

    radius: Rounding.verylarge
    color: "transparent"
    colors: MediaPlayerService?.colors

    StyledGridView {
        id: grid
        clip: true
        anchors.fill: parent
        anchors.margins: Padding.large
        reuseItems: false
        model: filteredModel
        readonly property int columns: controls.listMode ? 1 : root.expanded ? 4 : 2
        cellWidth: width / columns
        cellHeight: controls.listMode ? 110 : cellWidth
        property string libPath: (Mem.beats?.directory ?? "") + "/"

        delegate: TrackItem {
            listMode: controls?.listMode ?? false
            implicitHeight: grid.cellHeight - margins
            implicitWidth: grid.cellWidth - margins
            title: modelData?.title ?? ""
            artist: modelData?.artist ?? ""
            coverArt: modelData?.cover ? (grid.libPath + modelData.cover) : ""

            eventArea.onClicked: event => {
                if (!modelData)
                    return;
                if (event.button === Qt.LeftButton) {
                    root.createPlaylist(modelData?.file);
                } else if (event.button === Qt.MiddleButton) {
                    root.playResults();
                } else if (event.button === Qt.RightButton) {
                    menu.popup();
                }
            }

            TrackContextMenu {
                id: menu
                trackPath: modelData?.file ? (grid.libPath + modelData.file) : ""
                trackName: modelData?.title ?? ""
            }
        }
    }

    MouseArea {
        id: dismissArea
        z: controls.z - 1
        preventStealing: true
        hoverEnabled: true
        enabled: controls._expanded
        anchors.fill: parent
        onClicked: controls.mode = ""
    }
}
