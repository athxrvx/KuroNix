{ ... }:
{
  imports = [
    ./environment.nix
    ./development.nix
    ../config/shell/fastfetch.nix
    ../config/shell/zsh/zsh.nix
    ../config/shell/athena/kuro.nix
    ../config/desktop/xdg/xdg.nix
  ];
}
