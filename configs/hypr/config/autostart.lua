-- Start Noctalia from the UWSM-managed Hyprland session.
hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia --daemon")
end)