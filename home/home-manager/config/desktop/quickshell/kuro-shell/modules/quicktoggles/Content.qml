pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.components.widgets
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property var wrapper
    required property PersistentProperties visibilities

    readonly property int padding: Math.max(Appearance.padding.xl, Config.border.rounding)

    implicitWidth: 450
    implicitHeight: mainLayout.implicitHeight + padding * 2

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding
        spacing: Appearance.spacing.sm

        /* ─── KEEP AWAKE ─── */
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: awakeRow.implicitHeight + Appearance.padding.md * 2
            radius: Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: awakeRow
                anchors.fill: parent
                anchors.margins: Appearance.padding.md
                spacing: Appearance.spacing.md

                StyledRect {
                    Layout.preferredWidth: Appearance.font.size.titleMedium + Appearance.padding.md * 2
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: Appearance.rounding.full
                    color: IdleInhibitor.enabled ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "coffee"
                        color: IdleInhibitor.enabled ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Keep awake")
                        font.pointSize: Appearance.font.size.bodyMedium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: IdleInhibitor.enabled ? qsTr("Preventing sleep mode") : qsTr("Normal power management")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.bodySmall
                        elide: Text.ElideRight
                    }
                }

                StyledSwitch {
                    checked: IdleInhibitor.enabled
                    onToggled: IdleInhibitor.enabled = checked
                }
            }
        }

        /* ─── NOTIFICATIONS ─── */
        StyledClippingRect {
            id: notifSection
            Layout.fillWidth: true
            Layout.preferredHeight: notifExpanded ? expandedHeight : collapsedHeight
            radius: Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainer

            readonly property bool notifExpanded: root.visibilities.notifsExpanded
            readonly property int collapsedHeight: notifListWidget.showHeader ? 52 : 0
            readonly property int screenHalfHeight: (Screen.height || 1080) / 2
            readonly property int desiredHeight: notifListWidget.desiredContentHeight + Appearance.padding.md * 2
            readonly property int expandedHeight: Notifs.list.length === 0
                ? collapsedHeight + 120
                : Math.max(collapsedHeight + 120, Math.min(desiredHeight, screenHalfHeight))

            // Tracks whether the user manually collapsed the panel while notifications exist.
            // Reset to false when the notification list empties, so the next incoming
            // notification triggers an auto-expand again.
            property bool userCollapsed: false
            property int notifCount: Notifs.list.length

            onNotifCountChanged: {
                if (notifCount === 0) {
                    userCollapsed = false;
                    root.visibilities.notifsExpanded = false;
                    notifListWidget.expanded = false;
                } else if (!userCollapsed) {
                    root.visibilities.notifsExpanded = true;
                    notifListWidget.expanded = true;
                }
            }

            Component.onCompleted: {
                if (Notifs.list.length > 0)
                    root.visibilities.notifsExpanded = true;
            }

            Behavior on Layout.preferredHeight {
                Anim {
                    duration: Appearance.anim.durations.normal
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            NotificationList {
                id: notifListWidget
                anchors.fill: parent
                anchors.margins: Appearance.padding.md
                expanded: notifSection.notifExpanded
                expandable: true

                Connections {
                    target: notifListWidget
                    function onExpandedChanged(): void {
                        root.visibilities.notifsExpanded = notifListWidget.expanded;
                        if (!notifListWidget.expanded && Notifs.list.length > 0)
                            notifSection.userCollapsed = true;
                        else if (notifListWidget.expanded)
                            notifSection.userCollapsed = false;
                    }
                    function onCleared(): void {
                        notifSection.userCollapsed = false;
                        root.visibilities.notifsExpanded = false;
                        notifListWidget.expanded = false;
                    }
                }
            }
        }

        /* ─── QUICK TOGGLES ─── */
        StyledRect {
            id: togglesSection
            Layout.fillWidth: true
            implicitHeight: togglesLayout.implicitHeight + Appearance.padding.md * 2
            radius: Appearance.rounding.normal
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: togglesLayout
                anchors.fill: parent
                anchors.margins: Appearance.padding.md
                spacing: Appearance.spacing.md

                StyledText {
                    text: qsTr("Quick toggles")
                    font.pointSize: Appearance.font.size.bodyMedium
                    font.weight: 500
                }

                RowLayout {
                    id: togglesRow
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.sm

                    Toggle {
                        icon: "wifi"
                        checked: Network.wifiEnabled
                        onClicked: Network.toggleWifi()
                    }

                    Toggle {
                        icon: "bluetooth"
                        checked: Bluetooth.defaultAdapter?.enabled ?? false
                        onClicked: {
                            const adapter = Bluetooth.defaultAdapter;
                            if (adapter)
                                adapter.enabled = !adapter.enabled;
                        }
                    }

                    Toggle {
                        icon: "mic"
                        checked: !Audio.sourceMuted
                        onClicked: {
                            const audio = Audio.source?.audio;
                            if (audio)
                                audio.muted = !audio.muted;
                        }
                    }

                    Toggle {
                        icon: "vpn_key"
                        checked: VPN.connected
                        enabled: !VPN.connecting
                        visible: Config.utilities.vpn.provider.some(p => typeof p === "object" ? (p.enabled === true) : false)
                        onClicked: VPN.toggle()
                    }

                    Toggle {
                        icon: "settings"
                        toggle: false
                        onClicked: {
                            root.visibilities.quicktoggles = false;
                            openControlCenter("network");
                        }
                    }
                }
            }
        }

    }

    function openControlCenter(pane: string): void {
        const panelsPopouts = root.wrapper && root.wrapper.parent ? root.wrapper.parent.popouts : null;
        if (panelsPopouts) {
            panelsPopouts.detach(pane);
        }
        // Close the quicktoggles panel after opening the ControlCenter popout
        if (root.visibilities) {
            root.visibilities.quicktoggles = false;
        }
    }

    // Toggle component matching Hyprland's utilities/cards/Toggles style
    component Toggle: IconButton {
        Layout.fillWidth: true
        Layout.preferredWidth: implicitHeight
        implicitWidth: implicitHeight
        radius: Appearance.rounding.full
        inactiveColour: toggle
            ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
            : Colours.palette.m3primary
        // Some themes map onSurfaceVariant to the same value as surfaceContainerHighest,
        // which makes the icon invisible on an unchecked toggle. Derive a contrasting
        // icon colour from the actual background instead.
        inactiveOnColour: toggle ? Colours.on(inactiveColour) : Colours.palette.m3onPrimary
        toggle: true
        // Keep the icon filled when the toggle is off instead of falling back to
        // IconButton's outlined (fill 0) inactive style.
        fillWhenInactive: true
        radiusAnim.duration: Appearance.anim.durations.expressiveFastSpatial
        radiusAnim.easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial

        Behavior on Layout.preferredWidth {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
        }
    }

}
