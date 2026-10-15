local OUTER_GAP = { top = 100, right = 100, bottom = 100, left = 100 }
local INNER_GAP = 25
local MIN_TILE_W = 280
local MIN_TILE_H = 100
local ALLOW_UPSCALE = true
local CENTER_LAST_ROW = false
local CLICK_FOCUSED_TILE = true
local RELAYOUT_DELAY_MS = 80
local SETTLE_DELAY_MS = 120
local FILL_CELLS = true

local active = false
local saved = {}
local saved_order = {}
local saved_follow_mouse = nil
local placements = {}
local last_area = nil

local function clamp(v, lo, hi)
    if hi < lo then
        return lo
    end
    return math.max(lo, math.min(v, hi))
end

local function parse_sides(gap)
    if type(gap) == "number" then
        return { top = gap, right = gap, bottom = gap, left = gap }
    end
    return {
        top = gap.top or gap[1] or 0,
        right = gap.right or gap[2] or 0,
        bottom = gap.bottom or gap[3] or 0,
        left = gap.left or gap[4] or 0,
    }
end


local function read_follow_mouse()
    local ok, value = pcall(hl.get_config, "input:follow_mouse")
    if not ok then
        return 1
    end
    if type(value) == "table" then
        value = value.value or value.int or value[1]
    end
    return tonumber(value) or 1
end

local function set_follow_mouse(value)
    pcall(hl.config, { input = { follow_mouse = value } })
end

local function monitor_work_area(m)
    if not m then
        return nil
    end
    local r = m.reserved or {}
    local left = tonumber(r.left) or 0
    local top = tonumber(r.top) or 0
    local right = tonumber(r.right) or 0
    local bottom = tonumber(r.bottom) or 0
    local gap = parse_sides(OUTER_GAP)

    local area = {
        x = m.x + left + gap.left,
        y = m.y + top + gap.top,
        w = m.width - left - right - gap.left - gap.right,
        h = m.height - top - bottom - gap.top - gap.bottom,
    }
    if area.w <= 0 or area.h <= 0 then
        return nil
    end
    return area
end

local function targets()
    local ws = hl.get_active_workspace()
    local list = {}
    if not ws then
        return list
    end
    for _, w in ipairs(hl.get_windows() or {}) do
        local wws = w.workspace
        if w.mapped and not w.hidden and not w.pinned
            and wws and wws.id == ws.id and not wws.special then
            list[#list + 1] = w
        end
    end
    return list
end

local function snapshot(w)
    return {
        address = w.address,
        was_tiled = not w.floating,
        fs = w.fullscreen or 0,
        fsc = w.fullscreen_client or 0,
        x = (w.at and w.at.x) or 0,
        y = (w.at and w.at.y) or 0,
        w = (w.size and w.size.x) or 0,
        h = (w.size and w.size.y) or 0,
    }
end

local function fit_scale(w, tw, th)
    local s = saved[w.address]
    local ow = (s and s.w > 0) and s.w or (w.size and w.size.x) or tw
    local oh = (s and s.h > 0) and s.h or (w.size and w.size.y) or th
    local scale = math.min(tw / ow, th / oh)
    if not ALLOW_UPSCALE then
        scale = math.min(1, scale)
    end
    return scale, ow, oh
end

local function choose_grid(list, area)
    local n = #list
    local best
    for cols = 1, n do
        local rows = math.ceil(n / cols)
        local tw = (area.w - INNER_GAP * (cols - 1)) / cols
        local th = (area.h - INNER_GAP * (rows - 1)) / rows
        if tw >= MIN_TILE_W and th >= MIN_TILE_H then
            local score = 0
            if FILL_CELLS then
                score = tw * th * n
            else
                for _, w in ipairs(list) do
                    local scale, ow, oh = fit_scale(w, tw, th)
                    score = score + (ow * scale) * (oh * scale)
                end
            end
            if not best or score > best.score then
                best = { cols = cols, rows = rows, tw = tw, th = th, score = score }
            end
        end
    end
    if not best then
        local cols = clamp(math.ceil(math.sqrt(n * area.w / area.h)), 1, n)
        local rows = math.ceil(n / cols)
        best = {
            cols = cols,
            rows = rows,
            tw = (area.w - INNER_GAP * (cols - 1)) / cols,
            th = (area.h - INNER_GAP * (rows - 1)) / rows,
        }
    end
    return best
end

local function place(w, s, cx, cy, tw, th, area)
    local sel = "address:" .. w.address

    if s.fs ~= 0 or s.fsc ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen_state({ window = sel, internal = 0, client = 0 }))
    end
    if s.was_tiled then
        hl.dispatch(hl.dsp.window.float({ window = sel, action = "set" }))
    end

    local ww, hh
    if FILL_CELLS then
        ww = math.max(1, math.floor(tw))
        hh = math.max(1, math.floor(th))
    else
        local scale, ow, oh = fit_scale(w, tw, th)
        ww = math.max(1, math.floor(ow * scale))
        hh = math.max(1, math.floor(oh * scale))
    end

    local x = clamp(math.floor(cx + (tw - ww) / 2), area.x, area.x + area.w - ww)
    local y = clamp(math.floor(cy + (th - hh) / 2), area.y, area.y + area.h - hh)

    hl.dispatch(hl.dsp.window.resize({ window = sel, x = ww, y = hh }))
    hl.dispatch(hl.dsp.window.move({ window = sel, x = x, y = y }))
end

