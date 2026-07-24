function getAnimDirection()
    return vertical and "slidevert" or "slide"
end

function m_bind(key,action)
    return hl.bind(mainMod .. '+' .. key, action)
end

function reload_shell()
    return hl.dsp.exec_cmd(scriptsDir .. "/reload_shell.sh")
end

function loop_ipc(tuple, prefix, mod)
    for cat, key in pairs(tuple) do
        hl.bind(mainMod .. '+'  .. mod .. '+' .. key, hl.dsp.exec_cmd(ipc .. ' ' .. prefix .. ' ' .. cat), { locked = true })
    end
end

function set_app_as_side_panel(params, config)
    local result = config or {}
    local width, height = string.match(params, "(%d+)%s+(%d+)")
    width = tonumber(width)
    height = tonumber(height)

    local direction = result.direction or bar_location or "left"
    result.direction = nil

    local avail_height = m_height - gaps_out * 2
    if height > avail_height then height = avail_height end

    local y_pos = gaps_out + math.floor((avail_height - height) / 2)
    local x_pos

    if direction == "top" or direction == "bottom" then
        direction = "left"
    end

    if direction == "left" then
        x_pos = gaps_out + bar_width * 2 + gaps_out
    elseif direction == "right" then
        x_pos = m_width - gaps_out - bar_width * 2 - gaps_out - width
    end

    result.float = true
    result.size  = width .. " " .. height
    result.move  = x_pos .. " " .. y_pos
    return result
end

function toast(text)
    hl.dsp.exec_cmd(ipc .. " global toast Hyprland " .. text)
end

function notify(text)
    hl.dsp.exec_cmd("notify-send hyprland " .. text)
end

function toggle_float()
    hl.dsp.window.float({ mode = (mode == "float") and "tile" or "float" })
end

function mission_control()
    hl.dsp.global("hymission:toggle")
end

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name           = "suppress-maximize-events",
    match          = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name     = "fix-xwayland-drags",
    match    = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})
