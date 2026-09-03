pragma Singleton
pragma ComponentBehavior: Bound
import qs.common
import qs.data
import qs.common.utils
import qs.common.functions
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var list: {
        const db = Paths.assets + "/db/emojies.json";
        const content = Paths.methods.readFile(db);
        let parsed = [];
        try {
            parsed = JSON.parse(content);
        } catch (_) {
            console.error("EmojisService: ", _);
        }
        return parsed;
    }

    readonly property var frequentEmojis: {
        const emojis = Mem.states.services.emojis.frequentEmojies || [];
        const counts = {};

        emojis.forEach(e => counts[e] = (counts[e] || 0) + 1);

        return Object.entries(counts).sort((a, b) => b[1] - a[1]).map(([e]) => e);
    }

    function recordEmojiUse(emoji: string) {
        const emojiChar = emoji.split(' ')[0];
        Mem.states.services.emojis.frequentEmojies.push(emojiChar);
    }

    function searchEmojis(query: string) {
        if (!query || query.trim() === "") {
            return root.list;
        }

        const lowerQuery = query.toLowerCase();
        return root.list.filter(emoji => {
            return emoji.name.toLowerCase().includes(lowerQuery) || emoji.category.toLowerCase().includes(lowerQuery) || emoji.subcategory.toLowerCase().includes(lowerQuery) || emoji.emoji.includes(query);
        });
    }
}
