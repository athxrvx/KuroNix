# Kuro configuration guide

This is a NixOS and Home Manager flake for the `athena` host and `atharva`
user. Niri is the default desktop session, and Kuro Shell is the QuickShell
desktop shell. Hyprland configuration and its Home Manager profile are kept in
the repository but are not selected by the active flake.

Kuro Engine is the source of truth for the color scheme, shell font, and
application toolkit font. Kuro Shell owns its layout, icon fonts (including
Material Symbols), icon sizing, and other shell preferences.

## Layout

```text
flake.nix
├── modules/desktop/niri.nix           active Niri system module
├── modules/desktop/hyprland.nix       retained Hyprland system module
├── home/home-manager/profiles/niri.nix active Niri Home Manager profile
├── home/home-manager/profiles/hyprland.nix retained Hyprland profile
├── home/home-manager/config/desktop/niri/
│   └── niri.nix                       Niri configuration
├── home/home-manager/config/desktop/kuro/
│   ├── kuro.toml                      Kuro Engine seed settings
│   └── kurogen.py                     theme and font generator
└── home/home-manager/config/desktop/quickshell/kuro-shell/
    └── ...                            Kuro Shell source
```

Niri starts the Home Manager user service `kuro-shell.service`. The service
runs Kuro Engine's generator before launching Quickshell. The generator writes
`~/.config/niri/kuro-theme.kdl`; Niri includes that generated fragment when it
exists. Niri's keybindings, input settings, and behavior stay in the Niri
configuration.

## Kuro Engine appearance settings

The writable settings file is `~/.config/kuro/kuro.toml`. The seed file in
`home/home-manager/config/desktop/kuro/kuro.toml` supplies initial defaults.
Theme definitions live in `home/home-manager/theme/colors/` and are installed
under `~/.config/kuro/themes/`.

`[theme]` selects the scheme and shared gaps. `[niri]` contains Niri compositor
appearance and behavior, `[rules]` contains explicitly added per-window
rules, and `[shell]` contains Quickshell sizing and icon settings. Set
`[fonts].shell_font` for Kuro Shell and Kitty; set `[toolkit].font` for GTK and
Qt applications. In each theme TOML, `background` is Kuro Shell's original
background color. `darker_background` is used by GTK, Qt, Kitty, and other
applications. `[terminal]` contains Kitty
settings. Application choices are declared in Nix. The inactive Hyprland
profile remains in the repository, while Kuro renders the active appearance
values for Niri.

Use `kurogen` to list or switch schemes, update settings, and regenerate the
theme outputs:

```sh
kurogen themes
kurogen scheme tokyo-night
kurogen set fonts.shell_font "JetBrainsMono Nerd Font"
kurogen set toolkit.font "Fira Sans"
kurogen set theme.gaps 10
kurogen set terminal.opacity 0.95
kurogen window "Picture-in-Picture" "open-floating true"
kurogen
```

Generated files include `~/.cache/kuro/theme.json` for Kuro Shell,
`~/.config/niri/kuro-theme.kdl` for Niri, GTK 3/4 stylesheets, Qt 5/6 color
settings, and the terminal and shell color outputs. Edit `kuro.toml` or use
`kurogen` to change these values; the generated files are outputs of Kuro
Engine.

Kuro Shell reads the interface and terminal family names from
`~/.cache/kuro/theme.json`. Its Appearance settings continue to manage
Material Symbols, icon sizes, spacing, rounding, and shell-specific controls.
Its editable preferences live at `~/.config/kuro/shell.json`; an existing
`~/.config/kuro-shell/shell.json` is moved there on first launch if needed.

## Kuro Shell

The shell source is in
`home/home-manager/config/desktop/quickshell/kuro-shell/`; Home Manager
installs the config and runs it as the `kuro-shell.service` user service with
`qs -c shell`. It provides the bar,
launcher, overview, notifications, lock screen, capture overlay, sidebar, and
Control Center. Its IPC instance is named `shell`.

Kuro Shell talks to Niri through its Niri integration and uses the generated
Kuro palette. Wallpapers remain a shell preference and do not select or
regenerate the Kuro color scheme.

## Kuro CLI

The `kuro` command is the existing NixOS and Home Manager wrapper. `kurogen`
is the separate Kuro Engine theme tool used to edit appearance settings and
render generated outputs. The wrapper implementation and its configuration
remain separate from the Kuro Shell port.
