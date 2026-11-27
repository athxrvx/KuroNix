pragma Singleton

import qs.modules.launcher
import qs.modules.controlcenter
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

Searcher {
    id: root

    readonly property list<QtObject> actions: [
        Action {
            name: qsTr("Settings")
            desc: qsTr("Open the configuration editor")
            icon: "settings"
            keywords: "config preferences kuro"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                WindowFactory.create();
            }
        },
        Action {
            name: qsTr("Calculator")
            desc: qsTr("Do simple math equations (powered by Qalc)")
            icon: "calculate"
            keywords: "calc math qalc"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "calc");
            }
        },
        Action {
            name: qsTr("Scheme")
            desc: qsTr("Change the current colour scheme")
            icon: "palette"
            keywords: "theme colorscheme colourscheme"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "scheme");
            }
        },
        Action {
            name: qsTr("Wallpaper")
            desc: qsTr("Change the current wallpaper")
            icon: "image"
            keywords: "background set wallpaper"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "wallpaper");
            }
        },
        Action {
            name: qsTr("Clipboard")
            desc: qsTr("Search clipboard history")
            icon: "content_paste"
            keywords: "clip history paste"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "clip");
            }
        },
        Action {
            name: qsTr("Web Search")
            desc: qsTr("Search the web or open a URL")
            icon: "travel_explore"
            keywords: "search url browser"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "web");
            }
        },
        Action {
            name: qsTr("Emoji")
            desc: qsTr("Search and copy emojis")
            icon: "mood"
            keywords: "emojis smileys"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "emoji");
            }
        },
        Action {
            name: qsTr("Distrobox")
            desc: qsTr("Browse and enter containers")
            icon: "deployed_code"
            keywords: "containers container podman"

            function onClicked(list: AppList): void {
                root.autocomplete(list, "distrobox");
            }
        },
        Action {
            name: qsTr("OCR")
            desc: qsTr("Extract text from a screen region")
            icon: "document_scanner"
            keywords: "text recognition screen text"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                const configName = Quickshell.shellDir.toString().replace(/\/$/, "").split("/").pop();
                Quickshell.execDetached(["qs", "-c", configName, "ipc", "call", "picker", "regionOcr"]);
            }
        },
        Action {
            name: qsTr("Random")
            desc: qsTr("Switch to a random wallpaper")
            icon: "casino"
            keywords: "shuffle random wallpaper"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                // Get a random wallpaper from the Wallpapers service
                const wallpaperList = Wallpapers.list;
                if (wallpaperList && wallpaperList.length > 0) {
                    const randomIndex = Math.floor(Math.random() * wallpaperList.length);
                    const randomWallpaper = wallpaperList[randomIndex];
                    if (randomWallpaper && randomWallpaper.path) {
                        Wallpapers.setWallpaper(randomWallpaper.path);
                    }
                } else {
                    Toaster.toast(qsTr("No wallpapers found"), qsTr("Add wallpapers to your configured wallpaper folder first."), "wallpaper_slideshow", Toast.Warning);
                }
            }
        },
        Action {
            name: qsTr("Light")
            desc: qsTr("Change the scheme to light mode")
            icon: "light_mode"
            keywords: "light mode day"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                Colours.setMode("light");
                Schemes.regenerateDynamic();
            }
        },
        Action {
            name: qsTr("Dark")
            desc: qsTr("Change the scheme to dark mode")
            icon: "dark_mode"
            keywords: "dark mode night"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                Colours.setMode("dark");
                Schemes.regenerateDynamic();
            }
        },
        Action {
            name: qsTr("Shutdown")
            desc: qsTr("Shutdown the system")
            icon: "power_settings_new"
            keywords: "power off poweroff"
            disabled: !Config.launcher.enableDangerousActions

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                Quickshell.execDetached(["systemctl", "poweroff"]);
            }
        },
        Action {
            name: qsTr("Reboot")
            desc: qsTr("Reboot the system")
            icon: "cached"
            keywords: "restart reboot"
            disabled: !Config.launcher.enableDangerousActions

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                Quickshell.execDetached(["systemctl", "reboot"]);
            }
        },
        Action {
            name: qsTr("Logout")
            desc: qsTr("Log out of the current session")
            icon: "exit_to_app"
            keywords: "quit exit sign out"
            disabled: !Config.launcher.enableDangerousActions

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                Quickshell.execDetached(["niri", "msg", "action", "quit", "-s"]);
            }
        },
        Action {
            name: qsTr("Lock")
            desc: qsTr("Lock the current session")
            icon: "lock"
            keywords: "lock screen"

            function onClicked(list: AppList): void {
                list.visibilities.launcher = false;
                const configName = Quickshell.shellDir.toString().replace(/\/$/, "").split("/").pop();
                Quickshell.execDetached(["qs", "-c", configName, "ipc", "call", "lock", "lock"]);
            }
        }
    ]

    function transformSearch(search: string): string {
        return search.slice(Config.launcher.actionPrefix.length);
    }

    function autocomplete(list: AppList, text: string): void {
        list.search.text = `${Config.launcher.actionPrefix}${text} `;
    }

    list: actions.filter(a => !a.disabled)
    useFuzzy: Config.launcher.useFuzzy.actions
    keys: ["name", "keywords"]
    weights: [0.75, 0.25]
    function selector(item: var): string {
        return `${item.name} ${item.keywords || ""}`;
    }

    component Action: QtObject {
        required property string name
        required property string desc
        required property string icon
        property bool disabled
        property string keywords: ""

        function onClicked(list: AppList): void {
        }
    }
}
