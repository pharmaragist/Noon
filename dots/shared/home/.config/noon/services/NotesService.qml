pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.utils
import qs.common.functions
import Qt.labs.folderlistmodel

Singleton {
    id: root

    readonly property string folderPath: Directories.standard.documents + "/Notes/"
    property string fileName: Mem.states.services.notes?.currentFile ?? "noon_notes.md"
    property string filePath: folderPath + fileName
    property string content: ""
    property bool isDirty: false
    property string lastSaved: ""
    property bool isLoaded: false
    property string _pendingNote: ""
    readonly property var cards: {
        const _model = notesModel;
        let all = [];
        for (var i = 0; i < _model.count; i++) {
            all.push({
                name: _model.get(i, "fileName"),
                path: _model.get(i, "filePath"),
                lastSaved: friendlyDate(_model.get(i, "fileModified")),
                content: FileUtils.readFile(_model.get(i, "filePath"))
            });
        }
        return all;
    }

    FileView {
        id: noteFile
        path: root.filePath

        onLoaded: {
            root.content = noteFile.text();
            root.isDirty = false;
            root.isLoaded = true;
            if (root._pendingNote)
                root.note(root._pendingNote);
        }

        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                root.content = "";
                root.isLoaded = true;
                save();
            }
        }

        onSaved: {
            root.isDirty = false;
            root.lastSaved = new Date().toISOString();
        }
    }

    FolderListModel {
        id: notesModel
        nameFilters: ["*.md"]
        folder: root.folderPath
        showDirs: false
        showFiles: true
    }

    function createNote(name) {
        if (!name?.trim())
            return;
        const _name = name + ".md";
        FileUtils.createFileWith(folderPath + "/" + _name, "");
        NoonUtils.inlineTimer(() => openNote(_name), 500);
    }

    function openNote(name) {
        if (name)
            Mem.states.services.notes.currentFile = name.trim();
    }

    function save() {
        noteFile.setText(root.content);
    }

    function note(text) {
        if (!text?.trim())
            return;
        if (!root.isLoaded) {
            root._pendingNote = text;
            noteFile.reload();
            return;
        }
        root.content += text.trim() + "\n";
        root.isDirty = true;
        save();
    }

    function friendlyDate(timestamp) {
        if (!timestamp)
            return "";
        return Qt.formatDateTime(new Date(timestamp), "MMM d, ''yy • h:mm AP");
    }

    Component.onCompleted: noteFile.reload()
}
