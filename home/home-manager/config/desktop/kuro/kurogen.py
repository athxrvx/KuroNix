#!/usr/bin/env python3
"""kurogen — render the kuro.toml settings into app-specific configs.

Source of truth : ~/.config/kuro/kuro.toml
Outputs         : ~/.cache/kuro/theme.json       (Quickshell)
                  ~/.config/niri/kuro-theme.kdl  (Niri)
                  ~/.config/kitty/kuro.conf      (kitty)
                  ~/.config/nvim/colors/kuro.lua  (Neovim)
                  ~/.config/gtk-{3,4}.0/gtk.css   (GTK)
                  ~/.config/qt{5,6}ct/*           (Qt)

Usage:
    kurogen                       regenerate everything
    kurogen set theme.gaps 8      edit one value, then regenerate
    kurogen window "Title" "open-floating true"
                                  add a rule for an exact Niri window title
    kurogen path                  print the config path

On first run, kurogen copies kuro.toml and the default themes from
KURO_DEFAULTS (or ~/.config/kuro/defaults) into ~/.config/kuro. Existing
files are never overwritten.

Only Python's standard library is used (tomllib, Python >= 3.11).
"""

from __future__ import annotations

import copy
import json
import os
import re
import shutil
import sys
import tomllib
from pathlib import Path

HOME = Path(os.environ.get("HOME") or Path.home())
CONFIG = Path(os.environ.get("KURO_CONFIG") or HOME / ".config/kuro/kuro.toml")
THEMES_DIR = Path(os.environ.get("KURO_THEMES") or HOME / ".config/kuro/themes")
KURO_DEFAULTS = Path(os.environ.get("KURO_DEFAULTS") or "")
THEME_JSON = HOME / ".cache/kuro/theme.json"
ZSH_COLORS = HOME / ".cache/kuro/zsh-colors.zsh"
FLEA_THEME_DIR = HOME / ".cache/kuro/flea"
FLEA_COLORS = FLEA_THEME_DIR / "colors.toml"
FLEA_SHELL = FLEA_THEME_DIR / "shell.toml"
FLEA_FONT_FAMILY = FLEA_THEME_DIR / "font-family"
NIRI_KDL = HOME / ".config/niri/kuro-theme.kdl"
KITTY_CONF = HOME / ".config/kitty/kuro.conf"
NVIM_THEME = HOME / ".config/nvim/colors/kuro.lua"
GTK3_CSS = HOME / ".config/gtk-3.0/gtk.css"
GTK4_CSS = HOME / ".config/gtk-4.0/gtk.css"
QT5_CONFIG = HOME / ".config/qt5ct/qt5ct.conf"
QT6_CONFIG = HOME / ".config/qt6ct/qt6ct.conf"
QT5_COLORS = HOME / ".config/qt5ct/colors/kuro.conf"
QT6_COLORS = HOME / ".config/qt6ct/colors/kuro.conf"

DEFAULTS = {
    "colors": {
        "palette": [
            "#151515", "#e27373", "#94b979", "#ffba7b",
            "#97bedc", "#e1c0fa", "#00988e", "#dedede",
            "#888888", "#ffa1a1", "#bddeab", "#ffdca0",
            "#b1d8f6", "#fbdaff", "#1ab2a8", "#ffffff",
        ],
        "base": "#0b0b0b",
        "shell_background": "#0d0d0d",
        "ink": "#dedede",
        "hot": "#e27373",
        "accent": "#8a694c",
        "accent_text": "#dedede",
        "red": "#e27373",
        "yellow": "#ffba7b",
        "orange": "#ffa560",
        "green": "#94b979",
        "cyan": "#00988e",
        "blue": "#97bedc",
        "magenta": "#e1c0fa",
        "brown": "#8a694c",
        "muted": "#888888",
        "cursor": "#ffa560",
        "cursor_text": "#0d0d0d",
        "selection_background": "#fad07a",
        "selection_foreground": "#0d0d0d",
        "url": "#97bedc",
        "active_border": "#8a694c",
        "inactive_border": "#88888888",
        "tab_active_background": "#8a694c",
        "tab_active_foreground": "#dedede",
        "tab_inactive_background": "#303030",
        "tab_inactive_foreground": "#dedede",
    },
    "theme": {
        "scheme": "jellybeans",
        "mode": "auto",
        # Compatibility defaults for existing Hyprland and shell consumers.
        "rounding": 0,
        "gaps_in": 4,
        "gaps_out": 8,
        "border_size": 2,
        "blur": True,
        "animations": True,
        "active_opacity": 1.0,
        "inactive_opacity": 1.0,
        "shadow": True,
        "shadow_range": 4,
        "shadow_power": 3,
        "shadow_color": "0x990d0d0d",
        "bar_height": 30,
        "popup_gap": 14,
        "radius": 0,
        "radius_small": 0,
        "padding": 16,
        "gap": 10,
        # Niri-adapted visual settings.
        "gaps": 8,
    },
    "fonts": {
        "shell_font": "JetBrainsMono Nerd Font",
        "ui_size": 15,
        "terminal_size": 11.5,
    },
    "toolkit": {"inherit_theme": True, "font": "Fira Sans", "size": 10},
    "niri": {
        "center_focused_column": "never",
        "border_size": 3,
        "rounding": 10,
        "blur": False,
        "active_opacity": 1.0,
        "inactive_opacity": 1.0,
        "animations": True,
        "shadow": True,
        "shadow_range": 4,
        "shadow_power": 3,
        "shadow_color": "0x990d0d0d",
    },
    "rules": {},
    "shell": {
        "bar_height": 30,
        "popup_gap": 14,
        "radius": 0,
        "radius_small": 0,
        "padding": 16,
        "gap": 10,
        "icon_size": 20,
    },
    "terminal": {"opacity": 0.97, "padding": 10, "cursor_shape": "block", "scrollback": 10000},
    "apps": {
        "terminal": "kitty",
        "file_manager": "nautilus",
        "menu": "qs -c shell ipc call launcher toggle",
        "wallpaper_dir": "~/Pictures/Wallpaper",
        "wallpaper_picker": "quickshell -c hyprquickpaper",
    },
}


class KuroError(Exception):
    pass


