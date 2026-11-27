pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string themePath: `${Paths.home}/.cache/kuro/theme.json`
    property var data: ({})
    readonly property bool ready: Object.keys(data).length > 0
    readonly property string mode: data.mode || "dark"
    readonly property var fonts: data.fonts || ({})
    readonly property string shellFamily: fonts.shell || fonts.ui || fonts.terminal || "JetBrainsMono Nerd Font"
    readonly property string toolkitFont: (data.toolkit || {}).font || "Fira Sans"
    readonly property int toolkitFontSize: (data.toolkit || {}).size || 10

    function reload(): void {
        themeFile.reload();
    }

    FileView {
        id: themeFile
        path: root.themePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text());
            } catch (e) {
                console.error("KuroTheme: generated Kuro theme is invalid:", e);
            }
        }
    }
}