local function restore(w, s)
    local sel = "address:" .. w.address
    if s.was_tiled then
        hl.dispatch(hl.dsp.window.float({ window = sel, action = "unset" }))
    else
        hl.dispatch(hl.dsp.window.resize({ window = sel, x = s.w, y = s.h }))
        hl.dispatch(hl.dsp.window.move({ window = sel, x = s.x, y = s.y }))
    end
    if s.fs ~= 0 or s.fsc ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen_state({ window = sel, internal = s.fs, client = s.fsc }))
    end
end

local function settle()
    if not active or not last_area then
        return
    end
    local area = last_area
    local present = {}
    for _, w in ipairs(hl.get_windows() or {}) do
        present[w.address] = w
    end
    for addr, p in pairs(placements) do
        local w = present[addr]
        if w and w.size and w.at then
            local aw = w.size.x
            local ah = w.size.y
            local x = clamp(math.floor(p.cx + (p.tw - aw) / 2), area.x, area.x + area.w - aw)
            local y = clamp(math.floor(p.cy + (p.th - ah) / 2), area.y, area.y + area.h - ah)
            if math.abs(x - w.at.x) > 1 or math.abs(y - w.at.y) > 1 then
                hl.dispatch(hl.dsp.window.move({ window = "address:" .. addr, x = x, y = y }))
            end
        end
    end
end

local function layout()
    local present = {}
    for _, w in ipairs(hl.get_windows() or {}) do
        present[w.address] = true
    end
    for addr in pairs(saved) do
        if not present[addr] then
            saved[addr] = nil
        end
    end
    local kept = {}
    for _, addr in ipairs(saved_order) do
        if present[addr] then
            kept[#kept + 1] = addr
        end
    end
    saved_order = kept

    local area = monitor_work_area(hl.get_active_monitor() or hl.get_monitor_at_cursor())
    local list = targets()
    if not area or #list == 0 then
        return false
    end

    for _, w in ipairs(list) do
        if not saved[w.address] then
            saved[w.address] = snapshot(w)
            saved_order[#saved_order + 1] = w.address
        end
    end

    local n = #list
    local g = choose_grid(list, area)
    placements = {}
    last_area = area
    for i, w in ipairs(list) do
        local col = (i - 1) % g.cols
        local row = math.floor((i - 1) / g.cols)
        local offset = 0
        if CENTER_LAST_ROW then
            local in_row = math.min(g.cols, n - row * g.cols)
            offset = (g.cols - in_row) * (g.tw + INNER_GAP) / 2
        end
        local cx = area.x + offset + col * (g.tw + INNER_GAP)
        local cy = area.y + row * (g.th + INNER_GAP)
        placements[w.address] = { cx = cx, cy = cy, tw = g.tw, th = g.th }
        place(w, saved[w.address], cx, cy, g.tw, g.th, area)
    end
    hl.timer(settle, { timeout = SETTLE_DELAY_MS, type = "oneshot" })
    return true
end

local function exit()
    if not active then
        return
    end
    active = false

    local present = {}
    for _, w in ipairs(hl.get_windows() or {}) do
        present[w.address] = w
    end
    for i = 1, #saved_order do
        local addr = saved_order[i]
        local w = present[addr]
        if w and saved[addr] then
            restore(w, saved[addr])
        end
    end
    saved = {}
    saved_order = {}

    set_follow_mouse(saved_follow_mouse or 1)
    saved_follow_mouse = nil
end

local function enter()
    if active then
        return
    end
    saved = {}
    saved_order = {}
    saved_follow_mouse = read_follow_mouse()
    set_follow_mouse(0)
    active = true
    if not layout() then
        active = false
        saved = {}
        saved_order = {}
        set_follow_mouse(saved_follow_mouse)
        saved_follow_mouse = nil
    end
end

local function refresh()
    if active and not layout() then
        exit()
    end
end

local function select_window(addr)
    if not addr or not saved[addr] then
        return
    end
    exit()
    local sel = "address:" .. addr
    pcall(function()
        hl.dispatch(hl.dsp.focus({ window = sel }))
    end)
    hl.dispatch(hl.dsp.window.fullscreen_state({
        window = sel,
        internal = 1,
        client = 1,
    }))
end

local function window_at_cursor()
    local ok, pos = pcall(hl.get_cursor_pos)
    if not ok or type(pos) ~= "table" then
        return nil
    end
    local px = tonumber(pos.x or pos[1])
    local py = tonumber(pos.y or pos[2])
    if not px or not py then
        return nil
    end
    for _, w in ipairs(targets()) do
        local ax = (w.at and w.at.x) or 0
        local ay = (w.at and w.at.y) or 0
        local aw = (w.size and w.size.x) or 0
        local ah = (w.size and w.size.y) or 0
        if px >= ax and px <= ax + aw and py >= ay and py <= ay + ah then
            return w.address
        end
    end
    return nil
end

function overview_toggle()
    if active then
        exit()
    else
        enter()
    end
end

hl.bind("SUPER + Tab", overview_toggle)

if CLICK_FOCUSED_TILE then
    pcall(hl.bind, "mouse:272", function()
        if active then
            select_window(window_at_cursor())
        end
    end, { non_consuming = true })
end

hl.on("window.close", refresh)
hl.on("window.destroy", refresh)
hl.on("window.open", function()
    if not active then
        return
    end
    hl.timer(refresh, { timeout = RELAYOUT_DELAY_MS, type = "oneshot" })
end)

hl.on("window.active", function(e)
    if not active then
        return
    end
    local addr = (type(e) == "table" and e.address) or (type(e) == "string" and e) or nil
    if not addr then
        local w = hl.get_active_window()
        addr = w and w.address
    end
    select_window(addr)
end)

hl.on("window.move_to_workspace", function()
    if active then
        exit()
    end
end)

hl.on("workspace.active", function()
    if active then
        exit()
    end
end)
