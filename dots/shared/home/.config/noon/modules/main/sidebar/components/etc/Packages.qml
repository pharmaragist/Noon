import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.common
import qs.common.utils
import qs.common.widgets
import qs.services

SidebarItemContainer {
    id: root

    property string installing: ""
    property int installPercent: 0
    property string installMessage: ""

    readonly property var status: PackagesService.status

    readonly property bool allInstalled: {
        if (root.installing !== "")
            return false;
        const keys = Object.keys(root.status);
        for (let i = 0; i < keys.length; i++)
            if (!root.status[keys[i]].installed)
                return false;
        return keys.length > 0;
    }

    function refresh() {
        PackagesService.getStatus();
    }

    Component.onCompleted: NoonUtils.inlineTimer(() => refresh(), 200)

    Connections {
        target: PackagesService
        function onProgress(group, percent, message) {
            root.installing = group;
            root.installPercent = percent;
            root.installMessage = message;
            if (percent >= 100) {
                root.installing = "";
                root.installPercent = 0;
                root.refresh();
            }
        }
        function onError(group, message) {
            root.installing = group;
            root.installPercent = 100;
            root.installMessage = "Failed: " + message;
            root.refresh();
            errorTimer.restart();
        }
    }

    Timer {
        id: errorTimer
        interval: 4000
        onTriggered: {
            root.installing = "";
            root.installPercent = 0;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Padding.huge
        anchors.rightMargin: Padding.huge
        anchors.topMargin: Padding.normal
        anchors.bottomMargin: Padding.normal
        spacing: Padding.huge

        PageHeader {
            title: "Packages"
            subTitle: root.allInstalled ? "Everything is up to date" : "Runtime dependencies & models"
            GroupButtonWithIcon {
                materialIcon: "refresh"
                onClicked: root.refresh()
            }
        }

        StyledListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Rounding.large
            clip: true
            _model: PackagesService.list
            spacing: 2

            delegate: PackageItem {
                anchors.left: parent?.left
                anchors.right: parent?.right
                listCount: listView.count
            }

            StyledText {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: "No package groups configured"
                font.pixelSize: Fonts.sizes.normal
                color: Colors.colOnSurfaceVariant
            }
        }
    }

    component PackageItem: Item {
        id: itemRoot
        required property var modelData
        required property int index
        property int listCount: 1
        property bool expanded: false
        readonly property bool isInstalled: root.status?.[modelData.name]?.installed ?? false
        readonly property bool isInstalling: root.installing === modelData.name
        readonly property var missing: root.status?.[modelData.name]?.missing ?? []
        readonly property var deps: modelData.dependencies ?? Object.values(modelData.mirrors ?? {})

        implicitHeight: card.implicitHeight

        MouseArea {
            anchors.fill: parent
            onClicked: itemRoot.expanded = !itemRoot.expanded
        }

        StyledRect {
            id: card
            clip: true

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.left: parent.left

            implicitHeight: Math.max(65, mainInfoCol.implicitHeight + Padding.massive)
            topRadius: index === 0 ? Rounding.huge : 2
            bottomRadius: index === itemRoot.listCount - 1 ? Rounding.huge : 2
            color: Colors.colLayer2

            ColumnLayout {
                id: mainInfoCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right

                anchors.leftMargin: Padding.large
                anchors.rightMargin: Padding.large
                anchors.topMargin: Padding.massive / 2
                spacing: Padding.large

                RowLayout {
                    Layout.leftMargin: Padding.large
                    Layout.rightMargin: Padding.large
                    Layout.fillWidth: true
                    spacing: Padding.huge

                    StyledRect {
                        implicitSize: 45
                        radius: Rounding.full
                        color: itemRoot.isInstalled ? Colors.colSuccessContainer : Colors.colPrimaryContainer

                        Symbol {
                            anchors.centerIn: parent
                            icon: modelData.icon ?? "package"
                            iconSize: 24
                            color: itemRoot.isInstalled ? Colors.colSuccess : Colors.colOnPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        id: infoSection
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            font: Fonts.request("title", "large")
                            color: Colors.colOnLayer0
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.description || "No additional info"
                            font: Fonts.request("main", "small")
                            color: Colors.colSubtext
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            text: itemRoot.isInstalling ? root.installMessage : (itemRoot.isInstalled ? "All dependencies installed" : (itemRoot.missing.length ? "Missing: " + itemRoot.missing.join(", ") : "-"))
                            font: Fonts.request("mono", Fonts.sizes.small)
                            color: itemRoot.isInstalling ? (root.installPercent >= 100 ? Colors.colError : Colors.colSubtext) : (itemRoot.isInstalled ? Colors.colSuccess : Colors.colError)
                            elide: Text.ElideRight
                        }
                    }

                    GroupButtonWithIcon {
                        visible: !itemRoot.isInstalling
                        baseSize: 50
                        layerNumber: 2
                        buttonRadius: height / 2
                        toggled: !itemRoot.isInstalled
                        enabled: !itemRoot.isInstalled
                        materialIcon: itemRoot.isInstalled ? "check" : "download"
                        releaseAction: () => {
                            root.installing = modelData.name;
                            root.installPercent = 0;
                            root.installMessage = "Starting...";
                            PackagesService.install(modelData.name);
                        }
                        altAction: () => {
                            PackagesService.install(modelData.name, true);
                        }
                    }

                    CircularProgress {
                        visible: itemRoot.isInstalling
                        sperm: true
                        implicitSize: 36
                        lineWidth: 4
                        value: root.installPercent / 100
                        colPrimary: Colors.colPrimary
                        colSecondary: Colors.colSurfaceContainerHighest
                    }
                }

                ColumnLayout {
                    id: packagesColumn
                    visible: itemRoot.expanded
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: Padding.large
                    spacing: 2
                    Repeater {
                        model: itemRoot.deps
                        StyledRect {
                            required property var modelData
                            required property int index
                            color: Colors.colLayer3
                            Layout.fillWidth: true
                            implicitHeight: 45
                            topRadius: index === 0 ? Rounding.verylarge : 2
                            bottomRadius: index === itemRoot.deps.length - 1 ? Rounding.verylarge : 2

                            RowLayout {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.left: parent.left
                                anchors.margins: Padding.huge
                                spacing: Padding.huge

                                StyledText {
                                    text: modelData
                                    font: Fonts.request("mono", Fonts.sizes.small)
                                    color: Colors.colOnLayer3
                                    Layout.fillWidth: true
                                    truncate: true
                                }

                                Symbol {
                                    icon: itemRoot.missing.includes(modelData) ? "close" : "check"
                                    color: itemRoot.missing.includes(modelData) ? Colors.colError : Colors.colSuccess
                                    iconSize: 20
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: itemRoot.deps.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        horizontalAlignment: Text.AlignHCenter
                        text: "No dependencies"
                        font: Fonts.request("main", "small")
                        color: Colors.colSubtext
                    }
                }
            }
        }
    }
}
