-- Smooth curves and workspace/window motion, including a little overshoot.
hl.curve("smooth", {
    type = "bezier",
    points = { { 0.05, 0.9 }, { 0.1, 1.05 } },
})

hl.animation({ leaf = "global", enabled = true, speed = 1, bezier = "smooth" })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "smooth", style = "popin" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "smooth" })
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "smooth" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "smooth", style = "slide" })