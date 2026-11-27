{ config, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    SUDO_EDITOR = "nvim";
    GIT_EDITOR = "nvim";
    GIT_SEQUENCE_EDITOR = "nvim";
    NIX_EDITOR = "nvim";
    # The flake lives at ~/.config/nixconfig. Set it explicitly so the kuro
    # CLI and the launcher's update entries work from any directory.
    KURO_FLAKE = "${config.home.homeDirectory}/.config/nixconfig";
    KURO_PROFILE = "athena";
    KURO_USER = "atharva";
  };
}
