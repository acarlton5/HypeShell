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

-- Check if an external monitor is currently connected
local function has_external_display()
    local p = io.popen("for s in /sys/class/drm/card*-DP-*/status /sys/class/drm/card*-HDMI-*/status; do [ -f \"$s\" ] && grep -q '^connected' \"$s\" 2>/dev/null && echo 'yes' && exit 0; done; echo 'no'")
    if p then
        local res = p:read("*l") or "no"
        p:close()
        return res:find("yes") ~= nil
    end
    return false
end

local function update_displays()
    if has_external_display() then
        hl.monitor({
            output = "eDP-1",
            disabled = true,
        })
    else
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
                }
            }
        })
    end
end

-- Apply initial monitor configuration based on whether external screen is plugged in
update_displays()

-- Listen to monitor plug / unplug events to automatically toggle eDP-1
hl.on("monitor.added", function()
    update_displays()
end)

hl.on("monitor.removed", function()
    update_displays()
end)

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
