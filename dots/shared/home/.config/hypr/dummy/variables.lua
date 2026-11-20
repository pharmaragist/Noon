-- Global Settings & Paths
home = os.getenv("HOME")
shell_path = home .. "/.config/noon"
scriptsDir = shell_path .. "/scripts"
shell_cmd = "qs -c " .. shell_path
ipc = scriptsDir .. "/bin/npc call "
mainMod = "SUPER"

-- Apps
terminal = "kitty"
terminal_alt = "kitty"
terminal_opacity = 1
browser = "firefox"
browser_alt = "firefox"
editor = "zed"
file_manager = "dolphin"
task_manager = ipc .. "sidebar reveal TaskManager"
task_manager_alt = terminal .. ' fish -c "nvtop"'

-- Decoration & Layout
blur = false
compiz = false
unblur_apps = true
blur_size = 0
blur_passes = 0
noise = 0
xray = true
ignore_opacity = false
new_optimizations = false
allow_tearing = false
shadows = false
shadows_power = 0
shadows_range = 0
gaps_in = 0
gaps_out = 0
gaps_special = 0
borders = 0
rounding = 0
rounding_power = 2
layers_alpha = 1
applications_opacity = 1
hypr_col_alpha = 0
font_main = "Open Sans"
layout = "master"
vertical = true
debug_overlay = false
cursor_theme = "MacOS-Tahoe-Cursor"
cursor_size = 25
animation_style = "standard"
animation_scale = 0.85
animation_mode = "slidevert"
direction = vertical and "vertical" or "horizontal"
external_monitor_mode = "1920x1080@75"
float_apps = false
bar_location = "left"
bar_width = 52

-- Monitors
active_monitor = hl.get_active_monitor()
m_width = active_monitor and active_monitor.width or 1920
m_height = active_monitor and active_monitor.height or 1080
