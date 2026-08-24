-- Hacks
m_bind("Super_L", hl.dsp.global("noon:superHeld"))
m_bind("CTRL+R", reload_shell())
m_bind("CTRL+Period", hl.dsp.exec_cmd("wl-paste -p | xargs -0 " .. ipc .. " noon translate"))
m_bind("L", hl.dsp.exec_cmd(ipc .. " global lock"))
m_bind("SHIFT+R", hl.dsp.exec_cmd(ipc .. " global pick_random_wall"))
m_bind("ALT+D", hl.dsp.exec_cmd(ipc .. " global toggle_dormant_state"))

-- Media
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(ipc .. " global toggle_playing"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(ipc .. " global previous_track || playerctl previous"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(ipc .. " global next_track || playerctl next"))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(ipc .. " global pause_all_players"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(ipc .. " global volume_up"), { locked = false })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(ipc .. " global volume_down"), { locked = false })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true })

-- Brightness
hl.bind(
    "XF86MonBrightnessUp",
    hl.dsp.exec_cmd(ipc .. " global inc_brightness || brightnessctl set +5%"),
    { repeating = true, locked = true }
)
hl.bind(
    "XF86MonBrightnessDown",
    hl.dsp.exec_cmd(ipc .. " global dec_brightness || brightnessctl set 5%-"),
    { repeating = true, locked = true }
)

-- IPC
local beam_actions = {
    shot = "SHIFT+S",
    music = "ALT+M",
    weather = "ALT+W",
    hints = "ALT+Slash",
    appearance = "S",
}

local sidebar_actions = {
    Apps = "Space",
    Walls = "W",
    View = "CTRL+Tab",
    Downloads = "J",
    Beats = "M",
    API = "A",
    Sounds = "grave",
    Widgets = "Tab",
    Shelf = "Z",
    Tweaks = "I",
    Notifs = "N",
    Bookmarks = "ALT+B",
    Web = "ALT+W",
    Plugins = "P",
    Tasks = "CTRL+T",
    Notes = "CTRL+N",
    Games = "CTRL+G",
    Session = "Escape"
}

local noon_actions = {
    toggle_zen = "CTRL+SHIFT+X",
    toggle_beam = "Super_L",
    toggle_bar_mode = "CTRL+X",
    toggle_history = "V",
    toggle_emoji = "Period",
    swap_bar_position = "ALT+X",
    toggle_dock_pin = "ALT+P"
}

local nobuntu_actions = {
    toggle_overview = "Super_L",
    toggle_notifs = "N",
    toggle_db = "comma",
    toggle_clipboard = "V"
}

local xp_actions = {
    toggle_run = "R",
    toggle_start_menu = "Super_L"
}

loop_ipc(xp_actions, "xp", "")
loop_ipc(nobuntu_actions, "nobuntu", "")

loop_ipc(noon_actions, "noon", "")
loop_ipc(beam_actions, "noon reveal_beam ", "")
loop_ipc(sidebar_actions, "sidebar reveal", "")
loop_ipc(sidebar_actions, "sidebar reveal_aux", "SHIFT")
