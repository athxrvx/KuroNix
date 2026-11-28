{ lib, pkgs, ... }:
let
  root = ./.;
  # Hyprland remains available as a static, inactive profile; Kurogen does
  # not generate Hyprland configuration.
  files = lib.filter
    (p: ! lib.hasSuffix "hyprland.nix" (toString p)
      && ! lib.hasSuffix "hypridle.conf" (toString p))
    (lib.filesystem.listFilesRecursive root);
  relative = p: lib.removePrefix (toString root + "/") (toString p);
in
{
  home.packages = with pkgs; [
    hyprsunset
    hyprpicker
    cliphist
    wl-clipboard
    playerctl
    brightnessctl
    grim
    slurp
  ];

  home.file = (lib.listToAttrs (map (p: {
    name = ".config/hypr/${relative p}";
    value.source = p;
  }) files)) // {
    ".config/hypr/hypridle.conf".text =
      builtins.replaceStrings [ "@QS@" "@SYSTEMCTL@" ]
        [ "${pkgs.quickshell}/bin/qs" "${pkgs.systemd}/bin/systemctl" ]
        (builtins.readFile ./hypridle.conf);
  };

  home.sessionVariables = {
    TERMINAL = "kitty";
    NIXOS_OZONE_WL = "1";
  };
}
