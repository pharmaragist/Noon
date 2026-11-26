import QtQuick
import QtQuick.Layouts
import QtQml.Models
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

    Timer {
        id: debounceTimer
        interval: 200
        repeat: false
        onTriggered: root.debouncedQuery = controls.inputArea.text
    }

    Connections {
        target: controls.inputArea
        function onTextChanged() {
            debounceTimer.restart();
        }
    }

    ScriptModel {
        id: filteredModel
        values: {
            const query = root.debouncedQuery.trim().toLowerCase();
            const shuffleEnabled = Boolean(Mem.states && Mem.states.services && Mem.states.services.beats && Mem.states.services.beats.shuffleTracks);
            const all = BeatsService.library || [];
            const startsMatches = [];
            const includesMatches = [];

            for (let i = 0; i < all.length; i++) {
                const t = all[i];
                if (!t || (!t.title && !t.file))
                    continue;

                if (query.length === 0) {
                    startsMatches.push(t);
                    continue;
                }

                const title = (t.title || "").toLowerCase();
                const artist = (t.artist || "").toLowerCase();

                if (title.startsWith(query) || artist.startsWith(query))
                    startsMatches.push(t);
                else if (title.includes(query) || artist.includes(query))
                    includesMatches.push(t);
            }

            if (query.length === 0 && shuffleEnabled) {
                for (let i = startsMatches.length - 1; i > 0; i--) {
                    const j = Math.floor(Math.random() * (i + 1));
                    const tmp = startsMatches[i];
                    startsMatches[i] = startsMatches[j];
                    startsMatches[j] = tmp;
                }
                return startsMatches;
            }

            return startsMatches.concat(includesMatches);
        }
    }

    StyledRectangularShadow {
        target: controls
    }

    LocalControls {
        id: controls
    }

    TrackContextMenu {
        id: sharedMenu
    }

    function playFrom(track) {
        const values = filteredModel.values || [];
        const files = values.map(t => t && t.file).filter(f => !!f);
        const at = Math.max(0, files.indexOf(track && track.file));
        BeatsService.playFiles(files.slice(at).concat(files.slice(0, at)));
    }

    radius: Rounding.verylarge
    color: "transparent"
    colors: MediaPlayerService ? MediaPlayerService.colors : undefined

    StyledGridView {
        id: grid
        clip: true
        anchors.fill: parent
        anchors.margins: Padding.large
        reuseItems: false
        cacheBuffer: 400
        model: filteredModel
        readonly property int columns: controls.listMode ? 1 : (root.expanded ? 4 : 2)
        cellWidth: width / columns
        cellHeight: controls.listMode ? 110 : cellWidth
        property string libPath: (Mem.beats && Mem.beats.directory ? Mem.beats.directory : "") + "/"

        add: null
        addDisplaced: null
        remove: null
        removeDisplaced: null

        delegate: TrackItem {
            listMode: controls.listMode
            implicitHeight: grid.cellHeight - margins
            implicitWidth: grid.cellWidth - margins
            title: modelData ? (modelData.title || "") : ""
            artist: modelData ? (modelData.artist || "") : ""
            coverArt: (modelData && modelData.cover) ? (grid.libPath + modelData.cover) : ""

            eventArea.onClicked: event => {
                if (!modelData)
                    return;
                if (event.button === Qt.LeftButton) {
                    root.playFrom(modelData);
                } else if (event.button === Qt.RightButton) {
                    sharedMenu.trackPath = modelData.file ? (grid.libPath + modelData.file) : "";
                    sharedMenu.trackName = modelData.title || "";
                    sharedMenu.popup();
                }
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
