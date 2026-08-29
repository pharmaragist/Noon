import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.functions
import qs.common.widgets

WidgetContainer {
    id: root

    property var upcomingEvents: CalendarService.getUpcomingEvents(7)
    property int monthShift: 0
    property var calendarLayout: CalendarUtils.getCalendarLayout(viewingDate, monthShift === 0)
    property var viewingDate: CalendarUtils.getDateInXMonthsTime(monthShift)
    readonly property string today: DateTimeService.request("d/M/yyyy")
    Component.onCompleted: CalendarService.pull()

    small: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.normal
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: DateTimeService.request("ddd")
            color: Colors.colPrimary
            font: Fonts.request("main", "verysmall", {
                weight: Font.DemiBold
            })
            horizontalAlignment: Text.AlignHCenter
        }

        Spacer {}

        StyledText {
            Layout.fillWidth: true
            text: DateTimeService.request("d")
            color: Colors.colOnLayer0
            font: Fonts.request("numbers", Fonts.sizes.title)
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Padding.tiny
            text: DateTimeService.request("MMM").toUpperCase()
            color: Colors.colOnSurfaceVariant
            font: Fonts.request("main", "verysmall")
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Padding.tiny
            implicitWidth: 4
            implicitHeight: 4
            visible: root.getTasksOfDate(root.today).length > 0

            Rectangle {
                anchors.fill: parent
                radius: Rounding.full
                color: Colors.colPrimary
            }
        }

        Spacer {}
    }

    normal: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.normal

        MonthCalendar {}
    }

    large: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Padding.huge
        anchors.rightMargin: Padding.huge
        spacing: Padding.normal

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Padding.large
            StyledText {
                Layout.fillWidth: true
                text: DateTimeService.request("dddd")
                color: Colors.colPrimary
                font: Fonts.request("main", Fonts.sizes.small)
            }

            StyledText {
                Layout.fillWidth: true
                text: DateTimeService.request("d")
                color: Colors.colOnLayer0
                font: Fonts.request("numbers", 40)
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Padding.tiny
                text: {
                    const n = root.getTasksOfDate(root.today).length;
                    return n + (n === 1 ? " Event Today" : " Events Today");
                }
                color: Colors.colOnSurfaceVariant
                font: Fonts.request("main", Fonts.sizes.verysmall)
            }

            StyledListView {
                radius: 0
                clip: true
                hint: false
                Layout.topMargin: Padding.normal
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: getTasksOfDate(root.today)
                delegate: Item {
                    required property var modelData
                    anchors.right: parent?.right
                    anchors.left: parent?.left
                    height: 55
                    RLayout {
                        anchors.fill: parent

                        ColumnLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: modelData.content
                                color: Colors.colOnLayer0
                                font: Fonts.request("main", Fonts.sizes.normal)
                                Layout.fillWidth: true
                                truncate: true
                                Layout.rightMargin: Padding.large
                            }
                            StyledText {
                                visible: text.length > 0
                                text: {
                                    if (modelData.isTask)
                                        return "";
                                    const parts = modelData.end.split('/');
                                    return "Ends at " + parts[0] + '/' + parts[1];
                                }
                                color: Colors.colOnSurfaceVariant
                                font: Fonts.request("main", Fonts.sizes.verysmall)
                                Layout.fillWidth: true
                                truncate: true
                            }
                        }
                    }
                }

                StyledText {
                    visible: parent.count === 0
                    text: "No Events Today"
                    anchors.centerIn: parent
                    font.pixelSize: Fonts.sizes.small
                    color: Colors.colSubtext
                }
            }
        }

        MonthCalendar {}
    }

    xlarge: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.large
        spacing: Padding.large

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                Layout.leftMargin: Padding.small
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: -Padding.verysmall

                StyledText {
                    text: DateTimeService.request("dddd")
                    color: Colors.colPrimary
                    font: Fonts.request("main", Fonts.sizes.small)
                }

                StyledText {
                    text: DateTimeService.request("d")
                    color: Colors.colOnLayer0
                    font: Fonts.request("numbers", 40)
                }

                StyledText {
                    Layout.topMargin: Padding.tiny
                    text: {
                        const n = root.getTasksOfDate(root.today).length;
                        return n + (n === 1 ? " Event Today" : " Events Today");
                    }
                    color: Colors.colOnSurfaceVariant
                    font: Fonts.request("main", Fonts.sizes.verysmall)
                }

                StyledListView {
                    radius: 0
                    clip: true
                    hint: false
                    Layout.topMargin: Padding.normal
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: getTasksOfDate(root.today)
                    delegate: Item {
                        required property var modelData
                        anchors.right: parent?.right
                        anchors.left: parent?.left
                        height: 55
                        RLayout {
                            anchors.fill: parent

                            ColumnLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    text: modelData.content
                                    color: Colors.colOnLayer0
                                    font: Fonts.request("main", Fonts.sizes.normal)
                                    Layout.fillWidth: true
                                    truncate: true
                                    Layout.rightMargin: Padding.large
                                }
                                StyledText {
                                    visible: text.length > 0
                                    text: {
                                        if (modelData.isTask)
                                            return "";
                                        const parts = modelData.end.split('/');
                                        return "Ends at " + parts[0] + '/' + parts[1];
                                    }
                                    color: Colors.colOnSurfaceVariant
                                    font: Fonts.request("main", Fonts.sizes.verysmall)
                                    Layout.fillWidth: true
                                    truncate: true
                                }
                            }
                        }
                    }
                    StyledText {
                        visible: parent.count === 0
                        text: "No Events Today"
                        anchors.centerIn: parent
                        font.pixelSize: Fonts.sizes.small
                        color: Colors.colSubtext
                    }
                }
            }
            MonthCalendar {}
        }
        Spacer {}
    }
}
