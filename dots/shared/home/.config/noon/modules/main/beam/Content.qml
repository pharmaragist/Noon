import QtQuick
import qs.common
import qs.common.widgets

PanelRect {
    id: root

    property bool reveal: false
    readonly property var conf: Mem.options.beam.appearance
    readonly property real animationScale: conf.animationScale ?? 1
    readonly property int animationStyle: {
        const dict = {
            "expo": Content.Style.Expo,
            "slidebottom": Content.Style.SlideBottom,
            "springpop": Content.Style.SpringPop,
            "glide": Content.Style.Glide
        };
        return dict[(conf.animationStyle ?? "expo").toLowerCase()] ?? Content.Style.Expo;
    }

    property url contentSource: ""
    signal contentLoaded(var item)
    property int elevationValue: 0
    property bool _sizeMorphArmed: false
    property url _lastContent: ""

    readonly property bool _spring: animationStyle === Content.Style.SpringPop
    readonly property bool _glide: animationStyle === Content.Style.Glide
    readonly property bool _slide: animationStyle === Content.Style.SlideBottom
    readonly property bool _noScale: _slide || _glide

    readonly property int _morphDuration: (_spring ? 380 : _glide ? 280 : _noScale ? 260 : 300) * root.animationScale
    readonly property int _revealDuration: (_spring ? 500 : _glide ? 380 : _noScale ? 300 : 380) * root.animationScale
    readonly property int _hideDuration: (_spring ? 280 : _glide ? 240 : _noScale ? 240 : 260) * root.animationScale
    readonly property int _morphEasingType: _spring ? Easing.OutBack : _glide ? Easing.InOutCubic : _noScale ? Easing.OutCubic : Easing.OutExpo
    readonly property int _hideEasingType: _spring ? Easing.InBack : _glide ? Easing.InOutCubic : _noScale ? Easing.InCubic : Easing.InExpo
    readonly property real _morphOvershoot: _spring ? 2.2 : 1.70158
    readonly property real _hideOvershoot: _spring ? 1.5 : 1.70158

    property real translateY: 0
    readonly property real _hiddenTranslateY: _slide ? root.elevationValue + root.implicitHeight * 0.4 : root.elevationValue + (_glide ? 8 : 10)

    enum Style {
        Expo,
        SlideBottom,
        SpringPop,
        Glide
    }

    anchors {
        horizontalCenter: parent ? parent.horizontalCenter : undefined
        bottom: parent ? parent.bottom : undefined
        bottomMargin: elevationValue
    }

    transform: Translate {
        y: root.translateY
    }

    transformOrigin: Item.Bottom

    Behavior on bottomRadius {
        enabled: root._sizeMorphArmed
        NumberAnimation {
            duration: root._morphDuration
            easing.type: root._morphEasingType
            easing.overshoot: root._morphOvershoot
        }
    }
    Behavior on width {
        enabled: root._sizeMorphArmed
        NumberAnimation {
            duration: root._morphDuration
            easing.type: root._morphEasingType
            easing.overshoot: root._morphOvershoot
        }
    }
    Behavior on height {
        enabled: root._sizeMorphArmed
        NumberAnimation {
            duration: root._morphDuration
            easing.type: root._morphEasingType
            easing.overshoot: root._morphOvershoot
        }
    }

    onRevealChanged: {
        if (root.reveal) {
            root._sizeMorphArmed = true;
            if (stack.currentItem)
                root.contentLoaded(stack.currentItem);
        }
    }

    onContentSourceChanged: {
        if (contentSource.toString() === "" || contentSource.toString() === root._lastContent.toString())
            return;
        root._lastContent = contentSource;
        if (stack.currentItem)
            stack.replace(contentSource);
        else
            stack.push(contentSource);
    }

    states: [
        State {
            name: "hidden"
            when: !root.reveal
            PropertyChanges {
                target: root
                opacity: 0
                scale: root._noScale ? 1 : 0
                translateY: root._hiddenTranslateY
            }
        },
        State {
            name: "visible"
            when: root.reveal
            PropertyChanges {
                target: root
                opacity: 1
                scale: 1
                translateY: 0
            }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            ParallelAnimation {
                NumberAnimation {
                    target: root
                    property: "opacity"
                    duration: root._glide ? root._revealDuration : 200 * root.animationScale
                    easing.type: root._glide ? root._morphEasingType : Easing.OutCubic
                }
                NumberAnimation {
                    target: root
                    property: "translateY"
                    duration: root._revealDuration
                    easing.type: root._morphEasingType
                    easing.overshoot: root._morphOvershoot
                }
                NumberAnimation {
                    target: root
                    property: "scale"
                    duration: root._noScale ? 0 : root._revealDuration
                    easing.type: root._noScale ? Easing.Linear : root._morphEasingType
                    easing.overshoot: root._morphOvershoot
                }
            }
        },
        Transition {
            to: "hidden"
            ParallelAnimation {
                NumberAnimation {
                    target: root
                    property: "opacity"
                    duration: root._glide ? root._hideDuration : 450 * root.animationScale
                    easing.type: root._glide ? root._hideEasingType : Easing.InCubic
                }
                NumberAnimation {
                    target: root
                    property: "translateY"
                    duration: root._hideDuration
                    easing.type: root._hideEasingType
                    easing.overshoot: root._hideOvershoot
                }
                NumberAnimation {
                    target: root
                    property: "scale"
                    duration: root._noScale ? 0 : root._hideDuration
                    easing.type: root._noScale ? Easing.Linear : root._hideEasingType
                    easing.overshoot: root._hideOvershoot
                }
            }
        }
    ]

    StyledStackView {
        id: stack
        anchors.fill: parent

        pushEnter: Transition {
            ParallelAnimation {
                PropertyAnimation {
                    property: "scale"
                    from: 0.94
                    to: 1
                    duration: root._morphDuration
                    easing.type: Easing.OutCubic
                }
                PropertyAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: root._morphDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
        pushExit: Transition {
            ParallelAnimation {
                PropertyAnimation {
                    property: "scale"
                    from: 1
                    to: 0.96
                    duration: root._morphDuration * 0.5
                    easing.type: Easing.OutCubic
                }
                PropertyAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: root._morphDuration * 0.5
                    easing.type: Easing.OutCubic
                }
            }
        }
        replaceEnter: Transition {
            ParallelAnimation {
                PropertyAnimation {
                    property: "scale"
                    from: 0.94
                    to: 1
                    duration: root._morphDuration
                    easing.type: Easing.OutCubic
                }
                PropertyAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: root._morphDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
        replaceExit: Transition {
            ParallelAnimation {
                PropertyAnimation {
                    property: "scale"
                    from: 1
                    to: 0.96
                    duration: root._morphDuration * 0.5
                    easing.type: Easing.OutCubic
                }
                PropertyAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: root._morphDuration * 0.5
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Connections {
        target: stack
        function onCurrentItemChanged() {
            if (stack.currentItem)
                root.contentLoaded(stack.currentItem);
        }
    }
}