def deep_merge(base: dict, override: dict) -> dict:
    out = copy.deepcopy(base)
    for key, value in (override or {}).items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = deep_merge(out[key], value)
        else:
            out[key] = value
    return out


def theme_path(name: str) -> Path:
    return THEMES_DIR / f"{name}.toml"


def list_themes() -> list[dict]:
    """Every *.toml in ~/.config/kuro/themes, sorted by file name."""
    found = []
    if THEMES_DIR.is_dir():
        for path in sorted(THEMES_DIR.glob("*.toml")):
            name = path.stem.replace("-", " ").title()
            try:
                with path.open("rb") as fh:
                    data = tomllib.load(fh)
                name = data.get("name", name)
            except (OSError, tomllib.TOMLDecodeError):
                pass
            try:
                colors = theme_colors(path.stem)
            except (KuroError, OSError, tomllib.TOMLDecodeError):
                colors = DEFAULTS["colors"]
            palette = colors.get("palette", DEFAULTS["colors"]["palette"])
            found.append({"id": path.stem, "name": name, "palette": palette[:16]})
    return found


def load_theme(name: str) -> dict:
    path = theme_path(name)
    if not path.is_file():
        known = ", ".join(t["id"] for t in list_themes()) or "none"
        raise KuroError(f"unknown theme {name!r} (available: {known})")
    try:
        with path.open("rb") as fh:
            return tomllib.load(fh)
    except tomllib.TOMLDecodeError as exc:
        raise KuroError(f"invalid theme {path}: {exc}")


def theme_colors(name: str) -> dict:
    """Normalise an Omarchy colors.toml (or a Kuro palette theme) to colors."""
    theme = load_theme(name)
    tc = theme.get("colors") if isinstance(theme.get("colors"), dict) else theme

    # Custom Kuro theme: a 16-colour palette plus explicit color keys.
    if isinstance(tc.get("palette"), list):
        palette = list(tc["palette"])
        if len(palette) < 16:
            raise KuroError(f"theme {name!r}: palette needs 16 entries, found {len(palette)}")
        colors = deep_merge(DEFAULTS["colors"], tc)
        colors["palette"] = palette[:16]
        colors["shell_background"] = tc.get("background", colors["shell_background"])
        colors["base"] = tc.get("darker_background", colors["base"])
        return colors

    # Omarchy theme (flat semantic names).
    def get(key: str, fallback: str) -> str:
        value = tc.get(key)
        return str(value) if value else fallback

    shell_bg = get("background", DEFAULTS["colors"]["shell_background"])
    bg = get("darker_background", DEFAULTS["colors"]["base"])
    fg = get("foreground", DEFAULTS["colors"]["ink"])
    red = get("red", DEFAULTS["colors"]["hot"])
    green = get("green", DEFAULTS["colors"]["palette"][2])
    yellow = get("yellow", DEFAULTS["colors"]["palette"][3])
    blue = get("blue", DEFAULTS["colors"]["palette"][4])
    magenta = get("magenta", DEFAULTS["colors"]["palette"][5])
    cyan = get("cyan", DEFAULTS["colors"]["palette"][6])
    accent = get("accent", blue)

    palette = [
        get("dark_background", bg),
        red,
        green,
        yellow,
        blue,
        magenta,
        cyan,
        fg,
        get("muted", DEFAULTS["colors"]["palette"][8]),
        get("bright_red", red),
        get("bright_green", green),
        get("bright_yellow", yellow),
        get("bright_blue", blue),
        get("bright_magenta", magenta),
        get("bright_cyan", cyan),
        get("bright_foreground", fg),
    ]

    return {
        "palette": palette,
        "base": bg,
        "shell_background": shell_bg,
        "ink": fg,
        "hot": red,
        "red": red,
        "yellow": yellow,
        "orange": get("orange", DEFAULTS["colors"]["orange"]),
        "green": green,
        "cyan": cyan,
        "blue": blue,
        "magenta": magenta,
        "brown": get("brown", DEFAULTS["colors"]["brown"]),
        "muted": get("muted", DEFAULTS["colors"]["muted"]),
        "accent": accent,
        "accent_text": get("accent_text", fg),
        "cursor": get("cursor", get("bright_foreground", fg)),
        "cursor_text": get("cursor_text", bg),
        "selection_background": get("selection", accent),
        "selection_foreground": get("selection_foreground", bg),
        "url": get("url", get("bright_blue", blue)),
        # Solitude provides a dedicated active_border_color.
        "active_border": get("active_border", get("active_border_color", accent)),
        "inactive_border": get("inactive_border", "#595959aa"),
        "tab_active_background": get("active_tab_background", accent),
        "tab_active_foreground": get("tab_active_foreground", bg),
        "tab_inactive_background": get("lighter_background", bg),
        "tab_inactive_foreground": get("tab_inactive_foreground", fg),
    }


def resolve_theme(cfg: dict, raw: dict) -> None:
    """Load the selected theme file and expand it into cfg["colors"]."""
    scheme = str(cfg.get("theme", {}).get("scheme") or "").strip()
    explicit = raw.get("colors") or {}

    if scheme:
        colors = theme_colors(scheme)
        cfg["colors"] = deep_merge(colors, explicit)
        theme = load_theme(scheme)
        cfg["scheme_name"] = theme.get("name", scheme)
        scheme_mode = theme.get("mode", "dark")
    else:
        cfg["colors"] = deep_merge(cfg["colors"], explicit)
        cfg["scheme_name"] = "Custom"
        scheme_mode = "dark"

    requested_mode = str(cfg.get("theme", {}).get("mode", "auto")).strip().lower()
    cfg["mode"] = scheme_mode if requested_mode == "auto" else requested_mode
    if cfg["mode"] not in ("dark", "light"):
        raise KuroError("theme.mode must be 'auto', 'dark', or 'light'")

    cfg["scheme"] = scheme or "custom"
    cfg["schemes"] = list_themes()



