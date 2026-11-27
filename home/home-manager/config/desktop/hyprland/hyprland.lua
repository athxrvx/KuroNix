-- Retained Hyprland configuration. Niri is the active desktop profile.
local home = os.getenv("HOME") or ""
local configDir = home .. "/.config/hypr"
local modulesDir = configDir .. "/conf.d"

local apps = {
    terminal = "kitty",
    fileManager = "nautilus",
    menu = "qs -c shell ipc call launcher toggle",
    barLayout = home .. "/.local/bin/bar-layout",
}

local function loadModule(name, ...)
    local configure = dofile(modulesDir .. "/" .. name .. ".lua")
    configure(...)
end

-- Apply categories in a deliberate order: outputs, environment, visual
-- behavior, startup, rules, then interactive bindings.
loadModule("monitor")
loadModule("environment", apps.terminal)
loadModule("layouts")
loadModule("animations")
loadModule("space")
loadModule("autostart", home)
loadModule("rules")
loadModule("keybinds", apps)
loadModule("media")
