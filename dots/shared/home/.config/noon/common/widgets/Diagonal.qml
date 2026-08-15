import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.common
import qs.common.widgets

Canvas {
    property int containerWidth: 200
    property int containerHeight: 100
    property color bgColor: "white"
    property bool flip: false
    property bool hide: false

    height: containerHeight
    width: containerWidth
    
    onBgColorChanged: requestPaint()
    onHideChanged: requestPaint()
    onFlipChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d");
        
        ctx.clearRect(0, 0, width, height);
        
        ctx.fillStyle = hide ? "transparent" : bgColor;
        ctx.beginPath();
        if (flip) {
            
            ctx.moveTo(0, 0);
            ctx.lineTo(width - 30, 0);
            ctx.lineTo(width, height);
            ctx.lineTo(30, height);
        } else {
            
            ctx.moveTo(30, 0);
            ctx.lineTo(width, 0);
            ctx.lineTo(width - 30, height);
            ctx.lineTo(0, height);
        }
        ctx.closePath();
        ctx.fill();
    }
}