def bootstrap_defaults() -> bool:
    """Copy bundled first-run defaults into ~/.config/kuro without overwrites.

    KURO_DEFAULTS points at the flake's bundled kuro.toml and themes. When it
    is unset, ~/.config/kuro/defaults is used as a local fallback. Home
    Manager never owns kuro.toml or themes because `kurogen set` rewrites them.
    """
    defaults = Path(
        os.environ.get("KURO_DEFAULTS")
        or str(HOME / ".config/kuro/defaults")
    ).expanduser()
    copied = False

    default_config = defaults / "kuro.toml"
    if default_config.is_file() and not CONFIG.exists():
        CONFIG.parent.mkdir(parents=True, exist_ok=True)
        # copy2 preserves the Nix store's 0444 mode; kuro.toml is imperative
        # and must stay writable so `kurogen set` can change the scheme.
        shutil.copyfile(default_config, CONFIG)
        CONFIG.chmod(0o644)
        copied = True

    default_themes = defaults / "themes"
    if default_themes.is_dir():
        THEMES_DIR.mkdir(parents=True, exist_ok=True)
        for source in sorted(default_themes.glob("*.toml")):
            target = THEMES_DIR / source.name
            if not target.exists():
                shutil.copy2(source, target)
                copied = True

    if copied:
        print(f"kuro: bootstrapped defaults from {defaults}")
    return copied


def load(path: Path = CONFIG) -> dict:
    bootstrap_defaults()
    try:
        with path.open("rb") as fh:
            raw = tomllib.load(fh)
    except FileNotFoundError:
        raise KuroError(f"missing config: {path}")
    except tomllib.TOMLDecodeError as exc:
        raise KuroError(f"invalid TOML in {path}: {exc}")

    cfg = deep_merge(DEFAULTS, raw)
    # Read old kuro.toml files while users transition to the extensible,
    # compositor-specific sections. Explicit new values always take priority.
    legacy_theme = raw.get("theme", {})
    if "gaps" not in legacy_theme and "gaps_out" in legacy_theme:
        cfg["theme"]["gaps"] = legacy_theme["gaps_out"]
    # Migrate the old all-in-one theme table into compositor, rule, and shell
    # settings. Values written in the new sections take precedence.
    legacy_niri = (
        "border_size", "blur", "animations", "active_opacity", "inactive_opacity",
        "shadow", "shadow_range", "shadow_power", "shadow_color", "rounding",
    )
    for key in legacy_niri:
        if key in legacy_theme and key not in raw.get("niri", {}):
            cfg["niri"][key] = legacy_theme[key]
    # The previous draft placed global Niri appearance values in [rules].
    # Move them out; [rules] is now exclusively for named window rules.
    for key in legacy_niri:
        if key in raw.get("rules", {}) and key not in raw.get("niri", {}):
            cfg["niri"][key] = raw["rules"][key]
            cfg["rules"].pop(key, None)
    for key in ("bar_height", "popup_gap", "radius", "radius_small", "padding", "gap"):
        if key in legacy_theme and key not in raw.get("shell", {}):
            cfg["shell"][key] = legacy_theme[key]
    # Older settings had separate interface and terminal font families. Keep
    # the interface family as the shared shell font unless the new key exists.
    if "shell_font" not in raw.get("fonts", {}):
        old_shell_font = raw.get("fonts", {}).get("ui_family") or raw.get("fonts", {}).get("terminal_family")
        if old_shell_font:
            cfg["fonts"]["shell_font"] = old_shell_font
    if "icon_size" in raw.get("fonts", {}) and "icon_size" not in raw.get("shell", {}):
        cfg["shell"]["icon_size"] = raw["fonts"]["icon_size"]
    legacy_terminal_size = raw.get("terminal", {}).get("font_size")
    if legacy_terminal_size is not None and "terminal_size" not in raw.get("fonts", {}):
        cfg["fonts"]["terminal_size"] = legacy_terminal_size
    resolve_theme(cfg, raw)
    palette = cfg["colors"].get("palette") or []
    if len(palette) < 16:
        raise KuroError(f"colors.palette needs 16 entries, found {len(palette)}")
    cfg["colors"]["palette"] = palette[:16]
    return cfg


# ── helpers ──────────────────────────────────────────────────────────
def toml_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "[" + ", ".join(toml_value(v) for v in value) + "]"
    if isinstance(value, dict):
        entries = (f"{json.dumps(key)} = {toml_value(item)}" for key, item in value.items())
        return "{ " + ", ".join(entries) + " }"
    raise KuroError(f"cannot serialise {value!r} to TOML")


def write_if_changed(path: Path, text: str) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        if path.read_text(encoding="utf-8") == text:
            return False
    except (FileNotFoundError, UnicodeDecodeError):
        pass
    path.write_text(text, encoding="utf-8")
    return True


# ── renderers ────────────────────────────────────────────────────────
def render_theme_json(cfg: dict) -> str:
    c, t, f, s = cfg["colors"], cfg["theme"], cfg["fonts"], cfg["shell"]
    toolkit = cfg["toolkit"]
    a, app = cfg["apps"], cfg["terminal"]
    data = {
        "scheme": cfg.get("scheme", ""),
        "schemeName": cfg.get("scheme_name", ""),
        "mode": cfg.get("mode", "dark"),
        "schemes": cfg.get("schemes", []),
        "colors": {
            "palette": c["palette"],
            "base": c["base"],
            "shellBackground": c["shell_background"],
            "ink": c["ink"],
            "hot": c["hot"],
            "accent": c["accent"],
            "accentText": c["accent_text"],
            "cursor": c["cursor"],
            "cursorText": c["cursor_text"],
            "selectionBg": c["selection_background"],
            "selectionFg": c["selection_foreground"],
            "url": c["url"],
            "tabActiveBg": c["tab_active_background"],
            "tabActiveFg": c["tab_active_foreground"],
            "tabInactiveBg": c["tab_inactive_background"],
            "tabInactiveFg": c["tab_inactive_foreground"],
        },
        "theme": {
            "barHeight": s["bar_height"],
            "popupGap": s["popup_gap"],
            "radius": s["radius"],
            "radiusSmall": s["radius_small"],
            "padding": s["padding"],
            "gap": s["gap"],
            "gaps": t["gaps"],
        },
        "fonts": {
            "shell": f["shell_font"],
            "ui": f["shell_font"],
            "uiSize": f["ui_size"],
            "iconSize": s["icon_size"],
            "terminal": f["shell_font"],
            "terminalSize": f["terminal_size"],
        },
        "toolkit": {
            "font": toolkit["font"],
            "size": toolkit["size"],
            "inheritTheme": toolkit["inherit_theme"],
        },
        "apps": {
            "terminal": a["terminal"],
            "fileManager": a["file_manager"],
            "menu": a["menu"],
            "wallpaperDir": a["wallpaper_dir"],
            "wallpaperPicker": a["wallpaper_picker"],
        },
        "terminal": {
            "opacity": app["opacity"],
            "padding": app["padding"],
            "cursorShape": app["cursor_shape"],
            "scrollback": app["scrollback"],
        },
    }
    return json.dumps(data, indent=2) + "\n"


