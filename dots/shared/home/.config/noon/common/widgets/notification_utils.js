




function findSuitableMaterialSymbol(summary = "") {
    const defaultType = 'chat';
    if(summary.length === 0) return defaultType;

    const keywordsToTypes = {
        'reboot': 'restart_alt',
        'recording': 'screen_record',
        'battery': 'power',
        'power': 'power',
        'screenshot': 'screenshot_monitor',
        'welcome': 'waving_hand',
        'time': 'scheduleb',
        'installed': 'download',
        'configuration reloaded': 'reset_wrench',
        'config': 'reset_wrench',
        'update': 'update',
        'ai response': 'neurology',
        'control': 'settings',
        'upscale': 'compare',
        'install': 'deployed_code_update',
        'startswith:file': 'folder_copy', 
    };

    const lowerSummary = summary.toLowerCase();

    for (const [keyword, type] of Object.entries(keywordsToTypes)) {
        if (keyword.startsWith('startswith:')) {
            const startsWithKeyword = keyword.replace('startswith:', '');
            if (lowerSummary.startsWith(startsWithKeyword)) {
                return type;
            }
        } else if (lowerSummary.includes(keyword)) {
            return type;
        }
    }

    return defaultType;
}





const getFriendlyNotifTimeString = (timestamp) => {
    if (!timestamp) return '';
    const messageTime = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - messageTime.getTime();

    
    if (diffMs < 60000) 
        return 'Now';
    
    
    if (messageTime.toDateString() === now.toDateString()) {
        const diffMinutes = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        
        if (diffHours > 0) {
            return `${diffHours}h`;
        } else {
            return `${diffMinutes}m`;
        }
    }
    
    
    if (messageTime.toDateString() === new Date(now.getTime() - 86400000).toDateString()) 
        return 'Yesterday';
    
    
    return Qt.formatDateTime(messageTime, "MMMM dd");
};