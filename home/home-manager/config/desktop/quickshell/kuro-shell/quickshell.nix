{ config, lib, pkgs, ... }:
let
  kuroShellFiles = pkgs.callPackage ./nix/default.nix { rev = "nix-config"; };
  kurogen = import ../../kuro/kurogen.nix { inherit pkgs; };
  kuroCapture = pkgs.writeShellScriptBin "kuro-capture" (builtins.readFile ../kuro/bin/capture);
  kuroIdleLock = pkgs.writeShellScriptBin "kuro-idle-lock" ''
    if ${pkgs.quickshell}/bin/qs -c shell ipc call idleInhibitor isEnabled 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx true; then
      exit 0
    fi
    exec ${pkgs.quickshell}/bin/qs -c shell ipc call lock lock
  '';
  kuroIdleHibernate = pkgs.writeShellScriptBin "kuro-idle-hibernate" ''
    if ${pkgs.quickshell}/bin/qs -c shell ipc call idleInhibitor isEnabled 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx true; then
      exit 0
    fi
    exec ${pkgs.systemd}/bin/systemctl hibernate
  '';
  kuroIdleDisplayOff = pkgs.writeShellScriptBin "kuro-idle-display-off" ''
    if ${pkgs.quickshell}/bin/qs -c shell ipc call idleInhibitor isEnabled 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx true; then
      exit 0
    fi
    exec ${pkgs.niri}/bin/niri msg action power-off-monitors
  '';
  kuroIdle = pkgs.writeShellScriptBin "kuro-idle" ''
    exec ${pkgs.swayidle}/bin/swayidle -w \
      timeout 600 '${kuroIdleDisplayOff}/bin/kuro-idle-display-off' \
      resume '${pkgs.niri}/bin/niri msg action power-on-monitors' \
      timeout 900 '${kuroIdleLock}/bin/kuro-idle-lock' \
      timeout 960 '${kuroIdleHibernate}/bin/kuro-idle-hibernate' \
      before-sleep '${pkgs.quickshell}/bin/qs -c shell ipc call lock lock'
  '';
in
{
  home.packages = [ kuroShellFiles kurogen pkgs.quickshell kuroCapture pkgs.swayidle kuroIdle ] ++ (with pkgs; [
    awww
    imagemagick
    pciutils
    yt-dlp
    dex
    mpv
    curl
    mpc
    gpu-screen-recorder
    grim
    slurp
    libnotify
    wl-clipboard
    cliphist
    tesseract
    xdg-utils
    python3
  ]);

  home.sessionVariables = {
    QML2_IMPORT_PATH = kuroShellFiles.passthru.launchEnvironment.QML2_IMPORT_PATH;
    FONTCONFIG_FILE = kuroShellFiles.passthru.launchEnvironment.FONTCONFIG_FILE;
    KURO_SHELL_LIB_DIR = kuroShellFiles.passthru.launchEnvironment.KURO_SHELL_LIB_DIR;
    KURO_SHELL_XKB_RULES_PATH = kuroShellFiles.passthru.launchEnvironment.KURO_SHELL_XKB_RULES_PATH;
  };

  systemd.user.services.kuro-shell = {
    Unit = {
      Description = "Kuro Shell";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${kurogen}/bin/kurogen";
      ExecStart = "${pkgs.quickshell}/bin/qs -c shell";
      Restart = "on-failure";
      RestartSec = "2s";
      Environment = [
        "QML2_IMPORT_PATH=${kuroShellFiles.passthru.launchEnvironment.QML2_IMPORT_PATH}"
        "FONTCONFIG_FILE=${kuroShellFiles.passthru.launchEnvironment.FONTCONFIG_FILE}"
        "KURO_SHELL_LIB_DIR=${kuroShellFiles.passthru.launchEnvironment.KURO_SHELL_LIB_DIR}"
        "KURO_SHELL_XKB_RULES_PATH=${kuroShellFiles.passthru.launchEnvironment.KURO_SHELL_XKB_RULES_PATH}"
      ];
    };
  };

  systemd.user.services.cliphist-watch-text = {
    Unit = {
      Description = "Store text selections in clipboard history";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.cliphist-watch-image = {
    Unit = {
      Description = "Store copied images in clipboard history";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.kuro-idle = {
    Unit = {
      Description = "Kuro idle lock, display power, and hibernation";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" "kuro-shell.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${kuroIdle}/bin/kuro-idle";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  services.mpd = {
    enable = true;
    musicDirectory = config.home.homeDirectory + "/Music";
    extraConfig = ''
      audio_output {
        type "pipewire"
        name "Kuro Shell MPD"
      }
      follow_outside_symlinks "yes"
      auto_update "yes"
    '';
  };

  xdg.configFile."mpd/mpd.conf".text = config.services.mpd.generatedConfig;
  xdg.configFile."quickshell/shell".source = "${kuroShellFiles}/share/kuro-shell";

  systemd.user.services.kuro-shell-lid-lock = {
    Unit.Description = "Lock Kuro Shell before lid-close suspend";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.quickshell}/bin/qs -c shell ipc call lock lock";
    };
  };
}
