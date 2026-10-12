import qs.common.utils

JsonAdapter {
    property JO misc: JO {
        property list<string> systemCommands: []
    }

    property JO services: JO {
        property JO search: JO {
            property list<string> history: []
        }
        property JO weather: JO {
            property var data: ({})
        }
        property JO colors: JO {
            property list<var> palettes: []
        }
        property JO cursors: JO {
            property list<var> availableCursors: []
        }
        property JO icons: JO {
            property list<var> availableIconThemes: []
        }
        property JO ambientSounds: JO {
            property list<var> availableSounds: []
        }
    }
}