def niri_color(value: str) -> str:
    """Convert Kuro hex or rgb()/rgba() colors to Niri's #RRGGBBAA form."""
    text = str(value).strip().lower()
    if text.startswith("0x") and len(text) == 10:
        return f"#{text[4:]}{text[2:4]}"
    if text.startswith("rgba(") and text.endswith(")"):
        text = text[5:-1]
    elif text.startswith("rgb(") and text.endswith(")"):
        text = text[4:-1]
    else:
        text = text.lstrip("#")
    if len(text) == 6:
        text += "ff"
    if len(text) != 8 or not re.fullmatch(r"[0-9a-f]{8}", text):
        return "#ffffffff"
    return f"#{text}"


def render_niri_kdl(cfg: dict) -> str:
    c, t, n, r = cfg["colors"], cfg["theme"], cfg["niri"], cfg["rules"]
    lines = [
        "// Generated by kurogen from ~/.config/kuro/kuro.toml.",
        "// Edit Kuro's theme settings and run `kurogen`; do not edit this file.",
        "",
        "layout {",
        f"    gaps {t['gaps']}",
        f'    center-focused-column "{n["center_focused_column"]}"',
    ]
    if n["border_size"] > 0:
        lines.extend([
            "    focus-ring {",
            f"        width {n['border_size']}",
            f'        active-color "{niri_color(c["active_border"])}"',
            f'        inactive-color "{niri_color(c["inactive_border"])}"',
            "    }",
        ])
    else:
        lines.append("    focus-ring { off }")
    if n["shadow"]:
        lines.extend([
            "    shadow {",
            "        on",
            f"        softness {n['shadow_range']}",
            f"        spread {n['shadow_power']}",
            f'        color "{niri_color(n["shadow_color"])}"',
            "    }",
        ])
    lines.extend(["}", ""])
    if n["rounding"] > 0:
        lines.extend([
            "window-rule {",
            f"    geometry-corner-radius {n['rounding']}",
            "    clip-to-geometry true",
            "}",
            "",
        ])
    for active, opacity in ((True, n["active_opacity"]), (False, n["inactive_opacity"])):
        if opacity < 1:
            lines.extend([
                "window-rule {",
                f"    match is-active={'true' if active else 'false'}",
                f"    opacity {opacity}",
                "}",
                "",
            ])
    if n["blur"]:
        lines.extend([
            "window-rule {",
            "    background-effect { blur true }",
            "}",
            "",
        ])
    if not n["animations"]:
        lines.extend(["animations { off }", ""])
    lines.extend([
        "overview {",
        f'    backdrop-color "{niri_color(c["shell_background"])}"',
        "}",
        "",
    ])
    for title, directives in r.items():
        if not isinstance(directives, list):
            raise KuroError(f"rules.{title} must be an array of Niri rule directives")
        if not directives:
            continue
        title_pattern = "^" + re.escape(str(title)) + "$"
        lines.extend(["window-rule {", f"    match title={json.dumps(title_pattern)}"])
        for directive in directives:
            for directive_line in str(directive).splitlines():
                lines.append(f"    {directive_line}" if directive_line else "")
        lines.extend(["}", ""])
    return "\n".join(lines)


def css_quote(value: str) -> str:
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def mix_hex(first: str, second: str, amount: float) -> str:
    """Mix two #RRGGBB colors, with amount selecting the second color."""
    a = str(first).strip().lstrip("#")[:6]
    b = str(second).strip().lstrip("#")[:6]
    if not re.fullmatch(r"[0-9a-fA-F]{6}", a) or not re.fullmatch(r"[0-9a-fA-F]{6}", b):
        return first
    channels = [
        round(int(a[i:i + 2], 16) * (1 - amount) + int(b[i:i + 2], 16) * amount)
        for i in (0, 2, 4)
    ]
    return "#" + "".join(f"{channel:02x}" for channel in channels)


def libadwaita_palette(cfg: dict) -> dict[str, str]:
    """Map Kuro's semantic palette onto libadwaita's GNOME palette variables."""
    c = cfg["colors"]
    light = cfg.get("mode") == "light"
    colors = {
        "blue": c["blue"],
        "green": c["green"],
        "yellow": c["yellow"],
        "orange": c["orange"],
        "red": c["red"],
        "purple": c["magenta"],
        "brown": c["brown"],
        "light": c["ink"],
        "dark": c["base"],
    }
    result = {}
    for name, color in colors.items():
        if name in ("light", "dark"):
            shades = [
                mix_hex(color, c["base"], 0.0),
                mix_hex(color, c["base"], 0.25),
                color,
                mix_hex(color, c["ink"], 0.25),
                mix_hex(color, c["ink"], 0.5),
            ]
        elif light:
            shades = [
                mix_hex(color, c["base"], 0.5),
                mix_hex(color, c["base"], 0.25),
                color,
                mix_hex(color, "#000000", 0.2),
                mix_hex(color, "#000000", 0.4),
            ]
        else:
            shades = [
                mix_hex(color, c["ink"], 0.5),
                mix_hex(color, c["ink"], 0.25),
                color,
                mix_hex(color, c["base"], 0.2),
                mix_hex(color, c["base"], 0.4),
            ]
        for number, shade in enumerate(shades, 1):
            result[f"--{name}-{number}"] = shade
    return result


def qt_color(value: str, fallback: str = "#ff000000") -> str:
    """Return a Qt #AARRGGBB palette value from Kuro hex colors."""
    text = str(value).strip().lower()
    if text.startswith("0x") and len(text) == 10:
        return "#" + text[2:]
    if text.startswith("#"):
        text = text[1:]
    if len(text) == 6 and re.fullmatch(r"[0-9a-f]{6}", text):
        return "#ff" + text
    if len(text) == 8 and re.fullmatch(r"[0-9a-f]{8}", text):
        return "#" + text[6:8] + text[:6]
    return fallback


