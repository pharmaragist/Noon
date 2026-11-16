-- Global Settings & Paths
home = os.getenv("HOME")
shell_path = home .. "/.config/noon"
scriptsDir = shell_path .. "/scripts"
shell_cmd = "qs -c " .. shell_path
ipc = scriptsDir .. "/npc call "
mainMod = "SUPER"

-- Apps
terminal = "kitty"
terminal_alt = "foot"
terminal_opacity = 0.75
browser = "firefox"
browser_alt = "hellium"
editor = "zed"
file_manager = "dolphin"
task_manager = ipc .. "sidebar reveal TaskManager"
task_manager_alt = terminal .. ' fish -c "nvtop"'

-- Decoration & Layout
blur = true
compiz = false
unblur_apps = true
blur_size = 2
blur_passes = 4
noise = 0
xray = true
ignore_opacity = false
new_optimizations = true
allow_tearing = false
shadows = true
shadows_power = 3
shadows_range = 35
gaps_in = 2
gaps_out = 7
gaps_special = 40
borders = 0
rounding = 24
rounding_power = 2
layers_alpha = 0.6
applications_opacity = 1
hypr_col_alpha = 50
font_main = "Google Sans Flex 120pt"
layout = "master"
vertical = true
debug_overlay = false
cursor_theme = "LiOSV"
cursor_size = 22
animation_style = "standard"
animation_scale = 1
animation_mode = "slidevert"
direction = vertical and "vertical" or "horizontal"
external_monitor_mode = "1920x1080@75"
float_apps = false
bar_location = "left"
bar_width = 44

-- Monitors
active_monitor = hl.get_active_monitor()
m_width = active_monitor and active_monitor.width or 1920
m_height = active_monitor and active_monitor.height or 1080
