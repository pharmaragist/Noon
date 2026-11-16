import QtQuick

// Syntax highlighting used to be provided by the KDE syntax-highlighting
// framework. The type is kept as a no-op so call sites remain unchanged and
// the shell no longer depends on KF6.
QtObject {
    property var textEdit
    property string _definition: "bash"
}
