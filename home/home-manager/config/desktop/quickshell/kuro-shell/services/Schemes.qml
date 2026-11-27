pragma Singleton

import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
    id: root

    property string currentScheme: ""
    property string currentVariant: "default"
    readonly property string themePath: `${Paths.home}/.cache/kuro/theme.json`

    function transformSearch(search: string): string {
        return search.slice(`${Config.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return `${item.name} ${item.flavour}`;
    }

    function reload(): void {
        themeFile.reload();
    }

    function schemeColours(data: var): var {
        const colors = data.colors || {};
        const p = colors.palette || [];
        const raw = {
            mode: data.mode || "dark",
            base00: colors.shellBackground || colors.base || p[0],
            base01: p[0],
            base02: colors.tabInactiveBg || p[0],
            base03: p[8],
            base04: p[8],
            base05: colors.ink || p[7],
            base06: p[7],
            base07: p[15] || p[7],
            base08: p[1],
            base09: p[3],
            base0A: p[3],
            base0B: p[2],
            base0C: p[6],
            base0D: p[4],
            base0E: p[5],
            base0F: colors.accent || p[5]
        };
        for (const key of Object.keys(raw)) {
            if (key !== "mode" && typeof raw[key] === "string")
                raw[key] = raw[key].replace(/^#/, "");
        }
        return base16Colours(raw);
    }

    function base16Colours(palette: var): var {
        const light = palette.mode === "light";
        const foreground = palette.base05;
        const background = palette.base00;
        const buttonForeground = light ? palette.base07 : palette.base00;
        const container = light ? palette.base01 : palette.base02;
        const softContainer = light ? palette.base02 : palette.base01;

        const result = {
            primary_paletteKeyColor: palette.base0D,
            secondary_paletteKeyColor: palette.base0B,
            tertiary_paletteKeyColor: palette.base09,
            neutral_paletteKeyColor: palette.base03,
            neutral_variant_paletteKeyColor: palette.base04,
            background, onBackground: foreground,
            surface: background, surfaceDim: background,
            surfaceBright: palette.base02,
            surfaceContainerLowest: light ? palette.base07 : background,
            surfaceContainerLow: palette.base01,
            surfaceContainer: palette.base01,
            surfaceContainerHigh: palette.base02,
            surfaceContainerHighest: light ? palette.base02 : palette.base03,
            onSurface: foreground,
            surfaceVariant: palette.base02,
            onSurfaceVariant: palette.base04,
            inverseSurface: foreground,
            inverseOnSurface: background,
            outline: palette.base03,
            outlineVariant: palette.base02,
            shadow: background, scrim: background,
            surfaceTint: palette.base0D,
            primary: palette.base0D, onPrimary: buttonForeground,
            primaryContainer: container,
            onPrimaryContainer: light ? palette.base07 : foreground,
            inversePrimary: palette.base04,
            secondary: palette.base0B, onSecondary: buttonForeground,
            secondaryContainer: container,
            onSecondaryContainer: light ? palette.base07 : foreground,
            tertiary: palette.base09, onTertiary: buttonForeground,
            tertiaryContainer: container,
            onTertiaryContainer: light ? palette.base07 : foreground,
            error: palette.base08, onError: buttonForeground,
            errorContainer: container,
            onErrorContainer: light ? palette.base07 : foreground,
            primaryFixed: palette.base0D,
            primaryFixedDim: palette.base0D,
            onPrimaryFixed: buttonForeground,
            onPrimaryFixedVariant: buttonForeground,
            secondaryFixed: palette.base0B,
            secondaryFixedDim: palette.base0B,
            onSecondaryFixed: buttonForeground,
            onSecondaryFixedVariant: buttonForeground,
            tertiaryFixed: palette.base09,
            tertiaryFixedDim: palette.base09,
            onTertiaryFixed: buttonForeground,
            onTertiaryFixedVariant: buttonForeground,
            term0: palette.base00, term1: palette.base08,
            term2: palette.base0B, term3: palette.base09,
            term4: palette.base0D, term5: palette.base0E,
            term6: palette.base0C, term7: palette.base05,
            term8: palette.base03, term9: palette.base08,
            term10: palette.base0B, term11: palette.base0A,
            term12: palette.base0D, term13: palette.base0E,
            term14: palette.base0C, term15: palette.base07,
            base: background, success: palette.base0B,
            onSuccess: buttonForeground, warning: palette.base0A,
            info: palette.base0D, error: palette.base08
        };
        Object.assign(result, {
            archBlue: palette.base0D,
            success: palette.base0B,
            m3success: palette.base0B,
            warning: palette.base0A,
            m3warning: palette.base0A,
            info: palette.base0D,
            m3info: palette.base0D,
            error: palette.base08,
            m3error: palette.base08,
            rosewater: palette.base07,
            flamingo: palette.base08,
            pink: palette.base0E,
            mauve: palette.base0E,
            red: palette.base08,
            maroon: palette.base08,
            peach: palette.base09,
            yellow: palette.base0A,
            green: palette.base0B,
            teal: palette.base0C,
            sky: palette.base0C,
            sapphire: palette.base0D,
            blue: palette.base0D,
            lavender: palette.base0E
        });
        return result;
    }

    function setScheme(name: string, flavour: string): void {
        if (flavour !== "default" || !name)
            return;
        applySchemeProcess.command = ["kurogen", "set", "theme.scheme", name];
        applySchemeProcess.running = true;
    }

    function setVariant(variant: string): void {
        // Kuro's scheme selection is the only palette authority.
        if (variant !== "default")
            console.info("Color variants are managed by Kuro themes.");
    }

    function regenerateDynamic(): void {
        // Wallpaper changes do not replace the active Kuro theme.
    }

    list: schemes.instances
    useFuzzy: Config.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes
        Scheme {}
    }

    FileView {
        id: themeFile
        path: root.themePath
        watchChanges: true

        onLoaded: {
            try {
                const data = JSON.parse(text());
                const name = data.scheme || "jellybeans";
                root.currentScheme = `${name} default`;
                root.currentVariant = "default";

                const material = root.schemeColours(data);
                Colours.load(JSON.stringify({
                    name,
                    flavour: "default",
                    mode: data.mode || "dark",
                    colours: material
                }), false);

                const schemesData = (data.schemes || []).map(item => {
                    const palette = item.palette || [];
                    return {
                        name: item.id,
                        flavour: "default",
                        colours: {
                            surface: (palette[0] || "#101010").replace(/^#/, ""),
                            outline: (palette[8] || "#808080").replace(/^#/, ""),
                            primary: (palette[4] || "#808080").replace(/^#/, "")
                        }
                    };
                });
                schemes.model = schemesData;
            } catch (e) {
                console.error("Could not read Kuro's generated theme:", e);
            }
        }

        onFileChanged: reload()
    }

    Process {
        id: applySchemeProcess
        running: false
        stderr: SplitParser { onRead: data => console.warn("kurogen:", data) }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.error("Kuro could not apply the requested theme.");
        }
    }

    Process {
        id: setModeProcess
        running: false
        stderr: SplitParser { onRead: data => console.warn("kurogen:", data) }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.error("Kuro could not apply the requested mode.");
        }
    }

    function setMode(mode: string): void {
        setModeProcess.command = ["kurogen", "set", "theme.mode", mode];
        setModeProcess.running = true;
    }

    component Scheme: QtObject {
        required property var modelData
        readonly property string name: modelData.name
        readonly property string flavour: modelData.flavour
        readonly property var colours: modelData.colours

        function onClicked(list: var): void {
            list.visibilities.launcher = false;
            root.setScheme(name, flavour);
        }
    }
}
