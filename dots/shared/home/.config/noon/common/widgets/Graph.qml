import QtQuick
import QtGraphs
import qs.common





GraphsView {
    id: root

    property color color: Colors.colPrimary
    property real fillOpacity: 0.5
    property alias series: line

    antialiasing: true
    marginTop: 0
    marginBottom: 0
    marginLeft: 0
    marginRight: 0
    panStyle: GraphsView.PanStyle.None
    zoomStyle: GraphsView.ZoomStyle.None

    theme: GraphsTheme {
        backgroundVisible: false
        plotAreaBackgroundVisible: false
        gridVisible: true
        labelsVisible: true
    }

    axisX: ValueAxis {
        min: 0
        max: Math.max(1, line.count - 1)
        visible: false
        lineVisible: false
        labelsVisible: false
        gridVisible: false
        subGridVisible: false
    }

    axisY: ValueAxis {
        min: 0
        max: 1
        visible: false
        lineVisible: false
        labelsVisible: false
        gridVisible: false
        subGridVisible: false
    }


    AreaSeries {
        borderWidth: 0
        upperSeries: line
        color: Colors.methods.transparentize(root.color, 1 - root.fillOpacity)
    }

    LineSeries {
        id: line
        color: root.color
        width: 2
    }
}
