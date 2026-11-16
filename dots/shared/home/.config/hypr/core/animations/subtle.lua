local anim_direction = getAnimDirection()

hl.curve("quick", { type = "bezier", points = { { 0.1, 0 }, { 0.0, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 2 * animation_scale, bezier = "quick" })
hl.animation({ leaf = "windows", enabled = true, speed = 2 * animation_scale, bezier = "quick", style = "popin 90%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3 * animation_scale, bezier = "quick", style = anim_direction })
hl.animation({ leaf = "fade", enabled = false })
hl.animation({ leaf = "layers", enabled = false })
