import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.services
import qs.common.widgets
import qs.common.functions

SidebarItemContainer {
    id: root
    readonly property var engine: EqService
    readonly property var profiles: engine.profiles
    property string activePreset: "Custom"
    colors: MediaPlayerService.colors

    function statusText() {
        if (!engine.connected)
            return "Engine unavailable";
        if (!engine.ready)
            return "Reading equalizer…";
        if (!engine.enabled)
            return "Equalizer is off";
        return "Shape your sound";
    }

    function applyPreset(name) {
        if (!engine.ready)
            return;

        // Ten-band starting points adapted from the Figma interface. For a
        // different band count, interpolate across the same left-to-right
        // tonal shape instead of dropping bands.
        const gains = profiles[name];
        if (!gains)
            return;

        const count = engine.bands.length;
        for (let i = 0; i < count; i++) {
            const pos = count <= 1 ? 0 : i * (gains.length - 1) / (count - 1);
            const lo = Math.floor(pos);
            const hi = Math.min(gains.length - 1, lo + 1);
            const gain = gains[lo] + (gains[hi] - gains[lo]) * (pos - lo);
            if (engine.bands[i].type === 0 && Math.abs(gain) > 0.01)
                engine.setBand(i, "type", 1);
            engine.setBand(i, "gain", gain);
        }
        activePreset = name;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.huge
        spacing: Padding.large

        // Engine unavailable and loading states match the existing plugin
        // behavior, while the ready state uses the new slider-first layout.
        MaterialLoadingIndicator {
            z: 9999
            Layout.alignment: Qt.AlignCenter
            loading: !engine.ready
            visible: loading
            implicitSize: 100
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: engine.ready
            contentWidth: width
            contentHeight: readyContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: readyContent
                width: parent.width
                spacing: Padding.huge

                StyledRect {
                    Layout.fillWidth: true
                    color: root.colors.colLayer1
                    radius: Rounding.verylarge
                    implicitHeight: eqContent.implicitHeight + Padding.large * 2

                    ColumnLayout {
                        id: eqContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Padding.huge
                        spacing: Padding.normal

                        RowLayout {
                            Layout.bottomMargin: Padding.normal
                            Layout.fillWidth: true
                            Layout.maximumHeight: 40

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.maximumHeight: 40

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "LIVE EQ"
                                    font: Fonts.request("main", "small")
                                    color: root.colors.colSubtext
                                }

                                StyledText {
                                    text: root.activePreset
                                    font: Fonts.request("title", "normal")
                                    color: root.colors.colOnSurface
                                }
                            }
                            StyledSwitch {
                                enabled: engine.ready
                                checked: engine.enabled
                                onClicked: engine.setEnabled(!engine.enabled)
                                colors: root.colors
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 226
                            spacing: Padding.small

                            ColumnLayout {
                                Layout.preferredWidth: 24
                                Layout.fillHeight: true
                                spacing: 0
                                StyledText {
                                    text: "+12"
                                    font: Fonts.request("main", 10)
                                    color: root.colors.colSubtext
                                }
                                Item {
                                    Layout.fillHeight: true
                                }
                                StyledText {
                                    text: "0"
                                    font: Fonts.request("main", 10)
                                    color: root.colors.colSubtext
                                }
                                Item {
                                    Layout.fillHeight: true
                                }
                                StyledText {
                                    text: "-12"
                                    font: Fonts.request("main", 10)
                                    color: root.colors.colSubtext
                                }
                            }

                            // Keep every band reachable on narrower sidebars.
                            ListView {
                                id: bandList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                orientation: ListView.Horizontal
                                layoutDirection: Qt.LeftToRight
                                spacing: Padding.small
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                interactive: !engine.interacting && contentWidth > width
                                cacheBuffer: 100000
                                reuseItems: false
                                model: engine.bands.length

                                delegate: Item {
                                    id: bandItem
                                    required property int index
                                    readonly property var band: engine.bands[index]

                                    width: 38
                                    height: bandList.height

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: Padding.small

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: bandItem.band ? (bandItem.band.gain > 0 ? "+" : "") + (Math.round(bandItem.band.gain * 10) / 10).toFixed(1) : "0.0"
                                            font: Fonts.request("main", 9)
                                            color: (bandItem.band && bandItem.band.type > 0) ? root.colors.colPrimary : root.colors.colSubtext
                                        }

                                        VStyledSlider {
                                            id: bandSlider
                                            enableTooltip: false
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.fillHeight: true
                                            Layout.preferredWidth: 28
                                            reversed: false
                                            from: -12
                                            to: 12
                                            enabled: engine.ready && engine.enabled
                                            Accessible.name: bandItem.band ? "Band " + (bandItem.index + 1) + ", " + Math.round(bandItem.band.freq) + " hertz" : "Equalizer band"
                                            colors: root.colors

                                            Binding {
                                                target: bandSlider
                                                property: "value"
                                                value: bandItem.band ? Math.max(-12, Math.min(12, bandItem.band.gain)) : 0
                                                when: !bandSlider.pressed
                                            }

                                            onMoved: {
                                                if (bandItem.band && bandItem.band.type === 0)
                                                    engine.setBand(bandItem.index, "type", 1);
                                                engine.setBand(bandItem.index, "gain", Math.round(value * 10) / 10);
                                                root.activePreset = "Custom";
                                            }

                                            onPressedChanged: engine.interacting = pressed
                                        }

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: bandItem.band ? (bandItem.band.freq >= 1000 ? Math.round(bandItem.band.freq / 100) / 10 + "k" : Math.round(bandItem.band.freq)) : ""
                                            font: Fonts.request("main", 10)
                                            color: root.colors.colSubtext
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                text: "BASS"
                                font: Fonts.request("main", "small")
                                color: root.colors.colSubtext
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            StyledText {
                                text: "MIDS"
                                font: Fonts.request("main", "small")
                                color: root.colors.colSubtext
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            StyledText {
                                text: "TREBLE"
                                font: Fonts.request("main", "small")
                                color: root.colors.colSubtext
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: root.colors.colOutlineVariant
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80

                            RowLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Preamp"
                                    font: Fonts.request("main", "small")
                                    color: root.colors.colOnSurface
                                }
                                StyledText {
                                    text: Math.round(engine.preamp * 10) / 10 + " dB"
                                    font: Fonts.request("main", "small")
                                    color: root.colors.colSubtext
                                }
                                RippleButton {
                                    colors: root.colors
                                    implicitWidth: 54
                                    implicitHeight: 30
                                    buttonText: "Reset"
                                    onClicked: {
                                        engine.resetAll();
                                        root.activePreset = "Balanced";
                                    }
                                }
                            }

                            StyledSlider {
                                id: preampSlider
                                enableTooltip: false
                                Layout.fillWidth: true
                                from: -36
                                to: 36
                                enabled: engine.ready && engine.enabled
                                highlightColor: root.colors.colPrimary
                                trackColor: root.colors.colPrimaryContainer
                                handleColor: root.colors.colOnPrimaryContainer
                                Binding {
                                    target: preampSlider
                                    property: "value"
                                    value: engine.preamp
                                    when: !preampSlider.pressed
                                }
                                onMoved: engine.setPreamp(Math.round(value * 10) / 10)
                                onPressedChanged: engine.interacting = pressed
                            }
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    color: root.colors.colSecondaryContainer
                    radius: Rounding.verylarge
                    implicitHeight: presetsContent.implicitHeight + Padding.huge * 2

                    ColumnLayout {
                        id: presetsContent
                        anchors.fill: parent
                        anchors.margins: Padding.huge
                        spacing: Padding.small

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.maximumHeight: 40

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    text: "QUICK START"
                                    font: Fonts.request("main", 11)
                                    color: root.colors.colSubtext
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Presets"
                                    font: Fonts.request("title", "normal")
                                    color: root.colors.colOnSurface
                                }
                            }

                            RippleButtonWithIcon {
                                colors: root.colors
                                materialIcon: "expand_content"
                                colBackground: "transparent"
                                toggled: presetListView.expanded
                                onClicked: presetListView.expanded = !presetListView.expanded
                            }
                        }

                        StyledListView {
                            id: presetListView
                            property bool expanded: false

                            clip: true
                            hinter.color: root.colors.colSecondaryContainer
                            Layout.minimumHeight: expanded ? contentHeight : 270
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            model: Object.keys(root.profiles)
                            spacing: Padding.small
                            currentIndex: model.indexOf(root.activePreset)

                            highlight: StyledRect {
                                width: presetListView.width
                                height: 56
                                radius: Rounding.verylarge
                                color: root.colors.colSecondary
                                z: 0

                                Behavior on y {
                                    SAnim {}
                                }
                            }
                            highlightFollowsCurrentItem: true
                            highlightMoveDuration: 200

                            delegate: Item {
                                id: delegateRoot
                                required property string modelData
                                required property int index
                                property bool selected: root.activePreset === modelData

                                anchors.left: parent?.left
                                anchors.right: parent?.right
                                implicitHeight: 56

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Padding.normal
                                    spacing: Padding.large
                                    z: 1

                                    StyledRect {
                                        implicitWidth: 42
                                        implicitHeight: 42
                                        radius: Rounding.large
                                        color: selected ? root.colors.colPrimary : root.colors.colLayer1

                                        Symbol {
                                            anchors.centerIn: parent
                                            icon: "graphic_eq"
                                            iconSize: 20
                                            color: selected ? root.colors.colOnPrimary : root.colors.colOnSurface
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData
                                        font: Fonts.request("main", "normal")
                                        color: selected ? root.colors.colOnSecondary : root.colors.colOnSurface
                                    }

                                    Symbol {
                                        visible: selected
                                        icon: "check"
                                        iconSize: 24
                                        fill: 1
                                        color: root.colors.colOnSecondary
                                    }
                                }

                                MouseArea {
                                    id: presetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        presetListView.currentIndex = index;
                                        root.applyPreset(modelData);
                                    }
                                    Accessible.role: Accessible.Button
                                    Accessible.name: modelData + " preset"
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    color: root.colors.colTertiaryContainer
                    radius: Rounding.verylarge
                    implicitHeight: tipRow.implicitHeight + Padding.huge * 2

                    RowLayout {
                        id: tipRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Padding.verylarge
                        spacing: Padding.huge

                        Symbol {
                            icon: "auto_awesome"
                            iconSize: 24
                            color: root.colors.colTertiary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: "Make it yours"
                                font: Fonts.request("title", "normal")
                                color: root.colors.colOnSurface
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "Tap any band and move it until the music feels just right."
                                wrapMode: Text.WordWrap
                                font: Fonts.request("main", "small")
                                color: root.colors.colOnSurface
                            }
                        }
                    }
                }
            }
        }
    }
}
