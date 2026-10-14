hl.config({
    monitor = {
        "eDP-1, 1280x800@60, 0x0, 1, transform, 3"
    },
    input = {
        touchdevice = {
            transform = 3,
            output = "eDP-1"
        },
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            clickfinger_behavior = true
        }
    },
    bindl = {
        ", XF86PowerOff, exec, hype ipc call lock lock"
    },
    bind = {
        ", XF86Shop, exec, hype ipc call launcher toggle",
        "SUPER, SPACE, exec, hype ipc call launcher toggle"
    }
})
