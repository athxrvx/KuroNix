# Kuro

Kuro is a single-host NixOS and Home Manager configuration for an HP Victus
15-fb2117ax. The `athena` flake output configures the `atharva` account. Niri is
the default desktop session, with Kuro Shell providing the Quickshell desktop
UI. The existing Hyprland configuration and profile remain available in the
tree as an inactive alternative.

## Getting started

From this configuration directory:

```sh
kuro sync          # build and activate NixOS + Home Manager
kuro status        # show system and Home Manager generations
```

Run `kuro` from inside the flake, or set `KURO_FLAKE=$HOME/.config/nixconfig`
or pass `--flake PATH`. The first Nix build creates `flake.lock`; `kuro update`
refreshes inputs.

## Desktop and theming

- **Niri** is enabled by NixOS and selected as SDDM's default session. Its
  configuration starts Kuro Shell and Xwayland Satellite.
- **Kuro Shell** is the Niri-ready Quickshell desktop, installed as
  `kuro-shell`. Its workspace and window controls use Niri IPC.
- **Kuro** is the single theme source. `~/.config/kuro/kuro.toml` selects a
  palette, separate shell/application backgrounds, and shell/toolkit fonts;
  `kurogen` writes the Quickshell theme JSON, Niri color fragment, GTK and Qt
  themes, kitty theme, Zsh colors and Neovim colorscheme.
- **Hyprland** files and the old Home Manager profile remain in the repository,
  but the active flake output uses the Niri profile.

Theme commands:

```sh
kurogen themes
kurogen scheme jellybeans
kurogen set theme.mode light
kurogen
```

## Repository guide

- [Full configuration guide](home/documentation/README.md)
- [Kuro Shell reference](home/home-manager/config/desktop/quickshell/kuro-shell/README.md)
- [Kuro theme engine](home/home-manager/config/desktop/kuro/kurogen.py)
