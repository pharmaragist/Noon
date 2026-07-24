import QtQuick
import qs.common
import org.kde.syntaxhighlighting

SyntaxHighlighter {
    property string _definition: "bash"
    repository: Repository
    definition: Repository.definitionForName(_definition)
    theme: Colors.m3.darkmode ? "Dracula" : "ayu Light"
}