def render_toolkit_gtk(cfg: dict, gtk_major: int) -> str:
    """Generate a GTK user stylesheet with Kuro colors and toolkit font."""
    c = cfg["colors"]
    toolkit = cfg["toolkit"]
    shell_font = cfg["fonts"]["shell_font"]
    css = [
        "/* Generated by kurogen; edit [toolkit] and the active Kuro theme. */",
    ]
    if toolkit["inherit_theme"]:
        if gtk_major == 3:
            base, text = c["base"], c["ink"]
            css.extend([
                f"@define-color theme_bg_color {base};",
                f"@define-color theme_fg_color {text};",
                f"@define-color theme_base_color {base};",
                f"@define-color theme_text_color {text};",
                f"@define-color theme_selected_bg_color {c['accent']};",
                f"@define-color theme_selected_fg_color {c['accent_text']};",
                f"@define-color insensitive_fg_color {c['muted']};",
                f"@define-color borders {c['inactive_border']};",
            ])
        else:
            base, text = c["base"], c["ink"]
            accent, accent_text = c["accent"], c["accent_text"]
            surface, muted = c["palette"][0], c["muted"]
            variables = {
                "--accent-bg-color": accent,
                "--accent-fg-color": accent_text,
                "--accent-color": accent,
                "--destructive-bg-color": c["hot"],
                "--destructive-fg-color": accent_text,
                "--destructive-color": c["palette"][9],
                "--success-bg-color": c["green"],
                "--success-fg-color": c["base"],
                "--success-color": c["green"],
                "--warning-bg-color": c["yellow"],
                "--warning-fg-color": c["base"],
                "--warning-color": c["yellow"],
                "--error-bg-color": c["hot"],
                "--error-fg-color": accent_text,
                "--error-color": c["palette"][9],
                "--window-bg-color": base,
                "--window-fg-color": text,
                "--view-bg-color": base,
                "--view-fg-color": text,
                "--headerbar-bg-color": surface,
                "--headerbar-fg-color": text,
                "--headerbar-border-color": c["inactive_border"],
                "--headerbar-backdrop-color": base,
                "--headerbar-shade-color": "rgba(0, 0, 0, 0.28)",
                "--headerbar-darker-shade-color": "rgba(0, 0, 0, 0.62)",
                "--sidebar-bg-color": surface,
                "--sidebar-fg-color": text,
                "--sidebar-backdrop-color": base,
                "--sidebar-border-color": c["inactive_border"],
                "--sidebar-shade-color": "rgba(0, 0, 0, 0.28)",
                "--secondary-sidebar-bg-color": c["base"],
                "--secondary-sidebar-fg-color": text,
                "--secondary-sidebar-backdrop-color": base,
                "--secondary-sidebar-border-color": c["inactive_border"],
                "--secondary-sidebar-shade-color": "rgba(0, 0, 0, 0.3)",
                "--card-bg-color": surface,
                "--card-fg-color": text,
                "--card-shade-color": "rgba(0, 0, 0, 0.25)",
                "--overview-bg-color": c["base"],
                "--overview-fg-color": text,
                "--thumbnail-bg-color": surface,
                "--thumbnail-fg-color": text,
                "--active-toggle-bg-color": accent,
                "--active-toggle-fg-color": accent_text,
                "--dialog-bg-color": surface,
                "--dialog-fg-color": text,
                "--popover-bg-color": surface,
                "--popover-fg-color": text,
                "--popover-shade-color": "rgba(0, 0, 0, 0.3)",
                "--shade-color": "rgba(0, 0, 0, 0.25)",
                "--scrollbar-outline-color": c["ink"] if cfg.get("mode") == "dark" else c["base"],
                "--document-font-family": css_quote(toolkit["font"]),
                "--document-font-size": f"{toolkit['size']}pt",
                "--monospace-font-family": css_quote(shell_font),
                "--monospace-font-size": "11pt",
                "--accent-blue": c["blue"],
                "--accent-teal": c["cyan"],
                "--accent-green": c["green"],
                "--accent-yellow": c["yellow"],
                "--accent-orange": c["orange"],
                "--accent-red": c["red"],
                "--accent-pink": c["magenta"],
                "--accent-purple": c["magenta"],
                "--accent-slate": c["muted"],
            }
            variables.update(libadwaita_palette(cfg))
            css.append(":root {")
            css.extend(f"  {name}: {value};" for name, value in variables.items())
            css.append("}")
            # Older GTK/libadwaita apps still use these GTK named colors.
            css.extend([
                f"@define-color theme_bg_color {base};",
                f"@define-color theme_fg_color {text};",
                f"@define-color theme_base_color {base};",
                f"@define-color theme_text_color {text};",
                f"@define-color theme_selected_bg_color {accent};",
                f"@define-color theme_selected_fg_color {accent_text};",
                f"@define-color insensitive_bg_color {surface};",
                f"@define-color insensitive_fg_color {muted};",
                f"@define-color insensitive_base_color {base};",
                f"@define-color borders {c['inactive_border']};",
                f"@define-color theme_unfocused_bg_color {base};",
                f"@define-color theme_unfocused_fg_color {text};",
                f"@define-color theme_unfocused_base_color {base};",
                f"@define-color theme_unfocused_text_color {text};",
                f"@define-color theme_unfocused_selected_bg_color {accent};",
                f"@define-color theme_unfocused_selected_fg_color {accent_text};",
                f"@define-color unfocused_insensitive_color {muted};",
                f"@define-color unfocused_borders {c['inactive_border']};",
            ])
            css.extend([
                f"window, dialog {{ background-color: {base}; color: {text}; }}",
                f"view, textview, entry {{ background-color: {base}; color: {text}; }}",
                f"*:disabled {{ color: {muted}; }}",
            ])
    return "\n".join(css) + "\n"


