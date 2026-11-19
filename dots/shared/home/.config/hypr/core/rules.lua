local function anchored(pattern)
    if pattern:match("^%^") or pattern:match("%$$") then
        return pattern
    end
    return "^(" .. pattern .. ")$"
end

hl.window_rule({
    name = "overrides",
    match = { class = "^(?!(kitty|dolphin|foot|ghostty)$)(.*)" },
    no_blur = unblur_apps,
})

hl.window_rule({
    name = "global",
    match = { class = "^.*" },
    no_blur = unblur_apps,
})

hl.window_rule({
    name = "dolphin",
    match = { class = "^(dolphin.*)" },
    no_blur = true,
})

hl.window_rule({
    name = "browser",
    match = { class = "^(firefox.*)" },
    workspace = "2",
})

hl.window_rule({
    name = "clipboard",
    match = { class = "^(wl-clipboard|wl-copy|wl-paste)$" },
    float = true,
    no_initial_focus = true,
    no_focus = true,
})

for _, app in ipairs({
    { name = "telegram", class = "org.telegram.desktop" },
    { name = "localsend", class = "localsend" },
}) do
    hl.window_rule(
        set_app_as_side_panel("380 99999", {
            name = app.name,
            direction = bar_position,
            animation = "none",
            match = { class = app.class },
        })
    )
end

local floating_apps = {
    { class = "org.quickshell.*",                         size = "50% 55%", center = true },
    { class = "org.kde.kclock.*",                         size = "50% 55%" },
    { class = "hyprland-share-picker.*",                  size = "25% 40%", center = true },
    { class = "pavucontrol-qt",                           size = "60% 65%", center = true },
    { class = "nm-connection-editor",                     size = "45% 37%", center = true },
    { title = "satty",                                    size = "65% 65%" },
    { class = "kcm_.*" },
    { class = ".*plasmawindowed.*" },
    { class = ".*org.kde.kdeconnect.daemon.*" },
    { class = "org.kde.polkit-kde-authentication-agent-1" },
    { class = "org.kde.ark" },
    { class = "blueberry\\.py" },
    { class = "blueman-manager" },
    { class = "nm-applet" },
    { class = "nwg-look" },
    { class = "qt[56]ct" },
    { class = "guifetch" },
    { class = "vlc" },
}

for _, app in ipairs(floating_apps) do
    local match = {}
    if app.class then match.class = anchored(app.class) end
    if app.title then match.title = anchored(app.title) end

    hl.window_rule({
        match = match,
        float = true,
        size = app.size,
        center = app.center,
        move = app.move
    })
end

hl.window_rule({
    name = "offscreen_utility",
    match = { class = "^(plasma-changeicons)$" },
    float = true,
    no_initial_focus = true,
    move = "999999 999999",
})

hl.window_rule({
    name = "klook",
    match = { class = "klook" },
    float = true,
    no_initial_focus = true,
})

hl.window_rule({
    name = "pip",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    size = "25% 25%",
    move = math.floor(m_width * 0.73) .. " " .. math.floor(m_height * 0.72),
    animation = "none",
})

hl.window_rule({
    name = "games",
    match = { title = ".*\\.exe*" },
    immediate = true,
    fullscreen_state = 3,
})

-- Static layer rules: the shell owns these namespaces, so spell each one out.
hl.layer_rule({
    name = "global_layer",
    match = { namespace = "noon.*" },
    blur = false,
    xray = true,
})

hl.layer_rule({
    name = "blurred_layer",
    match = { namespace = "noon:blurred_layer" },
    blur = blur,
    ignore_alpha = layers_alpha,
})

hl.layer_rule({
    name = "noanim_blurred_layer",
    match = { namespace = "noon:noanim_blurred_layer" },
    blur = blur,
    xray = true,
    ignore_alpha = layers_alpha,
    no_anim = true,
    animation = "none",
})

hl.layer_rule({
    name = "blurred_fade_layer",
    match = { namespace = "noon:blurred_fade_layer" },
    blur = blur,
    xray = true,
    ignore_alpha = layers_alpha,
    animation = "fade",
})

hl.layer_rule({
    name = "popup_layer",
    match = { namespace = "noon:popup_layer" },
    blur = blur,
    xray = true,
    ignore_alpha = layers_alpha,
    animation = "slide_" .. bar_location,
})

hl.layer_rule({
    name = "fade_layer",
    match = { namespace = "noon:fade_layer" },
    blur = false,
    ignore_alpha = layers_alpha,
    animation = "fade",
})
