-- Global Application Rule
hl.window_rule({
    name = "windowrule-1",
    match = { class = "^(.*)" },
    no_blur = unblur_apps,
    opacity = applications_opacity,
})
hl.window_rule({
    name = "terminal_blur",
    match = { class = "^(kitty*|foot*|ghostty*)" },
    no_blur = not (terminal_opacity < 1),
})
hl.window_rule({
    name = "browser",
    match = { class = "^(firefox*)" },
    workspace = "2",
})
hl.window_rule({
    name = "editor",
    match = { class = "^(dev.zed.Zed*)" },
    workspace = "1",
})

hl.window_rule(
    set_app_as_side_panel("380 99999", {
        name = "telegram",
        direction = bar_position,
        match = { class = "org.telegram.desktop" },
    })
)

hl.window_rule(
    set_app_as_side_panel("380 99999", {
        name = "localsend",
        direction = bar_position,
        match = { class = "localsend" },
    })
)


-- Common Floating Rules
local apps_cfg = {
    { class = "org.kde.kclock.*",                         size = "50% 55%" },
    { class = "hyprland-share-picker.*",                  size = "25% 40%", center = true },
    { class = "kcm_.*" },
    { class = ".*plasmawindowed.*" },
    { class = ".*org.kde.kdeconnect.daemon.*" },
    { class = "blueberry\\.py" },
    { class = "guifetch" },
    { class = "vlc" },
    { title = "satty",                                    size = "65% 65%" },
    { class = "kvantummanager" },
    { class = "qt[56]ct" },
    { class = "nwg-look" },
    { class = "org.kde.ark" },
    { class = "blueman-manager" },
    { class = "nm-applet" },
    { class = "org.kde.polkit-kde-authentication-agent-1" },
    { class = "pavucontrol-qt",                           size = "60% 65%", center = true },
    { class = "nm-connection-editor",                     size = "45% 37%", center = true },
}

for _, cfg in ipairs(apps_cfg) do
    local match_criteria = {}

    if cfg.class then
        if cfg.class:match("^%^") or cfg.class:match("%$$") then
            match_criteria.class = cfg.class
        else
            match_criteria.class = "^(" .. cfg.class .. ")$"
        end
    end

    if cfg.title then
        if cfg.title:match("^%^") or cfg.title:match("%$$") then
            match_criteria.title = cfg.title
        else
            match_criteria.title = "^(" .. cfg.title .. ")$"
        end
    end

    hl.window_rule({
        match = match_criteria,
        float = true,
        size = cfg.size,
        center = cfg.center,
        move = cfg.move,

    })
end

-- Hidden/Offscreen utility windows
hl.window_rule({
    match = { class = "^(plasma-changeicons)$" },
    float = true,
    no_initial_focus = true,
    move = "999999 999999",
})
hl.window_rule({
    match = { class = "klook" },
    float = true,
    no_initial_focus = true,
})

-- Picture-in-Picture logic (calculated move)
hl.window_rule({
    name = "pip",
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    size = "25% 25%",
    move = math.floor(m_width * 0.73) .. " " .. math.floor(m_height * 0.72),
})

-- Specific Logic for Games/Steam
hl.window_rule({
    name = "games",
    match = { title = ".*\\.exe" },
    immediate = true,
    fullscreen_state = 2,
})

-- Layers
local layers = {
    {
        name = "global_layers",
        namespace = "noon.*",
        xray = false,
        blur = false,
        ignore_alpha = layers_alpha,
    },
    {
        name = "noanim_blurred_layer",
        namespace = "noon:noanim_blurred_layer",
        blur = true,
        no_anim = true,
    },
    {
        name = "blurred_layer",
        namespace = "noon:blurred_layer",
        blur = blur,
        xray = xray
    },
    {
        name = "unblurred_layer",
        namespace = "noon:unblurred_layer",
        blur = false,
    },
    {
        name = "dialog_panel",
        namespace = "noon:dialog_panel",
        blur = blur,
        xray = xray,
        ignore_alpha = 0.7,
    },
    {
        name = "bar",
        namespace = "noon:bar",
        xray = true,
        blur = true,
        animation = "slide"
    },
    {
        name = "noanim_layer",
        namespace = "noon:noanim_layer",
        animation = "none",
        blur = false
    },
    {
        name = "bottom_slide_layer",
        namespace = "noon:bottom_slide_layer",
        animation = "slide",
    },
    {
        name = "slide_layer",
        namespace = "noon:slide_layer",
        animation = "slide",
    },
    {
        name = "slide_dim_layer",
        namespace = "noon:slide_dim_layer",
        dim_around = true,
        animation = "slide",
    },
    {
        name = "blurred_fade_layer",
        namespace = "noon:blurred_fade_layer",
        animation = "fade",
        blur = true
    },
    {
        name = "unblurred_fade_layer",
        namespace = "noon:unblurred_fade_layer",
        animation = "fade",
        blur = false
    },
    {
        name = "nobuntu",
        namespace = "nobuntu.*",
        ignore_alpha = layers_alpha,
        blur = true,
        xray = true,
    }
}

for _, layer in ipairs(layers) do
    hl.layer_rule({
        name = layer.name,
        blur = layer.blur,
        xray = layer.xray,
        ignore_alpha = layer.ignore_alpha,
        no_anim = layer.no_anim,
        animation = layer.animation,
        dim_around = layer.dim_around,
        match = { namespace = layer.namespace },
    })
end