def qt_color_groups(cfg: dict) -> dict[str, list[str]]:
    c = cfg["colors"]
    palette = c["palette"]
    accent = c["accent"]
    accent_text = c["accent_text"]
    active = [
        c["ink"], palette[8], palette[15], palette[8], c["base"], palette[8],
        c["ink"], palette[15], c["ink"], c["base"], c["base"], c["base"],
        accent, accent_text, c["blue"], c["magenta"], palette[0], c["ink"],
        palette[0], c["ink"], c["muted"], accent,
    ]
    inactive = [
        c["muted"], palette[8], palette[15], palette[8], c["base"], palette[8],
        c["muted"], palette[15], c["muted"], c["base"], c["base"], c["base"],
        accent, accent_text, c["blue"], c["magenta"], palette[0], c["muted"],
        palette[0], c["muted"], c["muted"], accent,
    ]
    disabled = [
        c["muted"], palette[0], palette[8], palette[0], c["base"], palette[0],
        c["muted"], palette[8], c["muted"], c["base"], c["base"], c["base"],
        palette[8], c["muted"], c["blue"], c["magenta"], palette[0], c["muted"],
        palette[0], c["muted"], c["muted"], palette[8],
    ]
    return {
        "active_colors": active,
        "inactive_colors": inactive,
        "disabled_colors": disabled,
    }


def render_toolkit_qt_colors(cfg: dict) -> str:
    groups = qt_color_groups(cfg)
    lines = ["[ColorScheme]"]
    for name, values in groups.items():
        lines.append(f"{name}=" + ", ".join(qt_color(value) for value in values))
    return "\n".join(lines) + "\n"


def render_toolkit_qt_config(cfg: dict, qt_major: int, colors_path: Path) -> str:
    toolkit = cfg["toolkit"]
    inherited = toolkit["inherit_theme"]
    font = toolkit["font"].replace("\\", "\\\\").replace('"', '\\"')
    scheme_path = str(colors_path) if inherited else ""
    return (
        "[Appearance]\n"
        f"custom_palette={'true' if inherited else 'false'}\n"
        f"color_scheme_path={scheme_path}\n"
        "standard_dialogs=default\n"
        "style=Fusion\n\n"
        "[Fonts]\n"
        f'general="{font},{toolkit["size"]},-1,5,50,0,0,0,0,0"\n'
        f'fixed="{font},{toolkit["size"]},-1,5,50,0,0,0,0,0"\n'
    )


def render_neovim_theme(cfg: dict) -> str:
    """Render a Neovim colorscheme from Kuro's active semantic palette."""
    c, p = cfg["colors"], cfg["colors"]["palette"]
    groups = {
        "Normal": {"fg": c["ink"], "bg": c["base"]},
        "NormalFloat": {"fg": c["ink"], "bg": p[0]},
        "FloatBorder": {"fg": c["muted"], "bg": p[0]},
        "Cursor": {"fg": c["cursor_text"], "bg": c["cursor"]},
        "CursorLine": {"bg": p[0]},
        "LineNr": {"fg": c["muted"]},
        "CursorLineNr": {"fg": c["accent"], "bold": True},
        "Visual": {"fg": c["selection_foreground"], "bg": c["selection_background"]},
        "Search": {"fg": c["selection_foreground"], "bg": c["selection_background"]},
        "IncSearch": {"fg": c["cursor_text"], "bg": c["cursor"]},
        "Pmenu": {"fg": c["ink"], "bg": p[0]},
        "PmenuSel": {"fg": c["accent_text"], "bg": c["accent"], "bold": True},
        "StatusLine": {"fg": c["accent_text"], "bg": c["accent"], "bold": True},
        "StatusLineNC": {"fg": c["muted"], "bg": p[0]},
        "WinSeparator": {"fg": c["inactive_border"]},
        "Comment": {"fg": c["muted"], "italic": True},
        "String": {"fg": p[2]},
        "Character": {"fg": p[2]},
        "Number": {"fg": p[3]},
        "Boolean": {"fg": p[3]},
        "Constant": {"fg": p[3]},
        "Identifier": {"fg": c["ink"]},
        "Function": {"fg": p[4]},
        "Statement": {"fg": c["accent"], "bold": True},
        "Conditional": {"fg": c["accent"], "bold": True},
        "Repeat": {"fg": c["accent"], "bold": True},
        "Operator": {"fg": c["muted"]},
        "Keyword": {"fg": c["accent"], "bold": True},
        "PreProc": {"fg": p[5]},
        "Type": {"fg": p[6]},
        "Special": {"fg": p[4]},
        "Todo": {"fg": c["cursor_text"], "bg": c["cursor"], "bold": True},
        "DiagnosticError": {"fg": c["hot"]},
        "DiagnosticWarn": {"fg": c["yellow"]},
        "DiagnosticInfo": {"fg": c["blue"]},
        "DiagnosticHint": {"fg": c["cyan"]},
        "DiffAdd": {"fg": c["green"]},
        "DiffDelete": {"fg": c["hot"]},
        "DiffChange": {"fg": c["yellow"]},
        "GitSignsAdd": {"fg": c["green"]},
        "GitSignsChange": {"fg": c["yellow"]},
        "GitSignsDelete": {"fg": c["hot"]},
    }
    lines = [
        "-- Generated by kurogen from the active Kuro palette.",
        "vim.cmd('highlight clear')",
        "if vim.fn.exists('syntax_on') == 1 then vim.cmd('syntax reset') end",
        "vim.g.colors_name = 'kuro'",
        "local groups = {",
    ]
    for name, style in groups.items():
        attrs = ", ".join(f"{key} = {json.dumps(value)}" for key, value in style.items())
        lines.append(f"  {name} = {{ {attrs} }},")
    lines.extend([
        "}",
        "for name, opts in pairs(groups) do vim.api.nvim_set_hl(0, name, opts) end",
        "",
    ])
    return "\n".join(lines)


