-- Steam Deck Hardware Profile for Hyprland (Lua)
-- Handles rotation for Steam Deck LCD (transform 3) and OLED (transform 1)
local deck_transform = 3
local product_name_file = io.open("/sys/devices/virtual/dmi/id/product_name", "r")
if product_name_file then
    local p = product_name_file:read("*a") or ""
    product_name_file:close()
    if p:find("Galileo") then
        deck_transform = 1
    end
end

hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "0x0",
    scale = "1",
    transform = deck_transform,
})

hl.config({
    input = {
        touchdevice = {
            transform = deck_transform,
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
        "SUPER, SPACE, exec, hype ipc call launcher toggle",
        ", XF86Search, exec, hype ipc call anvil toggle",
        "SUPER ALT, A, exec, hype ipc call anvil toggle",
        "SUPER, X, exec, hype ipc call keyboard toggle",
        "SUPER, K, exec, hype ipc call keyboard toggle"
    }
})
