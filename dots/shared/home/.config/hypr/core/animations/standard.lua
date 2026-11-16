-- Custom vars: multiply every speed by animation_scale, and use anim_direction as the style for all workspace leaves.
-- Setup: define each curve once at the top (beziers named by shape, springs by feel) and reuse it by name.
-- Per-surface styles for floating windows and layers live in the window and layer rules file, not here.

local anim_direction = getAnimDirection()

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeOutExpo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.1, 0 }, { 0.0, 1 } } })

hl.curve("pop", { type = "spring", mass = 1, stiffness = 450, dampening = 20 })
hl.curve("snappy", { type = "spring", mass = 1, stiffness = 500, dampening = 32 })
hl.curve("glide", { type = "spring", mass = 1, stiffness = 380, dampening = 28 })

hl.animation({ leaf = "global", enabled = true, speed = 8 * animation_scale, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5 * animation_scale, bezier = "easeOutQuint" })

hl.animation({ leaf = "windows", enabled = true, speed = 10 * animation_scale, spring = "pop", style = "popin 70%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 10 * animation_scale, spring = "pop", style = "popin 70%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 10 * animation_scale, spring = "snappy", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 10 * animation_scale, spring = "snappy" })

hl.animation({ leaf = "fade", enabled = true, speed = 3 * animation_scale, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2 * animation_scale, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.5 * animation_scale, bezier = "almostLinear" })

hl.animation({ leaf = "layers", enabled = true, speed = 4 * animation_scale, bezier = "easeOutExpo" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4.5 * animation_scale, bezier = "easeOutExpo", style = "slide bottom" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3 * animation_scale, bezier = "quick", style = "slide bottom" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2 * animation_scale, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.4 * animation_scale, bezier = "almostLinear" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 12 * animation_scale, spring = "glide", style = anim_direction })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 12 * animation_scale, spring = "glide", style = anim_direction })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 12 * animation_scale, spring = "glide", style = anim_direction })

hl.animation({ leaf = "zoomFactor", enabled = true, speed = 8 * animation_scale, bezier = "quick" })
