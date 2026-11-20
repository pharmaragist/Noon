import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.functions
import qs.services

Item {
    id: root
    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + Padding.massive

    readonly property var elicitation: Harness.pendingElicitation
    readonly property var fields: elicitation?.fields ?? []
    property var answers: Object.assign({}, elicitation?.values ?? {})
    readonly property var questions: root.fields.filter(f => !(f?.key ?? "").endsWith("_custom"))
    readonly property var question: root.questions[Math.min(root.index, root.questions.length - 1)] ?? ({})
    readonly property var spec: question.spec ?? ({})
    readonly property string fieldKey: question.key ?? ""
    readonly property var custom: root.fields.find(f => f?.key === fieldKey + "_custom") ?? null
    property color color: Colors.colLayer2
    property int index: 0

    readonly property var options: {
        const raw = NoonUtils.isList(spec.oneOf) ? spec.oneOf : NoonUtils.isList(spec.enum) ? spec.enum : (spec.type === "array" && NoonUtils.isList(spec.items?.anyOf)) ? spec.items.anyOf : [];
        return raw.map(o => typeof o === "object" && o !== null ? {
                                                                      value: o.const ?? o.name ?? "",
                                                                      label: o.title ?? o.description ?? String(o.const ?? "")
                                                                  } : {
            value: o,
            label: String(o)
        });
    }
    readonly property bool isMulti: spec.type === "array" && options.length > 0

    Connections {
        target: Harness
        function onPendingElicitationChanged() {
            root.index = 0;
        }
    }

    function setAnswer(key, value) {
        const next = Object.assign({}, root.answers);
        next[key] = value;
        root.answers = next;
    }

    function toggle(value, checked) {
        const arr = NoonUtils.isList(root.answers[fieldKey]) ? root.answers[fieldKey].slice() : [];
        const i = arr.indexOf(value);
        if (checked && i < 0)
            arr.push(value);
        else if (!checked && i >= 0)
            arr.splice(i, 1);
        root.setAnswer(fieldKey, arr);
    }

    function collect() {
        const content = {};
        for (const field of root.fields)
            if (field?.key)
                content[field.key] = root.answers[field.key];
        return content;
    }

    function finish(accepted) {
        Harness.answerElicitation(accepted, root.collect());
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: Padding.normal
        spacing: Padding.huge

        PageHeader {
            title: spec.description ?? spec.title ?? root.elicitation?.message ?? ""
            subTitle: qsTr("Question %1 of %2").arg(root.index + 1).arg(root.questions.length)
            titleItem.font: Fonts.request("title", "large")
            subTitleItem.font: Fonts.request("main", "small")
            implicitHeight: 45
            sideButton {
                visible: true
                materialIcon: "close"
                buttonRadius: Rounding.full
                releaseAction: () => {
                    root.finish(false);
                }
            }
        }

        StyledListView {
            hint: true
            spacing: 3
            Layout.fillHeight: true
            Layout.fillWidth: true
            hinter.color: root.color
            model: options
            Layout.minimumHeight: contentHeight
            delegate: StyledRect {
                required property var modelData
                required property int index

                anchors.left: parent?.left
                anchors.right: parent?.right
                implicitHeight: 50

                topRadius: index === 0 ? Rounding.verylarge : Rounding.tiny
                bottomRadius: index === options.length - 1 ? Rounding.verylarge : Rounding.tiny

                color: selected ? Colors.colSecondaryContainer : Colors.colLayer3

                readonly property bool selected: isMulti
                                                 ? (root.answers[fieldKey] ?? []).indexOf(modelData.value) >= 0
                                                 : root.answers[fieldKey] === modelData.value

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Padding.large
                    anchors.rightMargin: Padding.large

                    StyledRadioButton {
                        checked: selected
                        scale: 0.85
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.label
                        truncate: true
                        font: Fonts.request("main", "small")
                        color: selected ? Colors.colOnSecondaryContainer : Colors.colOnLayer3
                    }
                }

                MouseArea {
                    z: 999
                    anchors.fill: parent
                    onClicked: {
                        if (isMulti)
                            root.toggle(modelData.value, !selected);
                        else
                            root.setAnswer(fieldKey, modelData.value);
                    }
                }
            }
        }

        RowLayout {
            Layout.maximumHeight: 50
            Layout.fillWidth: true
            visible: !!root.custom
            spacing: Padding.normal

            Symbol {
                icon: "edit_note"
                iconSize: 24
                color: Colors.colSubtext
            }

            StyledTextField {
                implicitHeight: 48
                Layout.fillHeight: true
                Layout.fillWidth: true
                placeholderText: root.custom?.spec?.description ?? qsTr("Type your own answer")
                text: String(root.answers[root.custom?.key ?? ""] ?? "")
                onTextChanged: root.setAnswer(root.custom.key, text)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Padding.normal

            DialogButton {
                visible: root.index > 0
                buttonText: qsTr("Back")
                toggled: false
                releaseAction: () => root.index = Math.max(0, root.index - 1)
            }

            Item {
                Layout.fillWidth: true
            }

            DialogButton {
                buttonText: root.index < root.questions.length - 1 ? qsTr("Next") : qsTr("Submit")
                toggled: true
                colText: Colors.colOnPrimary
                releaseAction: () => {
                    if (root.index < root.questions.length - 1)
                        root.index = Math.min(root.questions.length - 1, root.index + 1);
                    else
                        root.finish(true);
                }
            }
        }
    }
}
