-- Workspaces Switch
for i = 1, 10 do
    m_bind(i % 10, hl.dsp.focus({ workspace = i }))
end

-- Move active window to workspace
for i = 1, 10 do
    m_bind("+ALT+" .. i % 10,  hl.dsp.window.move({ workspace = i }))
end

-- Special workspace
m_bind("S", hl.dsp.workspace.toggle_special())
m_bind("ALT+S", hl.dsp.window.move({ workspace = "special" }))
m_bind("mouse:275", hl.dsp.workspace.toggle_special(), { mouse = true })

hl.bind("CTRL+" .. mainMod .. "+bracketleft", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("CTRL+" .. mainMod .. "+bracketright", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("CTRL+" .. mainMod .. "+up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("CTRL+" .. mainMod .. "+down", hl.dsp.focus({ workspace = "e+1" }))

m_bind("Page_Up", hl.dsp.focus({ workspace = "r-1" }))
m_bind("Page_Down", hl.dsp.focus({ workspace = "r+1" }))

hl.bind("CTRL+" .. mainMod .. "+ALT+right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("CTRL+" .. mainMod .. "+ALT+left", hl.dsp.focus({ workspace = "m-1" }))

hl.bind("CTRL+" .. mainMod .. "+Page_Down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("CTRL+" .. mainMod .. "+Page_Up", hl.dsp.focus({ workspace = "r-1" }))

m_bind("mouse_up", hl.dsp.focus({ workspace = "+1" }), { mouse = true })
m_bind("mouse_down", hl.dsp.focus({ workspace = "-1" }), { mouse = true })

hl.bind("CTRL+" .. mainMod .. "+mouse_up", hl.dsp.focus({ workspace = "r+1" }), { mouse = true })
hl.bind("CTRL+" .. mainMod .. "+mouse_down", hl.dsp.focus({ workspace = "r-1" }), { mouse = true })

---

m_bind("SHIFT+mouse_down", hl.dsp.window.move({ workspace = "r-1" }), { mouse = true })
m_bind("SHIFT+mouse_up", hl.dsp.window.move({ workspace = "r+1" }), { mouse = true })
m_bind("ALT+mouse_down", hl.dsp.window.move({ workspace = "-1" }), { mouse = true })
m_bind("ALT+mouse_up", hl.dsp.window.move({ workspace = "+1" }), { mouse = true })

m_bind("ALT+Page_Down", hl.dsp.window.move({ workspace = "+1" }))
m_bind("ALT+Page_Up", hl.dsp.window.move({ workspace = "-1" }))
m_bind("SHIFT+Page_Down", hl.dsp.window.move({ workspace = "r+1" }))
m_bind("SHIFT+Page_Up", hl.dsp.window.move({ workspace = "r-1" }))

m_bind("ALT+S", hl.dsp.window.move({ workspace = "special" }))

-- Windows
m_bind("G", hl.dsp.group.toggle())
m_bind("CTRL+TAB", hl.dsp.group.next())

m_bind("Q", hl.dsp.window.close())
m_bind("ALT+SPACE", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 1280, y = 800 }))
end)
-- Movement
m_bind("SHIFT+Right", hl.dsp.window.move({ direction = "right" }))
m_bind("SHIFT+Left", hl.dsp.window.move({ direction = "left" }))
m_bind("SHIFT+Up", hl.dsp.window.move({ direction = "up" }))
m_bind("SHIFT+Down", hl.dsp.window.move({ direction = "down" }))

-- Fullscreen / window state
m_bind("D", hl.dsp.window.fullscreen({ mode = "maximized" }))
m_bind("F", hl.dsp.window.fullscreen())
m_bind("ALT+F", hl.dsp.exec_cmd("hyprctl dispatch fullscreenstate 0 3"))

-- Focus
m_bind("right", hl.dsp.focus({ direction = "r" }))
m_bind("left", hl.dsp.focus({ direction = "l" }))
m_bind("up", hl.dsp.focus({ direction = "u" }))
m_bind("down", hl.dsp.focus({ direction = "d" }))

-- Mouse move/resize
m_bind("mouse:272", hl.dsp.window.drag(), { mouse = true })
m_bind("mouse:274", hl.dsp.window.drag(), { mouse = true })
m_bind("CTRL+mouse:272", hl.dsp.window.resize(), { mouse = true })

-- Layout: fine pixel scroll
m_bind("P", hl.dsp.window.pin())

-- Scrolling Layout Controls
if layout == "scrolling" then
    m_bind("BracketRight", hl.dsp.layout("move +col"))
    m_bind("BracketLeft", hl.dsp.layout("move -col"))
    m_bind("ALT+right", hl.dsp.layout("move +200"))
    m_bind("ALT+left", hl.dsp.layout("move -200"))
    m_bind("SHIFT+right", hl.dsp.layout("colresize +conf"))
    m_bind("SHIFT+left", hl.dsp.layout("colresize -conf"))
    m_bind("SHIFT+up", hl.dsp.layout("colresize +0.1"))
    m_bind("SHIFT+down", hl.dsp.layout("colresize -0.1"))
    hl.bind("CTRL+" .. mainMod .. "+right", hl.dsp.layout("swapcol r"))
    hl.bind("CTRL+" .. mainMod .. "+left", hl.dsp.layout("swapcol l"))
    hl.bind("CTRL+ALT+" .. mainMod .. "+equal", hl.dsp.layout("colresize all 0.5"))
    -- Layout: fit / scroll to position
    m_bind("Home", hl.dsp.layout("fit tobeg"))
    m_bind("End", hl.dsp.layout("fit toend"))
    m_bind("A", hl.dsp.layout("fit active"))
    m_bind("SHIFT+A", hl.dsp.layout("fit all"))
    hl.bind("CTRL+" .. mainMod .. "+A", hl.dsp.layout("fit visible"))
end

hl.bind("CTRL+SHIFT+" .. mainMod .. "+right", hl.dsp.layout("movecoltoworkspace +1"))
hl.bind("CTRL+SHIFT+" .. mainMod .. "+left", hl.dsp.layout("movecoltoworkspace -1"))

-- Screenshot area
m_bind("SHIFT+S", hl.dsp.exec_cmd(ipc .. " global toggle_screenshot"))

-- OCR
hl.bind(
    mainMod .. "+SHIFT+T",
    hl.dsp.exec_cmd('grim -g "$(slurp $SLURP_ARGS)" "tmp.png" && tesseract "tmp.png" - | wl-copy && rm "tmp.png"')
)

-- Color picker
m_bind("SHIFT+C", hl.dsp.exec_cmd("hyprpicker -a"))

-- Fullscreen screenshot
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true })
hl.bind(
    "CTRL+Print",
    hl.dsp.exec_cmd(
        "mkdir -p $(xdg-user-dir PICTURES)/Screenshots && grim $(xdg-user-dir PICTURES)/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"
    ),
    { locked = true }
)

