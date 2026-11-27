import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property var modelData
    required property var list

    implicitHeight: Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    function onClicked(): void {
        if (root.modelData.action === "create") {
            Distrobox.create();
            root.list.visibilities.launcher = false;
        } else if (root.modelData.action === "refresh") {
            Distrobox.refresh();
        } else {
            Distrobox.enter(root.modelData.name);
            root.list.visibilities.launcher = false;
        }
    }

    StateLayer {
        radius: Appearance.rounding.small

        function onClicked(): void {
            root.onClicked();
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.lg
        anchors.rightMargin: Appearance.padding.lg
        anchors.margins: Appearance.padding.sm

        MaterialIcon {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            text: root.modelData.action === "create" ? "add_box"
                : root.modelData.action === "refresh" ? "refresh" : "deployed_code"
            color: root.modelData.action ? Colours.palette.m3primary
                : root.modelData.running ? Colours.palette.m3primary : Colours.palette.m3outline
            font.pointSize: Appearance.font.size.headlineLarge
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: Appearance.spacing.lg
            anchors.right: enterIcon.left
            anchors.rightMargin: Appearance.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.xs

            StyledText {
                width: parent.width
                text: root.modelData.name
                font.pointSize: Appearance.font.size.bodyMedium
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: root.modelData.action ? root.modelData.status
                    : `${root.modelData.running ? qsTr("Running") : qsTr("Stopped")} · ${root.modelData.image || qsTr("Distrobox container")}`
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.labelLarge
                elide: Text.ElideRight
            }
        }

        MaterialIcon {
            id: enterIcon

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.modelData.action === "refresh" ? "refresh"
                : root.modelData.action === "create" ? "add" : "arrow_forward"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.titleMedium
        }
    }
}
