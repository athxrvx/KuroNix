{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [ "gtk" ];
      niri = {
        default = [ "gnome" "gtk" ];
      };
    };
  };

  home.sessionVariables.GTK_USE_PORTAL = "1";
}
