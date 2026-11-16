hl.on("hyprland.start", function()
    local apps = {
        "systemctl --user --no-block start graphical-session.target",
        "noon -d -n",
        ipc .. " global trigger_autostart_apps",
        "dbus-update-activation-environment --systemd --all",
        "systemctl --user import-environment QT_QPA_PLATFORMTHEME",
        "systemctl --user restart xdg-desktop-portal xdg-desktop-portal-hyprland",
        "kdeconnectd",
        "foot --server",
        "kwalletd6",
        "gnome-keyring-daemon --start --components=secrets",
        "nm-applet",
        "wl-paste --watch cliphist store",
    }

    for _, cmd in ipairs(apps) do
        hl.exec_cmd(cmd)
    end
end)
