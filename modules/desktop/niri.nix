{ config, lib, pkgs, ... }:
{
  imports = [ ../power/lid-close.nix ];

  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  security.pam.services.sddm-autologin = {
    enableGnomeKeyring = true;
    text = lib.mkForce ''
      auth requisite pam_nologin.so
      auth optional ${config.systemd.package}/lib/security/pam_systemd_loadkey.so
      auth optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so
      auth required pam_succeed_if.so uid >= 1000 quiet
      auth required pam_permit.so

      account include sddm
      password include sddm
      session include sddm
      session optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
    '';
  };

  systemd.services.display-manager.serviceConfig.KeyringMode = "inherit";

  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      settings.Autologin = {
        Session = "niri.desktop";
        User = "atharva";
      };
    };
    autoLogin = {
      enable = true;
      user = "atharva";
    };
    defaultSession = "niri";
  };

  programs.niri.enable = true;
  programs.xwayland.enable = true;

  security.polkit.enable = true;
  programs.dconf.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.libinput.enable = true;

  programs.gdk-pixbuf.modulePackages = [ pkgs.webp-pixbuf-loader ];

  environment.systemPackages = with pkgs; [
    nautilus
    file-roller
    ffmpegthumbnailer
    poppler
    android-tools
    xwayland-satellite
  ];

  fonts.packages = with pkgs; [
    inter
    fira-sans
    rubik
    material-symbols
    nerd-fonts.jetbrains-mono
  ];
  fonts.fontDir.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-gnome ];
    config.niri.default = [ "gnome" "gtk" ];
  };
}
