# Kuro Shell

Kuro Shell is the QuickShell desktop shell used by this configuration. Niri
is the active compositor and the default login session; Hyprland files and
their Home Manager profile remain available in the repository.

Kuro Engine supplies the active color scheme and the interface and terminal
font families through `~/.cache/kuro/theme.json`. Kuro Shell owns its layout
and shell preferences, including Material Symbols, icon sizing, spacing,
rounding, and wallpaper selection. Changing wallpaper does not change the
Kuro color scheme.

The Home Manager module is `quickshell.nix`. It installs the Quickshell `qs`
command, Kuro Shell's QML configuration and plugin support, and Kuro Engine's
`kurogen` command. Niri starts the Home Manager user service
`kuro-shell.service`, which runs `kurogen` and launches `qs -c shell`. IPC
bindings use `qs -c shell` directly.
The shell's editable preferences are stored in `~/.config/kuro/shell.json`;
an existing `~/.config/kuro-shell/shell.json` is moved there on first launch
when the new path does not already exist.