-- Recording
m_bind("ALT+R", hl.dsp.exec_cmd(scriptsDir .. "/record_service.sh"))
hl.bind("CTRL+ALT+R", hl.dsp.exec_cmd(scriptsDir .. "/record_service.sh --fullscreen"))
m_bind("SHIFT+ALT+R", hl.dsp.exec_cmd(scriptsDir .. "/record_service.sh --fullscreen-sound"))

-- AI primary buffer query
hl.bind(
    mainMod .. "+SHIFT+ALT+mouse:273",
    hl.dsp.exec_cmd("~/.config/ags/scripts/ai/primary-buffer-query.sh"),
    { mouse = true }
)

-- Zoom
m_bind("minus", hl.dsp.exec_cmd(scriptsDir .. "/hypr_zoom.sh decrease 0.1"), { repeating = true })
m_bind("equal", hl.dsp.exec_cmd(scriptsDir .. "/hypr_zoom.sh increase 0.1"), { repeating = true })

-- Apps
m_bind("T", hl.dsp.exec_cmd(terminal))
m_bind("C", hl.dsp.exec_cmd(editor .. " " .. shell_path))
m_bind("Return", hl.dsp.exec_cmd(terminal_alt))
m_bind("E", hl.dsp.exec_cmd(file_manager))
m_bind("B", hl.dsp.exec_cmd(browser))
m_bind("SHIFT+B", hl.dsp.exec_cmd(browser_alt))
m_bind("SHIFT+L", hl.dsp.exec_cmd("sleep 0.1 && systemctl suspend || loginctl suspend"), { locked = true })

hl.bind("CTRL+" .. mainMod .. "+V", hl.dsp.exec_cmd("pavucontrol-qt"))
hl.bind("CTRL+SHIFT+Escape", hl.dsp.exec_cmd(task_manager))
hl.bind("CTRL+" .. mainMod .. "+SHIFT+Escape", hl.dsp.exec_cmd(task_manager_alt))
hl.bind("CTRL+SHIFT+ALT+" .. mainMod .. "+Delete", hl.dsp.exec_cmd("systemctl poweroff || loginctl poweroff"))
