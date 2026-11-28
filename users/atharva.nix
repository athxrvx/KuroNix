{ pkgs, ... }:
{
  services.flatpak.enable = true;
  programs.zsh.enable = true;
  # Password is the one set during installation (or change with `passwd`).
  users.users.atharva = {
    isNormalUser = true;
    description = "Atharva";
    extraGroups = [ "wheel" "networkmanager" "video" "kvm" "adbusers" ];
    shell = pkgs.zsh;
  };
}
