{ config, pkgs, ... }:
let
  qs = "${pkgs.quickshell}/bin/qs";
in
{
  xdg.configFile."niri/config.kdl".text = ''
    // Kuro: Niri scrollable tiling desktop.
    // Kuro Shell is installed by Home Manager and controlled through its IPC.

    prefer-no-csd

    input {
        mod-key "Super"
        keyboard {
            xkb {
                layout "us"
                options "altwin:swap_alt_win"
            }
        }
        touchpad {
            tap
            dwt
            natural-scroll
        }
    }

    layout {
        gaps 8
        focus-ring {
            active-color "#8a694c"
            inactive-color "#88888888"
        }
        center-focused-column "never"
        preset-column-widths {
            proportion 0.5
            proportion 0.75
            proportion 1.0
        }
        default-column-width { proportion 0.5; }
    }

    window-rule {
        geometry-corner-radius 15
        clip-to-geometry true
    }

    // Keep Kuro Shell companion windows centered and floating.
    window-rule {
        match title="^Music$"
        open-floating true
    }

    // Reuse Kuro Shell's pre-blurred wallpaper as Niri's overview backdrop.
    layer-rule {
        match namespace="^quickshell:Backdrop$"
        place-within-backdrop true
    }

    overview {
        backdrop-color "#0d0d0d"
    }

    hotkey-overlay {
        skip-at-startup
    }

    spawn-at-startup "xwayland-satellite"
    spawn-at-startup "${pkgs.bash}/bin/bash" "-lc" "${pkgs.systemd}/bin/systemctl --user import-environment PATH WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP && ${pkgs.systemd}/bin/systemctl --user start kuro-shell.service kuro-idle.service cliphist-watch-text.service cliphist-watch-image.service"

    binds {
        // Apps
        Super+Shift+Return { spawn "${pkgs.kitty}/bin/kitty"; }
        Super+Return { spawn "${pkgs.kitty}/bin/kitty"; }
        Super+E { spawn "${pkgs.nautilus}/bin/nautilus"; }
        Super+Shift+W { spawn "${qs}" "-c" "shell" "ipc" "call" "webApps" "toggleCreator"; }
        Super+Space { spawn "${qs}" "-c" "shell" "ipc" "call" "drawers" "toggle" "launcher"; }
        Super+Shift+Period { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "actions"; }
        Super+Comma { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "emoji"; }
        Ctrl+Super+Comma { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "settings"; }
        Ctrl+Super+C { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "calc"; }
        Ctrl+Super+T { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "scheme"; }
        Ctrl+Super+P { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "wallpaper"; }
        Ctrl+Super+V { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "clip"; }
        Ctrl+Super+G { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "web"; }
        Ctrl+Super+E { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "emoji"; }
        Ctrl+Super+D { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "distrobox"; }
        Ctrl+Super+O { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "ocr"; }
        Ctrl+Super+R { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "random"; }
        Super+Alt+J { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "light"; }
        Super+Alt+K { spawn "${qs}" "-c" "shell" "ipc" "call" "launcher" "utility" "dark"; }
        Super+S { spawn "${qs}" "-c" "shell" "ipc" "call" "controlCenter" "open"; }
        Super+Shift+Space { spawn "${qs}" "-c" "shell" "ipc" "call" "quicktoggles" "toggle"; }
        Super+V { spawn "${qs}" "-c" "shell" "ipc" "call" "clipboard" "toggle"; }
        Super+Shift+S { spawn "${qs}" "-c" "shell" "ipc" "call" "picker" "open"; }
        Ctrl+Super+Delete { spawn "${qs}" "-c" "shell" "ipc" "call" "drawers" "toggle" "session"; }
        Super+Tab { toggle-overview; }
        Super+Q { close-window; }
        Super+Shift+E { quit; }
        Super+W { toggle-window-floating; }
        Super+Shift+Slash { show-hotkey-overlay; }

        // Focus and move around the scrollable layout
        Super+Left { focus-column-left; }
        Super+Right { focus-column-right; }
        Super+Down { focus-window-down; }
        Super+Up { focus-window-up; }
        Super+H { focus-column-left; }
        Super+L { focus-column-right; }
        Super+J { focus-window-down; }
        Super+K { focus-window-up; }
        Super+Shift+Left { move-column-left; }
        Super+Shift+Right { move-column-right; }
        Super+Shift+H { move-column-left; }
        Super+Shift+J { move-window-down; }
        Super+Shift+K { move-window-up; }
        Super+Shift+L { move-column-right; }
        Super+Home { focus-column-first; }
        Super+End { focus-column-last; }
        Super+Ctrl+Left { set-column-width "-10%"; }
        Super+Ctrl+Right { set-column-width "+10%"; }
        Super+Ctrl+Up { set-window-height "+10%"; }
        Super+Ctrl+Down { set-window-height "-10%"; }
        Super+Ctrl+H { set-column-width "-10%"; }
        Super+Ctrl+J { set-window-height "-10%"; }
        Super+Ctrl+K { set-window-height "+10%"; }
        Super+Ctrl+L { set-column-width "+10%"; }
        Super+F { maximize-column; }
        Super+Shift+F { fullscreen-window; }
        Super+C { center-column; }

        // Workspaces
        Super+Page_Down { focus-workspace-down; }
        Super+Page_Up { focus-workspace-up; }
        Super+Shift+Page_Down { move-column-to-workspace-down; }
        Super+Shift+Page_Up { move-column-to-workspace-up; }
        Super+1 { focus-workspace 1; }
        Super+2 { focus-workspace 2; }
        Super+3 { focus-workspace 3; }
        Super+4 { focus-workspace 4; }
        Super+5 { focus-workspace 5; }
        Super+6 { focus-workspace 6; }
        Super+7 { focus-workspace 7; }
        Super+8 { focus-workspace 8; }
        Super+9 { focus-workspace 9; }
        Super+Shift+1 { move-column-to-workspace 1; }
        Super+Shift+2 { move-column-to-workspace 2; }
        Super+Shift+3 { move-column-to-workspace 3; }
        Super+Shift+4 { move-column-to-workspace 4; }
        Super+Shift+5 { move-column-to-workspace 5; }
        Super+Shift+6 { move-column-to-workspace 6; }
        Super+Shift+7 { move-column-to-workspace 7; }
        Super+Shift+8 { move-column-to-workspace 8; }
        Super+Shift+9 { move-column-to-workspace 9; }

        // Laptop controls
        XF86AudioRaiseVolume allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioPlay { spawn "${pkgs.playerctl}/bin/playerctl" "play-pause"; }
        XF86AudioNext { spawn "${pkgs.playerctl}/bin/playerctl" "next"; }
        XF86AudioPrev { spawn "${pkgs.playerctl}/bin/playerctl" "previous"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "+5%"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%-"; }
        Super+Shift+Escape { spawn "${qs}" "-c" "shell" "ipc" "call" "lock" "lock"; }
        Print { spawn "${qs}" "-c" "shell" "ipc" "call" "capture" "toggle"; }
    }

    // Kuro Engine output is included last so kuro.toml overrides these defaults.
    include optional=true "${config.home.homeDirectory}/.config/niri/kuro-theme.kdl"
  '';
}
