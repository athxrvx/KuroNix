pragma Singleton

import Quickshell
import qs.services

Singleton {
    // Literally just here to shorten accessing stuff :woe:
    // Also kinda so I can keep accessing it with `Appearance.xxx` instead of `Config.appearance.xxx`
    readonly property AppearanceConfig.Rounding rounding: Config.appearance.rounding
    readonly property AppearanceConfig.Spacing spacing: Config.appearance.spacing
    readonly property AppearanceConfig.Padding padding: Config.appearance.padding
    readonly property var font: ({
        family: ({
            sans: KuroTheme.shellFamily,
            mono: KuroTheme.shellFamily,
            material: Config.appearance.font.family.material,
            clock: Config.appearance.font.family.clock
        }),
        size: Config.appearance.font.size
    })
    readonly property AppearanceConfig.Anim anim: Config.appearance.anim
    readonly property AppearanceConfig.Transparency transparency: Config.appearance.transparency
}
