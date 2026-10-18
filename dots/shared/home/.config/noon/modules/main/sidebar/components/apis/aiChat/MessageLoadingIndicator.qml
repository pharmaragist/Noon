import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

Item {
    id: loadingIndicator
    property var messageData
    property int blockCount: 0
    property bool done: false
    property bool queued: false
    property bool loading: blockCount === 0 && !done && !queued
    implicitHeight: 40

    RowLayout {
        id: row
        visible: loadingIndicator.loading
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Padding.large

        MaterialLoadingIndicator {
            loading: loadingIndicator.loading
            implicitSize: 35
        }

        StyledText {
            id: phrase
            font: Fonts.request("title", "large")
            color: Colors.colOnSurface
            animateChange: true
            text: "Thinking ..."

            function updateText() {
                const gerundVerbs = ["accelerating", "achieving", "advancing", "analyzing", "architecting", "building", "calculating", "caramelizing", "carrying", "climbing", "coding", "collaborating", "composing", "connecting", "crafting", "creating", "debugging", "deciding", "delivering", "designing", "developing", "discovering", "discussing", "driving", "engineering", "engaging", "evaluating", "examining", "executing", "expanding", "explaining", "exploring", "fashioning", "flying", "focusing", "forging", "generating", "growing", "honking", "imagining", "incubating", "innovating", "interacting", "inventing", "jumping", "launching", "leading", "learning", "listening", "making", "managing", "marinating", "memorizing", "mentoring", "molding", "moving", "navigating", "negotiating", "noodling", "operating", "perceiving", "percolating", "performing", "planning", "pondering", "predicting", "processing", "producing", "pushing", "reading", "reasoning", "reflecting", "running", "scaling", "shaping", "sharing", "shifting", "simmering", "sketching", "solving", "speaking", "stepping", "striving", "studying", "swimming", "teaching", "testing", "thinking", "translating", "traveling", "understanding", "uniting", "verbalizing", "visualizing", "walking", "whispering", "writing"];

                const randomIndex = Math.floor(Math.random() * gerundVerbs.length);
                phrase.text = phrase.methods.capitalizeFirstLetter(gerundVerbs[randomIndex]) + " ...";
            }

            Timer {
                interval: 2000
                running: true
                repeat: true
                onTriggered: phrase.updateText()
            }
        }
    }
}
