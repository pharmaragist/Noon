import QtQuick
import Quickshell

import qs.common
import qs.common.widgets
import qs.services

BeamApplet {
    id: root
    _shape: "Pill"
    viewId: "music"
    colors: BeatsService.colors
    color: colors.colPrimaryContainer

    
    
    
    
    

    Symbol {
        z: 2
        anchors.centerIn: parent
        icon: "music_note"
        iconSize: 20
        color: root.colors.colOnPrimaryContainer
    }
}
