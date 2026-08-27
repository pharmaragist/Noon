import QtQuick
import Quickshell
import qs.common.utils





Item {
    id: root


    readonly property var filterPresets: {
        "ALL": {
            "name": "All files",
            "patterns": NameFilters.all
        },
        "IMAGES": {
            "name": "Image files",
            "patterns": NameFilters.picture
        },
        "VIDEOS": {
            "name": "Video files",
            "patterns": NameFilters.video
        },
        "AUDIO": {
            "name": "Audio files",
            "patterns": NameFilters.audio
        },
        "ARCHIVES": {
            "name": "Archive files",
            "patterns": NameFilters.archive
        },
        "CODE": {
            "name": "Code files",
            "patterns": ["*.js", "*.py", "*.java", "*.cpp", "*.c", "*.h", "*.hpp", "*.cs", "*.go", "*.rs", "*.rb", "*.php", "*.html", "*.css", "*.qml"]
        },
        "DOCUMENTS": {
            "name": "Text files",
            "patterns": NameFilters.document
        }
    }

    property string title: "Select File"
    property bool multipleSelection: false
    property bool directoryMode: false
    property bool saveMode: false
    property string currentFolder: "~"
    property string filter: ""
    property var fileFilters: filterPresets[filter]
    property string separator: "\n"


    signal fileSelected(var files)
    signal cancelled
    signal error(string message)


    function open() {
        if (pickerLoader.item && pickerLoader.item.running) {
            console.warn("[FilePicker] Picker already running");
            return;
        }
        if (!pickerLoader.active)
            pickerLoader.active = true;

        Qt.callLater(() => {
            if (pickerLoader.item)
                pickerLoader.item.running = true;
        });
    }


    function buildKDialogFilter() {
        if (fileFilters.length === 0)
            return "";


        const filterStrings = fileFilters.map(filter => {
            if (filter.name && filter.patterns) {
                const patterns = Array.isArray(filter.patterns) ? filter.patterns.join(" ") : filter.patterns;
                return `${filter.name} (${patterns})`;
            }
            return "";
        }).filter(f => {
            return f !== "";
        });
        return filterStrings.join("|");
    }


    LazyLoader {
        id: pickerLoader

        active: false
        component: pickerComponent

        Component {
            id: pickerComponent

            Process {
                id: picker

                property string output: ""
                property string errorOutput: ""

                command: {
                    let args = ["kdialog"];

                    if (root.title)
                        args.push("--title", root.title);


                    if (root.directoryMode) {
                        args.push("--getexistingdirectory");
                        args.push(root.currentFolder);
                    } else if (root.saveMode) {
                        args.push("--getsavefilename");
                        args.push(root.currentFolder);
                        const filter = root.buildKDialogFilter();
                        if (filter)
                            args.push(filter);
                    } else {

                        args.push("--getopenfilename");
                        args.push(root.currentFolder);
                        const filter = root.buildKDialogFilter();
                        if (filter)
                            args.push(filter);


                        if (root.multipleSelection) {
                            args.push("--multiple");
                            args.push("--separate-output");
                        }
                    }
                    return args;
                }
                running: false
                onExited: (exitCode, exitStatus) => {
                    if (exitCode === 0) {
                        const trimmed = output.trim();
                        if (trimmed) {
                            if (root.multipleSelection) {
                                const files = trimmed.split("\n").filter(f => {
                                    return f.trim() !== "";
                                });
                                root.fileSelected(files);
                            } else {
                                root.fileSelected(trimmed);
                            }
                        } else {
                            root.cancelled();
                        }
                    } else if (exitCode === 1) {

                        root.cancelled();
                    } else {

                        root.error(errorOutput.trim() || "File picker failed");
                    }

                    output = "";
                    errorOutput = "";
                }

                stdout: SplitParser {
                    onRead: line => {
                        picker.output += line + "\n";
                    }
                }

                stderr: SplitParser {
                    onRead: line => {
                        picker.errorOutput += line + "\n";
                        console.error(`[FilePicker] ${line}`);
                    }
                }
            }
        }
    }
}
