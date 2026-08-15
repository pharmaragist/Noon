import QtQuick
import Quickshell

import qs.common
import qs.common.widgets
import qs.services

BeamApplet {
    id: root
    _shape: "Cookie12Sided"
    viewId: "weather"
    rotate: true
    color: Colors.colSecondaryContainer

    Emoji {
        iconSize: 18
        anchors.centerIn: parent
        text: WeatherService?.weatherData?.current_emoji ?? ""
    }
}
