import qs.common
import qs.common.utils

JsonAdapter {
    property string directory: Paths.methods.trim(Paths.standard.music)
    property list<string> folders: []

    property JO options: JO {
        property int fetchLimit: 72
        property bool adaptiveTheme: true
        property string visualizerMode: "Filled"
        property list<string> excludedPlayers: ["playerctld", "kdeconnectd"]
        property bool showLyrics: true
        property string homePageStyle: "PixelPlayer"
    }

    property JO hits: JO {
        property string recommendationsMode: "tracks"
        property var searchResults: []
        property var feed: []
    }
}