def render_zsh_colors(cfg: dict) -> str:
    """Expose the active Kuro palette as safe Zsh prompt color variables."""
    colors = cfg["colors"]

    def color(value: object, fallback: str) -> str:
        text = str(value)
        return text.lower() if re.fullmatch(r"#[0-9a-fA-F]{6}", text) else fallback

    values = {
        "KURO_PROMPT_BG": color(colors.get("base"), "#151515"),
        "KURO_PROMPT_FG": color(colors.get("ink"), "#dedede"),
        "KURO_PROMPT_ACCENT": color(colors.get("accent"), "#97bedc"),
        "KURO_PROMPT_HOT": color(colors.get("hot"), "#e27373"),
        "KURO_PROMPT_BLUE": color(colors.get("palette", [])[4] if len(colors.get("palette", [])) > 4 else None, "#97bedc"),
        "KURO_PROMPT_MUTED": color(colors.get("palette", [])[8] if len(colors.get("palette", [])) > 8 else None, "#888888"),
        "KURO_PROMPT_GREEN": color(colors.get("palette", [])[2] if len(colors.get("palette", [])) > 2 else None, "#94b979"),
        "KURO_PROMPT_YELLOW": color(colors.get("palette", [])[3] if len(colors.get("palette", [])) > 3 else None, "#ffba7b"),
        "KURO_PROMPT_MAGENTA": color(colors.get("palette", [])[5] if len(colors.get("palette", [])) > 5 else None, "#e1c0fa"),
        "KURO_PROMPT_RULE": "#333333",
    }
    return "# Generated by kurogen.\n" + "".join(f"typeset -g {key}='{value}'\n" for key, value in values.items())


def render_flea_colors(cfg: dict) -> str:
    """Export Kuro's active palette in Flea's semantic colors.toml format."""
    colors = cfg["colors"]
    palette = colors["palette"]
    values = {
        "background": colors["base"],
        "dark_background": palette[0],
        "darker_background": palette[0],
        "lighter_background": colors.get("lighter_background", palette[0]),
        "foreground": colors["ink"],
        "bright_foreground": palette[15],
        "dark_foreground": palette[8],
        "muted": palette[8],
        "accent": colors["accent"],
        "selection": colors["selection_background"],
        "red": palette[1],
        "orange": palette[3],
        "yellow": palette[3],
        "green": palette[2],
        "blue": palette[4],
        "magenta": palette[5],
        "cyan": palette[6],
        "bright_red": palette[9],
        "bright_yellow": palette[11],
        "bright_green": palette[10],
        "bright_blue": palette[12],
        "bright_magenta": palette[13],
        "bright_cyan": palette[14],
        "urgent": colors["hot"],
    }
    lines = ["# Generated by kurogen from ~/.config/kuro/kuro.toml."]
    lines.extend(f"{key} = {toml_value(value)}" for key, value in values.items())
    return "\n".join(lines) + "\n"


def render_flea_shell(cfg: dict) -> str:
    """Keep Flea's UI sizing aligned with Kuro's selected UI font size."""
    return (
        "# Generated by kurogen from ~/.config/kuro/kuro.toml.\n"
        "[font]\n"
        f"base-size = {int(cfg['fonts']['ui_size'])}\n"
    )


def render_kitty_conf(cfg: dict) -> str:
    c, f, t = cfg["colors"], cfg["fonts"], cfg["theme"]
    term = cfg["terminal"]
    lines = [
        "# Generated by kurogen from ~/.config/kuro/kuro.toml.",
        "# Do not edit by hand: change kuro.toml and run `kurogen`.",
        "",
        f"font_family      {f['shell_font']}",
        "bold_font        auto",
        "italic_font      auto",
        "bold_italic_font auto",
        f"font_size        {f['terminal_size']}",
        "",
        f"background_opacity    {term['opacity']}",
        f"window_padding_width  {term['padding']}",
        f"cursor_shape          {term['cursor_shape']}",
        "cursor_blink_interval 0",
        f"scrollback_lines      {term['scrollback']}",
        "",
        f"cursor            {c['cursor']}",
        f"cursor_text_color {c['cursor_text']}",
        "",
        f"selection_foreground {c['selection_foreground']}",
        f"selection_background {c['selection_background']}",
        "",
        f"foreground {c['ink']}",
        f"background {c['base']}",
        "",
    ]
    for i, color in enumerate(c["palette"]):
        lines.append(f"color{i} {color}")
    lines += [
        "",
        f"url_color {c['url']}",
        f"active_tab_foreground   {c['tab_active_foreground']}",
        f"active_tab_background   {c['tab_active_background']}",
        f"inactive_tab_foreground {c['tab_inactive_foreground']}",
        f"inactive_tab_background {c['tab_inactive_background']}",
        "",
    ]
    return "\n".join(lines)


def generate(cfg: dict) -> list[str]:
    changed = []
    if write_if_changed(THEME_JSON, render_theme_json(cfg)):
        changed.append(str(THEME_JSON))
    if write_if_changed(ZSH_COLORS, render_zsh_colors(cfg)):
        changed.append(str(ZSH_COLORS))
    # Flea is disabled in this setup; keep the renderers for reference only.
    # if write_if_changed(FLEA_COLORS, render_flea_colors(cfg)):
    #     changed.append(str(FLEA_COLORS))
    # if write_if_changed(FLEA_SHELL, render_flea_shell(cfg)):
    #     changed.append(str(FLEA_SHELL))
    # if write_if_changed(FLEA_FONT_FAMILY, str(cfg["fonts"]["shell_font"]) + "\n"):
    #     changed.append(str(FLEA_FONT_FAMILY))
    if write_if_changed(NIRI_KDL, render_niri_kdl(cfg)):
        changed.append(str(NIRI_KDL))
    if write_if_changed(KITTY_CONF, render_kitty_conf(cfg)):
        changed.append(str(KITTY_CONF))
    if write_if_changed(NVIM_THEME, render_neovim_theme(cfg)):
        changed.append(str(NVIM_THEME))
    for path, major in ((GTK3_CSS, 3), (GTK4_CSS, 4)):
        if write_if_changed(path, render_toolkit_gtk(cfg, major)):
            changed.append(str(path))
    for config_path, colors_path, major in (
        (QT5_CONFIG, QT5_COLORS, 5),
        (QT6_CONFIG, QT6_COLORS, 6),
    ):
        if cfg["toolkit"]["inherit_theme"] and write_if_changed(colors_path, render_toolkit_qt_colors(cfg)):
            changed.append(str(colors_path))
        if write_if_changed(config_path, render_toolkit_qt_config(cfg, major, colors_path)):
            changed.append(str(config_path))
    return changed


