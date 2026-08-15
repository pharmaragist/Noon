import QtQuick
import qs.common

StyledRect {
    clip: true
    radius: Rounding.verylarge
    color: "transparent"
    property bool detached: false
    property bool expanded: false
    property var colors: Colors
    property string searchQuery: ""
    property string debouncedQuery: ""
    property StyledPanel panelWindow: null
    property int selectedTabIndex: 0
    signal dismiss
    signal searchFocusRequested
    signal contentFocusRequested
    signal expandRequested
}
