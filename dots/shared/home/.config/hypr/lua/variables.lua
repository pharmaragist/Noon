-- Global Settings & Paths
home = os.getenv("HOME")
shell_path = home .. "/.config/noon"
scriptsDir = shell_path .. "/scripts"
shell_cmd = "qs -c " .. shell_path
ipc = shell_cmd .. " ipc call "
mainMod = "SUPER"

-- Apps
terminal = "kitty"
terminal_alt = "foot"
terminal_opacity = 1
browser = "firefox"
browser_alt = "firefox"
editor = "zed"
file_manager = "dolphin"
task_manager = ipc .. "sidebar reveal TaskManager"
task_manager_alt = terminal .. ' fish -c "nvtop"'

-- Decoration & Layout
blur = true
unblur_apps = true
blur_size = 2
blur_passes = 3
noise = 4
xray = true
ignore_opacity = true
new_optimizations = true
shadows = true
shadows_power = 4
shadows_range = 30
gaps_in = 5
gaps_out = 5
gaps_special = 40
borders = 1
rounding = 20
rounding_power = 2
layers_alpha = 0.4
applications_opacity = 1
hypr_col_alpha = 50
font_main = "Google Sans Flex"
layout = "master"
vertical = true
debug_overlay = false
cursor_theme = "GoogleDot-White"
cursor_size = 24
animation_style = "springs"
animation_scale = 0.5
animation_mode = "slidevert"
direction = vertical and "vertical" or "horizontal"
external_monitor_mode = "1920x1080@75"
float_apps = false
bar_location = "right"
bar_width = 50
-- Monitors
active_monitor = hl.get_active_monitor()
m_width = active_monitor and active_monitor.width or 1920
m_height = active_monitor and active_monitor.height or 1080
