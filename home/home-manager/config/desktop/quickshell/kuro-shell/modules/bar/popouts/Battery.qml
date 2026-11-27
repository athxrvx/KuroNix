pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    spacing: 0
    // Keep enough room for all three power-profile labels, including Performance.
    width: Math.max(320, Config.bar.sizes.batteryWidth)

    readonly property var battery: UPower.displayDevice
    property string powerDrawValue: "—"
    readonly property bool discharging: battery.state === UPowerDeviceState.Discharging
        || battery.state === UPowerDeviceState.PendingDischarge
        || UPower.onBattery
        || battery.changeRate < 0

    onDischargingChanged: {
        if (discharging)
            refreshPowerDraw();
        else
            powerDrawValue = "—";
    }

    function formatSeconds(seconds: int, fallback: string): string {
        if (seconds <= 0)
            return fallback;
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        if (hours > 0 && minutes > 0)
            return qsTr("%1h %2m").arg(hours).arg(minutes);
        if (hours > 0)
            return qsTr("%1h").arg(hours);
        if (minutes > 0)
            return qsTr("%1m").arg(minutes);
        return qsTr("<1m");
    }

    function batteryIcon(): string {
        if (!battery.isLaptopBattery)
            return "battery_unknown";
        if (discharging)
            return `battery_${Math.max(0, Math.min(6, Math.floor(battery.percentage * 7)))}_bar`;
        return battery.percentage >= 0.99 ? "battery_charging_full" : "battery_charging_80";
    }

    function refreshPowerDraw(): void {
        if (powerSampler.running || !battery.isLaptopBattery || !discharging)
            return;
        powerSampler.running = true;
    }

    readonly property string powerReadScript: [
        'total=0',
        'found=0',
        'for dir in /sys/class/power_supply/*; do',
        '  [ -r "$dir/type" ] && [ "$(cat "$dir/type")" = "Battery" ] || continue',
        '  [ "$(cat "$dir/status" 2>/dev/null)" = "Discharging" ] || continue',
        '  if [ -r "$dir/power_now" ]; then',
        '    raw=$(cat "$dir/power_now")',
        '    watts=$(awk -v n="$raw" "BEGIN { print n / 1000000 }")',
        '  elif [ -r "$dir/current_now" ] && [ -r "$dir/voltage_now" ]; then',
        '    current=$(cat "$dir/current_now"); voltage=$(cat "$dir/voltage_now")',
        '    watts=$(awk -v c="$current" -v v="$voltage" "BEGIN { print c * v / 1000000000000 }")',
        '  else',
        '    continue',
        '  fi',
        '  total=$(awk -v a="$total" -v b="$watts" "BEGIN { print a + b }")',
        '  found=1',
        'done',
        '[ "$found" = 1 ] || exit 1',
        'printf "%.1f\\n" "$total"'
    ].join("\n")

    function degradationToString(reason: int): string {
        switch (reason) {
        case PerformanceDegradationReason.HighTemperature:
            return qsTr("The device is too hot");
        case PerformanceDegradationReason.LapDetected:
            return qsTr("The device is on a lap");
        default:
            return qsTr("Unknown reason");
        }
    }


    Process {
        id: powerSampler
        command: ["sh", "-c", root.powerReadScript]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.discharging) {
                    root.powerDrawValue = "—";
                    return;
                }
                const watts = Number.parseFloat(text.trim());
                root.powerDrawValue = Number.isFinite(watts) ? qsTr("%1 W").arg(watts.toFixed(1)) : "—";
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.powerDrawValue = "—";
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.discharging && root.battery.isLaptopBattery
        onTriggered: root.refreshPowerDraw()
    }

    Component.onCompleted: refreshPowerDraw()

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.padding.xs
        Layout.bottomMargin: Appearance.spacing.sm
        spacing: Appearance.spacing.md

        MaterialIcon {
            text: root.batteryIcon()
            font.pointSize: Appearance.font.size.titleMedium
            color: Colours.palette.m3primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Battery")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelLarge
            }

            RowLayout {
                spacing: Appearance.spacing.xs

                StyledText {
                    text: root.battery.isLaptopBattery ? `${Math.round(root.battery.percentage * 100)}%` : "—"
                    font.pointSize: Appearance.font.size.titleMedium
                    font.weight: 600
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Appearance.spacing.md
        spacing: Appearance.spacing.md

        Metric {
            Layout.fillWidth: true
            icon: "schedule"
            title: root.discharging ? qsTr("Remaining") : qsTr("Until charged")
            value: root.discharging
                ? root.formatSeconds(root.battery.timeToEmpty, "—")
                : root.formatSeconds(root.battery.timeToFull, "—")
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 1
            color: Colours.palette.m3outlineVariant
        }

        Metric {
            Layout.fillWidth: true
            icon: "bolt"
            title: qsTr("Power draw")
            value: root.powerDrawValue
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.md
        spacing: Appearance.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.sm

            MaterialIcon {
                text: "tune"
                color: Colours.palette.m3onSurfaceVariant
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Power profile")
                    font.weight: 500
                }
            }

            StyledBusyIndicator {
                running: TunedPowerProfile.applying
                visible: running
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xs

            ProfileChoice {
                Layout.fillWidth: true
                profile: "power-saver"
                icon: "energy_savings_leaf"
                label: qsTr("Saver")
            }

            ProfileChoice {
                Layout.fillWidth: true
                profile: "balanced"
                icon: "balance"
                label: qsTr("Balanced")
            }

            ProfileChoice {
                Layout.fillWidth: true
                profile: "performance"
                icon: "rocket_launch"
                label: qsTr("Performance")
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !!TunedPowerProfile.error
            text: TunedPowerProfile.error
            color: Colours.palette.m3error
            font.pointSize: Appearance.font.size.bodySmall
            wrapMode: Text.Wrap
        }
    }

    Loader {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.md
        active: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
        asynchronous: true
        visible: active
        sourceComponent: StyledRect {
            implicitHeight: warningLayout.implicitHeight + Appearance.padding.md * 2
            color: Colours.palette.m3errorContainer
            radius: Appearance.rounding.normal

            ColumnLayout {
                id: warningLayout
                anchors.fill: parent
                anchors.margins: Appearance.padding.md
                spacing: Appearance.spacing.xs

                RowLayout {
                    MaterialIcon {
                        text: "warning"
                        color: Colours.palette.m3onErrorContainer
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Performance degraded")
                        color: Colours.palette.m3onErrorContainer
                        font.weight: 600
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.degradationToString(PowerProfiles.degradationReason)
                    color: Colours.palette.m3onErrorContainer
                    font.pointSize: Appearance.font.size.bodySmall
                }
            }
        }
    }

    component Metric: ColumnLayout {
        required property string icon
        required property string title
        required property string value

        spacing: 0

        RowLayout {
            spacing: Appearance.spacing.xs

            MaterialIcon {
                text: parent.parent.icon
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.bodySmall
            }

            StyledText {
                text: parent.parent.title
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelSmall
                elide: Text.ElideRight
            }
        }

        StyledText {
            Layout.leftMargin: Appearance.font.size.bodySmall + Appearance.spacing.xs
            text: parent.value
            font.weight: 500
            elide: Text.ElideRight
        }
    }

    component ProfileChoice: StyledRect {
        id: choice
        required property string profile
        required property string icon
        required property string label
        readonly property bool selected: TunedPowerProfile.current === profile
        readonly property bool available: TunedPowerProfile.available && TunedPowerProfile.profiles.includes(profile)

        implicitHeight: choiceLayout.implicitHeight + Appearance.padding.xs * 2
        radius: Appearance.rounding.normal
        color: selected ? Colours.palette.m3primaryContainer : "transparent"
        opacity: available ? 1 : 0.55

        ColumnLayout {
            id: choiceLayout
            anchors.fill: parent
            anchors.margins: Appearance.padding.xs
            spacing: Appearance.padding.xs / 2

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: choice.icon
                color: choice.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.titleMedium
            }

            StyledText {
                Layout.fillWidth: true
                text: choice.label
                color: choice.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.labelSmall
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        StateLayer {
            radius: Appearance.rounding.normal
            disabled: !choice.available || TunedPowerProfile.applying
            onClicked: TunedPowerProfile.set(choice.profile)
        }
    }
}
