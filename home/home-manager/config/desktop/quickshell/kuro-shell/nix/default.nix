{
  rev,
  lib,
  stdenv,
  makeFontsConf,
  fish,
  ddcutil,
  brightnessctl,
  networkmanager,
  lm_sensors,
  swappy,
  wl-clipboard,
  libqalculate,
  fftw,
  bash,
  ffmpeg,

  material-symbols,
  rubik,
  nerd-fonts,
  qt6,
  quickshell,
  aubio,
  libcava,
  pipewire,
  xkeyboard-config,
  cmake,
  ninja,
  pkg-config,
  debug ? false,
  extraRuntimeDeps ? [],
  ...
}: let
  version = "1.0.0";

  runtimeDeps =
    [
      quickshell
      fish
      ddcutil
      brightnessctl
      networkmanager
      lm_sensors
      swappy
      wl-clipboard
      libqalculate
      bash
      ffmpeg
    ]
    ++ extraRuntimeDeps;

  fontconfig = makeFontsConf {
    fontDirectories = [material-symbols rubik nerd-fonts.jetbrains-mono];
  };

  cmakeVersionFlags = [
    (lib.cmakeFeature "VERSION" version)
    (lib.cmakeFeature "GIT_REVISION" rev)
    (lib.cmakeFeature "DISTRIBUTOR" "nix-flake")
  ];

  extras = stdenv.mkDerivation {
    name = "kuro-shell-extras${lib.optionalString debug "-debug"}";
    src = lib.fileset.toSource {
      root = ./..;
      fileset = lib.fileset.union ./../CMakeLists.txt ./../extras;
    };

    nativeBuildInputs = [cmake ninja];

    cmakeFlags =
      [
        (lib.cmakeFeature "ENABLE_MODULES" "extras")
        (lib.cmakeFeature "INSTALL_LIBDIR" "${placeholder "out"}/lib")
      ]
      ++ cmakeVersionFlags;
  };

  plugin = stdenv.mkDerivation {
    name = "kuro-shell-qml-plugin${lib.optionalString debug "-debug"}";
    src = lib.fileset.toSource {
      root = ./..;
      fileset = lib.fileset.union ./../CMakeLists.txt ./../plugin;
    };

    nativeBuildInputs = [cmake ninja pkg-config];
    buildInputs = [qt6.qtbase qt6.qtdeclarative qt6.qt5compat fftw qt6.qtmultimedia libqalculate pipewire aubio libcava];

    dontWrapQtApps = true;
    cmakeFlags =
      [
        (lib.cmakeFeature "ENABLE_MODULES" "plugin")
        (lib.cmakeFeature "INSTALL_QMLDIR" qt6.qtbase.qtQmlPrefix)
      ]
      ++ cmakeVersionFlags;
  };
in
  stdenv.mkDerivation {
    inherit version;
    pname = "kuro-shell-config${lib.optionalString debug "-debug"}";
    src = ./..;

    nativeBuildInputs = [cmake ninja qt6.wrapQtAppsHook];
    buildInputs = [quickshell extras plugin xkeyboard-config qt6.qtbase qt6.qtmultimedia];
    propagatedBuildInputs = runtimeDeps;

    cmakeBuildType =
      if debug
      then "Debug"
      else "RelWithDebInfo";
    cmakeFlags =
      [
        (lib.cmakeFeature "ENABLE_MODULES" "shell")
        (lib.cmakeFeature "INSTALL_QSCONFDIR" "${placeholder "out"}/share/kuro-shell")
      ]
      ++ cmakeVersionFlags;

    dontStrip = debug;

    prePatch = ''
      substituteInPlace assets/pam.d/fprint \
        --replace-fail pam_fprintd.so /run/current-system/sw/lib/security/pam_fprintd.so
      substituteInPlace shell.qml \
        --replace-fail 'ShellRoot {' 'ShellRoot {  settings.watchFiles: false'
    '';

    postInstall = ''
      mkdir -p $out/lib
      ln -s ${extras}/lib/* $out/lib/
    '';

    passthru = {
      inherit plugin extras;
      launchEnvironment = {
        PATH = lib.makeBinPath runtimeDeps;
        QML2_IMPORT_PATH = lib.makeSearchPath qt6.qtbase.qtQmlPrefix [ qt6.qtdeclarative qt6.qt5compat qt6.qtmultimedia plugin ];
        FONTCONFIG_FILE = "${fontconfig}";
        KURO_SHELL_LIB_DIR = "${extras}/lib";
        KURO_SHELL_XKB_RULES_PATH = "${xkeyboard-config}/share/xkeyboard-config-2/rules/base.lst";
      };
    };

    meta = {
      description = "Kuro Shell desktop shell for Niri";
      homepage = "https://github.com/athxrvx/athena";
      license = lib.licenses.gpl3Only;
    };
  }
