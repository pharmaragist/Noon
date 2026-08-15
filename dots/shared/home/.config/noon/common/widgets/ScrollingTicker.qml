
import QtQuick
import QtQuick.Controls
import qs.common
import qs.common.widgets

Item {
    id: root

    property string tickerText: "Sample Text"
    property alias tickerFont: textItem.font
    property alias tickerColor: textItem.color
    property real scrollSpeed: 15 
    property bool oppositeDirection: false 
    
    readonly property bool needsScrolling: textItem.implicitWidth > root.width

    clip: true 

    StyledText {
        

        id: textItem

        text: root.tickerText
        font: Fonts.request("main", 48, { "weight": 400 })
        color: Colors.colOnLayer0
        anchors.verticalCenter: parent.verticalCenter
        
        x: {
            if (!root.needsScrolling)
                
                return (root.width - textItem.implicitWidth) / 2;
            else
                
                return root.oppositeDirection ? -textItem.implicitWidth : root.width;
        }

        Anim on x {
            id: scrollAnimation

            from: root.oppositeDirection ? -textItem.implicitWidth : root.width
            to: root.oppositeDirection ? root.width : -textItem.implicitWidth
            duration: (textItem.implicitWidth + root.width) * root.scrollSpeed
            loops: Animation.Infinite
            running: root.visible && root.width > 0 && textItem.implicitWidth > 0 && root.needsScrolling
        }

    }

}
