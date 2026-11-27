{ lib, pkgs, ... }:
let
  root = ./.;
in
{
  home.packages = with pkgs; [
    papirus-icon-theme
    adw-gtk3
    fira-sans
    inter
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
    nerd-fonts.caskaydia-cove
    nerd-fonts.fira-code
    libsForQt5.qt5ct
    qt6Packages.qt6ct
  ];

  home.sessionVariables.QT_QPA_PLATFORMTHEME = "qt5ct:qt6ct";

  home.file = {
    ".config/gtk-2.0/gtkrc".source = "${root}/gtkrc-2.0";
    ".config/gtk-3.0/settings.ini".source = "${root}/settings-gtk3.ini";
    ".config/gtk-4.0/settings.ini".source = "${root}/settings-gtk4.ini";
    ".config/xsettingsd/xsettingsd.conf".source = "${root}/xsettingsd.conf";
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Orchis-Dark";
    icon-theme = "Papirus-Dark";
    font-name = "Fira Sans 10";
  };

  xdg.dataFile."themes/Orchis-Dark" = {
    source = ../../../theme/Orchis-Dark;
    recursive = true;
  };
}
