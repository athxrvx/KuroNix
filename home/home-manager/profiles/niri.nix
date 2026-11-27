{ pkgs, ... }:
{
  imports = [
    ../config/desktop/quickshell/kuro-shell/quickshell.nix
    ../config/desktop/niri/niri.nix
    ../config/desktop/gtk/gtk.nix
    ../config/desktop/kuro/kuro.nix
    ../theme/colors/colors.nix
    ../theme/colors/theme-check.nix
    ../config/desktop/kitty/kitty.nix
    ../config/desktop/containers/containers.nix
    ../config/shell/zsh/kuro/kuro.nix
    ../config/apps/desktop-apps.nix
    ../config/services/easyeffects.nix
    ../config/services/kdeconnect.nix
  ];

  home.packages = with pkgs; [ playerctl brightnessctl wireplumber ];
}
