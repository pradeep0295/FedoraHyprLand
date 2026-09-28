-- Rich window styling with restrained blur so Noctalia remains legible.
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 12,
        border_size = 2,
        resize_on_border = true,
        extend_border_grab_area = 12,
    },
    decoration = {
        rounding = 12,
        active_opacity = 1.0,
        inactive_opacity = 0.97,
        fullscreen_opacity = 1.0,
        blur = {
            enabled = true,
            size = 7,
            passes = 2,
            new_optimizations = true,
            xray = false,
        },
        shadow = {
            enabled = true,
            range = 12,
            render_power = 2,
            color = 0x47000000,
        },
    },
})