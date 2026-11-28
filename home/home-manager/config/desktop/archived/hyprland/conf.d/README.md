# Hyprland Lua config

`hyprland.lua` loads Kuro first, then runs these modules in order:

- `monitor.lua`: output defaults
- `environment.lua`: cursor, terminal and Qt environment
- `animations.lua`: curves, animations and workspace gesture
- `autostart.lua`: session processes
- `rules.lua`: Quickshell layer and window rules
- `keybinds.lua`: window, launcher and workspace shortcuts
- `media.lua`: volume, microphone, brightness and player controls

This retained profile uses its own static appearance and input settings. The
active Niri profile receives generated colors from Kuro Engine.
