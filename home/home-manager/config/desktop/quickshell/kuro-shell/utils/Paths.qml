pragma Singleton

import qs.config
import KuroShell
import Quickshell

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string pictures: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`

    readonly property string data: `${Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`}/kuro-shell`
    readonly property string state: `${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/kuro-shell`
    readonly property string cache: `${Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`}/kuro-shell`
    readonly property string config: `${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/kuro-shell`
    readonly property string kuroConfig: `${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/kuro`

    readonly property string imagecache: `${cache}/imagecache`
    readonly property string notificationsData: `${data}/notifications.json`
    readonly property string wallsdir: Quickshell.env("KURO_SHELL_WALLPAPERS_DIR") || absolutePath(Config.paths.wallpaperDir)
    readonly property string recordings: `${home}/Videos/Recordings`
    readonly property string libdir: Quickshell.env("KURO_SHELL_LIB_DIR") || "/usr/lib/kuro-shell"

    function toLocalFile(path: url): string {
        path = Qt.resolvedUrl(path);
        return path.toString() ? CUtils.toLocalFile(path) : "";
    }

    function absolutePath(path: string): string {
        return toLocalFile(path.replace("~", home));
    }

    function shortenHome(path: string): string {
        return path.replace(home, "~");
    }
}
