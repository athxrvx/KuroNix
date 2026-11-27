pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("Fonts")
    showBackground: true

    property string pendingSetting: ""
    property string pendingValue: ""

    function setKuroFont(setting: string, value: string): void {
        pendingSetting = setting;
        pendingValue = value;
        kurogen.running = true;
    }

    Process {
        id: kurogen
        command: ["kurogen", "set", root.pendingSetting, root.pendingValue]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                KuroTheme.reload();
            } else {
                console.error("Kurogen failed to update font setting:", kurogenError.text, exitCode, exitStatus);
            }
        }
        stderr: StdioCollector { id: kurogenError }
    }

    ColumnLayout {
        spacing: Appearance.spacing.lg
        Layout.fillWidth: true

        FontDropdown {
            Layout.fillWidth: true
            label: qsTr("Material font family")
            currentFont: rootPane.fontFamilyMaterial
            onFontSelected: fontName => {
                rootPane.fontFamilyMaterial = fontName;
                rootPane.saveConfig();
            }
        }

        FontDropdown {
            Layout.fillWidth: true
            label: qsTr("Shell font")
            currentFont: KuroTheme.shellFamily
            onFontSelected: fontName => root.setKuroFont("fonts.shell_font", fontName)
        }

        FontDropdown {
            Layout.fillWidth: true
            label: qsTr("Toolkit font")
            currentFont: KuroTheme.toolkitFont
            onFontSelected: fontName => root.setKuroFont("toolkit.font", fontName)
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Shell font is shared by Quickshell and the terminal. Toolkit font and colors apply to GTK 3/4 and Qt 5/6 through Kuro Engine.")
            color: Appearance.colors.subtext
            wrapMode: Text.WordWrap
        }
    }
}
