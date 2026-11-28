{ lib, pkgs, ... }:
let
  nautilusActionRuntime = with pkgs; [
    quickshell
    imagemagick
    zenity
    wl-clipboard
    jq
    python3
    zip
    unzip
    gnutar
    coreutils
    kitty
    neovim
    git
  ];
  nautilusActions = pkgs.writeShellScriptBin "kuro-nautilus-actions" ''
    export PATH="${lib.makeBinPath nautilusActionRuntime}:$PATH"
    exec ${pkgs.bash}/bin/bash ${./nautilus/nautilus-actions.sh} "$@"
  '';
  actionEntries = [
    {
      group = "Wallpapers";
      label = "Set as Wallpaper";
      action = "set-wallpaper";
    }
    {
      group = "Wallpapers";
      label = "Add to Wallpapers (move)";
      action = "add-wallpaper";
    }
    {
      group = "File Tools";
      label = "Open Kitty Here";
      action = "kitty-here";
    }
    {
      group = "File Tools";
      label = "Open in Neovim";
      action = "nvim";
    }
    {
      group = "File Tools";
      label = "Copy Path";
      action = "copy-path";
    }
    {
      group = "File Tools";
      label = "Copy Filename";
      action = "copy-name";
    }
    {
      group = "File Tools";
      label = "Calculate SHA-256";
      action = "checksum";
    }
    {
      group = "File Tools";
      label = "Create Archive…";
      action = "archive";
    }
    {
      group = "File Tools";
      label = "Extract Archive Here";
      action = "extract";
    }
    {
      group = "Images";
      label = "Rotate Left 90° (copy)";
      action = "image-rotate-left";
    }
    {
      group = "Images";
      label = "Rotate Right 90° (copy)";
      action = "image-rotate-right";
    }
    {
      group = "Images";
      label = "Flip Horizontally (copy)";
      action = "image-flip-horizontal";
    }
    {
      group = "Images";
      label = "Flip Vertically (copy)";
      action = "image-flip-vertical";
    }
    {
      group = "Images";
      label = "Resize…";
      action = "image-resize";
    }
    {
      group = "Images";
      label = "Convert Format…";
      action = "image-convert";
    }
    {
      group = "Images";
      label = "Image Details";
      action = "image-details";
    }
    {
      group = "Images";
      label = "Remove Metadata (copy)";
      action = "image-strip-metadata";
    }
    {
      group = "Git";
      label = "Git Status";
      action = "git-status";
    }
    {
      group = "Git";
      label = "Open Repository in Kitty";
      action = "git-terminal";
    }
    {
      group = "Git";
      label = "Open Repository in Neovim";
      action = "git-nvim";
    }
    {
      group = "Git";
      label = "Copy Repository Root";
      action = "git-copy-root";
    }
    {
      group = "Git";
      label = "Initialize Repository Here…";
      action = "git-init";
    }
    {
      group = "Git";
      label = "Clone Repository Here…";
      action = "git-clone";
    }
  ];
  nautilusScripts = lib.listToAttrs (
    map (
      entry:
      let
        binary = "kuro-nautilus-${entry.action}";
        wrapper = pkgs.writeShellScriptBin binary ''
          exec ${nautilusActions}/bin/kuro-nautilus-actions ${lib.escapeShellArg entry.action} "$@"
        '';
      in
      {
        name = ".local/share/nautilus/scripts/${entry.group}/${entry.label}";
        value.source = "${wrapper}/bin/${binary}";
      }
    ) actionEntries
  );
in
{
  home.packages = [
    pkgs.xdg-user-dirs
    pkgs.ranger
    pkgs.nautilus
    pkgs.papers
    pkgs.loupe
    pkgs.gnome-text-editor
    pkgs.brave
  ];

  home.file = nautilusScripts;
  programs.zathura.enable = false;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
      "text/plain" = [ "org.gnome.TextEditor.desktop" ];
      "application/pdf" = [ "org.gnome.Papers.desktop" ];
      "text/html" = [ "firefox.desktop" ];
      "application/xhtml+xml" = [ "firefox.desktop" ];
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
      "x-scheme-handler/codex" = [ "chatgpt.desktop" ];
    };
  };

  # GTK/GNOME appearance is declared in ../desktop/gtk/gtk.nix.
}
