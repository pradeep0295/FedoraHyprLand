-- An empty output name creates a fallback rule for all unspecified displays.
-- Hyprland chooses preferred modes and automatically places connected monitors.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})