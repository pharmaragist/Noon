import QtQuick
import qs.services
import qs.common
import qs.common.widgets
import "pages"

RedunduntMultiViewPanel {
    id: root
    path: Qt.resolvedUrl("./")
    readonly property string currentPagePath: "pages/" + (Mem.beats.options.homePageStyle ?? "MaterialNoon")
    colors: BeatsService.colors
    padding: Padding.huge
    clip: false
    tabButtonList: [
        {
            
            "icon": "music_note",
            "name": "Home",
            "preload": "expanded",
            "preloadData": root.expanded,
            "component": root.currentPagePath
        },
        {
            "icon": "list",
            "name": "Local",
            "preload": "expanded",
            "preloadData": root.expanded,
            "component": "pages/LocalTracksPage"
        },
        {
            "icon": "for_you",
            "name": "Feed",
            "preload": "expanded",
            "preloadData": root.expanded,
            "component": "pages/HitsPage"
        }
    
    
    
    
    
    
    
    ]
    Rectangle {
        id:backdrop
        anchors.fill: parent
        z: -1
        opacity: 0.25
        property int randomizer: 0

        SmoothedAnimation on randomizer {
            running: true
            duration: 2000
            loops: Animation.Infinite
            from: 0
            to: 1
        }

        gradient: Gradient {
            GradientStop {
                position: backdrop.randomizer
                color: Colors.t(root.colors.colPrimary)
            }
            GradientStop {
                position: backdrop.randomizer / 2
                color: Colors.t(root.colors.colSecondary)
            }
            GradientStop {
                position: 1 - backdrop.randomizer
                color: Colors.t(root.colors.colPrimaryContainer)
            }
        }
    }
}