# ── one-value edit (used by the Appearance page / launcher) ──────────
def _split_comment(rest: str) -> tuple[str, str]:
    """Split `value  # comment` while respecting quoted strings."""
    quote = None
    escaped = False
    for i, ch in enumerate(rest):
        if escaped:
            escaped = False
            continue
        if ch == "\\" and quote:
            escaped = True
            continue
        if quote:
            if ch == quote:
                quote = None
            continue
        if ch in ('"', "'"):
            quote = ch
        elif ch == "#":
            return rest[:i].rstrip(), rest[i:].rstrip()
    return rest.strip(), ""


def coerce_like(old, raw: str):
    if isinstance(old, bool):
        low = raw.strip().lower()
        if low in ("true", "yes", "on", "1"):
            return True
        if low in ("false", "no", "off", "0"):
            return False
        raise KuroError(f"expected a boolean, got {raw!r}")
    if isinstance(old, int) and not isinstance(old, bool):
        return int(raw, 0)
    if isinstance(old, float):
        return float(raw)
    if isinstance(old, str):
        value = raw.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
            value = value[1:-1]
        return value
    raise KuroError("refusing to change an unknown value type")


def set_values(pairs: list[tuple[str, str]]) -> None:
    """Edit one or more values in kuro.toml while preserving comments."""
    cfg = load()
    text = CONFIG.read_text(encoding="utf-8")
    lines = text.splitlines()

    for dotted, raw in pairs:
        try:
            section, key = dotted.split(".", 1)
        except ValueError:
            raise KuroError(f"expected <section>.<key>, got {dotted!r}")
        if section not in cfg or key not in cfg[section]:
            raise KuroError(f"unknown setting: {dotted}")
        value = coerce_like(cfg[section][key], raw)

        header = f"[{section}]"
        start = None
        end = len(lines)
        for i, line in enumerate(lines):
            if line.strip() == header:
                start = i
                for j in range(i + 1, len(lines)):
                    if lines[j].lstrip().startswith("["):
                        end = j
                        break
                break
        if start is None:
            raise KuroError(f"section [{section}] not found in {CONFIG}")

        pattern = re.compile(rf"^(\s*){re.escape(key)}(\s*)=")
        target = None
        for i in range(start + 1, end):
            if pattern.match(lines[i]):
                target = i
                break
        if target is None:
            raise KuroError(f"key {key!r} not found in [{section}]")

        match = pattern.match(lines[target])
        indent = match.group(1) if match else ""
        rest = lines[target][match.end():] if match else ""
        _, comment = _split_comment(rest)
        new_line = f"{indent}{key} = {toml_value(value)}"
        if comment:
            new_line += "  " + comment
        lines[target] = new_line

    updated = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
    # Validate before writing.
    try:
        tomllib.loads(updated)
    except tomllib.TOMLDecodeError as exc:
        raise KuroError(f"edit would produce invalid TOML: {exc}")
    CONFIG.write_text(updated, encoding="utf-8")


def set_value(dotted: str, raw: str) -> None:
    set_values([(dotted, raw)])


def add_window_rule(title: str, directives: list[str]) -> None:
    """Add Niri KDL rule directives for an exact window-title match."""
    if not title.strip():
        raise KuroError("window title cannot be empty")
    if not directives or any(not directive.strip() for directive in directives):
        raise KuroError("provide at least one non-empty Niri rule directive")

    cfg = load()
    existing = cfg["rules"].get(title, [])
    if not isinstance(existing, list):
        raise KuroError(f"rules.{title} is not a list of Niri rule directives")
    updated_rules = existing + directives

    text = CONFIG.read_text(encoding="utf-8")
    lines = text.splitlines()
    header = "[rules]"
    start = next((i for i, line in enumerate(lines) if line.strip() == header), None)
    if start is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend([header, "# Per-window Niri rules are added with `kurogen window`."])
        start = len(lines) - 2

    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].lstrip().startswith("["):
            end = i
            break

    key = json.dumps(title, ensure_ascii=False)
    key_pattern = re.compile(rf"^\s*{re.escape(key)}\s*=")
    target = next((i for i in range(start + 1, end) if key_pattern.match(lines[i])), None)
    assignment = f"{key} = {toml_value(updated_rules)}"
    if target is not None:
        lines[target] = assignment
    else:
        lines.insert(end, assignment)

    updated = "\n".join(lines) + ("\n" if text.endswith("\n") or not text else "")
    try:
        tomllib.loads(updated)
    except tomllib.TOMLDecodeError as exc:
        raise KuroError(f"window rule would produce invalid TOML: {exc}")
    CONFIG.write_text(updated, encoding="utf-8")


# ── entry point ──────────────────────────────────────────────────────
def main(argv: list[str]) -> int:
    try:
        if len(argv) > 1 and argv[1] == "path":
            print(CONFIG)
            return 0
        if len(argv) > 1 and argv[1] == "themes":
            cfg = load()
            for item in cfg["schemes"]:
                mark = "*" if item["id"] == cfg["scheme"] else " "
                print(f"{mark} {item['id']:<20} {item['name']}")
            return 0
        if len(argv) > 1 and argv[1] == "scheme":
            if len(argv) != 3:
                raise KuroError("usage: kurogen scheme <name>")
            set_value("theme.scheme", argv[2])
        elif len(argv) > 1 and argv[1] == "set":
            rest = argv[2:]
            if len(rest) < 2 or len(rest) % 2 != 0:
                raise KuroError(
                    "usage: kurogen set <section.key> <value> "
                    "[<section.key> <value> ...]")
            set_values(list(zip(rest[0::2], rest[1::2])))
        elif len(argv) > 1 and argv[1] == "window":
            if len(argv) < 4:
                raise KuroError('usage: kurogen window "<title>" "<Niri rule>" ["<Niri rule>" ...]')
            add_window_rule(argv[2], argv[3:])
        elif len(argv) > 1 and argv[1] not in ("generate", "apply"):
            raise KuroError(f"unknown command: {argv[1]}")

        cfg = load()
        changed = generate(cfg)
        for path in changed:
            print(f"kuro: wrote {path}")
        if not changed:
            print("kuro: configs already up to date")
        return 0
    except KuroError as exc:
        print(f"kurogen: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
