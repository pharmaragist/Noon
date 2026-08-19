import qs.common
import qs.common.utils

JsonAdapter {
    property string directory: Directories.methods.trim(Directories.standard.home)
    property list<string> folders: []
    property var library: []
    property int webClientPort: 8090

    property JO options: JO {
        property int fetchLimit: 24
        property bool adaptiveTheme: true
        property string visualizerMode: "Filled"
        property list<string> excludedPlayers: ["playerctld", "kdeconnect"]
        property bool showLyrics: true
        property string homePageStyle: "PixelPlayer"
    }

    property JO hits: JO {
        property string recommendationsMode: "both"
    }
}
