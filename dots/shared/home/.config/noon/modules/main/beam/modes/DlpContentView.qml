import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services
import qs.common.widgets

PanelRect {
    id: root

    readonly property string url: Globals.main.beam.payload

    function dismiss() {
        Globals.main.beam.show = false;
        Globals.main.beam.reason = "default";
    }

    function execute() {
        if (!root.url)
            return;

        const mode = modeCombo.model[(modeCombo?.currentIndex ?? 0)]?.toLowerCase();
        const label = qualityRow.model[(qualityRow?.currentIndex ?? 0)]?.toLowerCase();
        const isAudio = mode === "audio";
        const dir = isAudio ? Paths.methods.trim(Paths.standard.music) : Paths.methods.trim(Paths.standard.videos);

        const request = {
            url: root.url,
            audio: isAudio,
            quality: label,
            directory: dir,
            toast: true
        };

        DlpService.request(request);

        Qt.callLater(() => {
            root.dismiss();
        });
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: Padding.massive

            RowLayout {
                Layout.fillWidth: true
                height: 45
                spacing: Padding.huge

                MaterialShapeWrappedSymbol {
                    iconSize: 36
                    text: "play_arrow"
                    _shape: "Pill"
                }

                ColumnLayout {
                    Layout.preferredHeight: 40
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: "Media Downloader"
                        font: Fonts.request("title", "large")
                        color: Colors.colOnLayer0
                    }

                    StyledText {
                        text: "Wanna Grab that link ?"
                        font: Fonts.request("reading", "normal")
                        color: Colors.colSubtext
                    }
                }
            }

            RowLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: Padding.large

                StyledComboBox {
                    id: qualityRow
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignLeft
                    model: ["Best", "Standard", "Low"]
                }

                StyledComboBox {
                    id: modeCombo
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignLeft
                    model: ["Audio", "Video"]
                }

                RippleButtonWithIcon {
                    implicitSize: 45
                    buttonRadius: Rounding.large
                    toggled: true
                    materialIcon: "download"
                    downAction: () => root.execute()
                }
            }
        }
    }
}
