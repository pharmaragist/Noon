import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets

WidgetContainer {
    id: root

    readonly property int maxPoints: 24

    property real dlLast: 0
    property real ulLast: 0
    property var dlHistory: []
    property var ulHistory: []

    readonly property var manager: NetworkService.manager

    function parseSpeed(text) {
        if (!text)
            return 0;
        const m = text.trim().match(/^([\d.]+)\s*(B|KB|MB|GB)\/s$/i);
        if (!m)
            return 0;
        const v = parseFloat(m[1]);
        const mult = {
            "B": 1,
            "KB": 1024,
            "MB": 1024 * 1024,
            "GB": 1024 * 1024 * 1024
        };
        return v * (mult[m[2].toUpperCase()] ?? 1);
    }

    function updateSpeed() {
        const dl = root.parseSpeed(manager.downloadSpeedText);
        const ul = root.parseSpeed(manager.uploadSpeedText);
        let peak = 1;
        for (const v of root.dlHistory)
            peak = Math.max(peak, v);
        for (const v of root.ulHistory)
            peak = Math.max(peak, v);
        peak = Math.max(peak, dl, ul, 1);

        const arrDl = root.dlHistory.concat([dl / peak]);
        const arrUl = root.ulHistory.concat([ul / peak]);
        root.dlHistory = arrDl.slice(-root.maxPoints);
        root.ulHistory = arrUl.slice(-root.maxPoints);
        root.dlLast = dl / peak;
        root.ulLast = ul / peak;
    }

    Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: root.updateSpeed()
    }

    Component.onCompleted: root.updateSpeed()

    small: ColumnLayout {
        anchors.centerIn: parent
        spacing: Padding.normal

        StyledRect {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            implicitSize: 40
            radius: Rounding.full
            color: Colors.colPrimary

            Symbol {
                anchors.centerIn: parent
                text: "arrow_cool_down"
                color: Colors.colOnPrimary
                fill: 1
                iconSize: Fonts.sizes.large
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: manager.downloadSpeedText
            color: Colors.colOnLayer0
            font: Fonts.request("numbers", "normal")
            horizontalAlignment: Text.AlignHCenter
            truncate: true
        }
    }

    normal: RowLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true

            spacing: Padding.large

            StyledText {
                Layout.fillWidth: true
                text: manager.networkName || "No connection"
                color: Colors.colOnLayer0
                font: Fonts.request("main", "small")
                horizontalAlignment: Text.AlignHCenter
                truncate: true
            }

            SpeedRow {
                Layout.fillWidth: true
                text: "arrow_cool_down"
                label: "Download"
                value: manager.downloadSpeedText
                accent: true
            }
            SpeedRow {
                Layout.fillWidth: true
                text: "arrow_warm_up"
                label: "Upload"
                value: manager.uploadSpeedText
            }
        }

        GGraph {
            implicitWidth: 80
            visible: root.isLarge
            history: root.dlHistory
        }
    }
    large: normal

    xlarge: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.veryhuge
        spacing: Padding.massive

        RowLayout {
            Layout.fillWidth: true
            spacing: Padding.large

            Symbol {
                leftPadding: Padding.large
                text: manager.materialSymbol
                color: Colors.colPrimary
                fill: 1
                iconSize: 18
            }

            StyledText {
                Layout.fillWidth: true
                text: (manager.networkName + "@" + manager.ipAddress) || "No connection"
                color: Colors.colOnLayer0
                font: Fonts.request("title", "normal")
                truncate: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Padding.normal

            SpeedRow {
                Layout.fillWidth: true
                text: "arrow_cool_down"
                label: "Download"
                value: manager.downloadSpeedText
                accent: true
            }
            SpeedRow {
                Layout.fillWidth: true
                text: "arrow_warm_up"
                label: "Upload"
                value: manager.uploadSpeedText
            }
        }

        GGraph {
            history: root.dlHistory
        }
    }

    component GGraph: StyledRect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        color: Colors.colLayer3
        radius: Rounding.verylarge
        property var history: root.dlHistory

        Graph {
            id: graph
            anchors.margins: Padding.normal
            anchors.fill: parent
            color: Colors.colPrimary
            fillOpacity: 0.35
            
        }

        onHistoryChanged: sync()
        Component.onCompleted: sync()

        function sync() {
            graph.series.clear();
            for (var i = 0; i < root.dlHistory.length; ++i)
                graph.series.append(i, root.dlHistory[i]);
        }
    }
    component SpeedRow: RowLayout {
        id: row
        property string text
        property string label
        property string value
        property bool accent: false
        Layout.leftMargin: Padding.large
        spacing: Padding.large

        MaterialShapeWrappedSymbol {
            shape: MaterialShape.Shape.Circle
            color: row.accent ? Colors.colPrimary : Colors.colSecondary
            colSymbol: row.accent ? Colors.colOnPrimary : Colors.colOnSecondary
            text: row.text
            iconSize: Fonts.sizes.normal
            fill: 1
            padding: Padding.tiny
            implicitSize: Fonts.sizes.verylarge + Padding.small
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Padding.tiny

            StyledText {
                Layout.fillWidth: true
                text: row.label
                color: Colors.colOnSurfaceVariant
                font: Fonts.request("main", "verysmall")
            }
            StyledText {
                Layout.fillWidth: true
                text: row.value
                color: Colors.colOnLayer0
                font: Fonts.request("numbers", "normal")
            }
        }
    }
}
