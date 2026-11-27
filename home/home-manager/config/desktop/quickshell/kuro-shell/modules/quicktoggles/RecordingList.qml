pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.config
import qs.utils
import KuroShell
import KuroShell.Models
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property bool expanded: false
    readonly property var recordings: recordingFiles.entries
        .filter(file => file.name.startsWith("recording_") && file.suffix.toLowerCase() === "mp4")
        .sort((a, b) => b.name.localeCompare(a.name))

    spacing: 0

    FileSystemModel {
        id: recordingFiles
        path: Paths.recordings
        filter: FileSystemModel.Files
        watchChanges: true
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight

        RowLayout {
            id: header
            anchors.fill: parent
            spacing: Appearance.spacing.sm

            MaterialIcon {
                text: "list"
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Recordings")
                font.weight: 500
            }

            IconButton {
                type: IconButton.Text
                icon: root.expanded ? "unfold_less" : "unfold_more"
                label.animate: true
                onClicked: root.expanded = !root.expanded
            }
        }

        StateLayer {
            anchors.fill: parent
            z: 1
            acceptedButtons: Qt.LeftButton
            showHoverBackground: false
            onClicked: root.expanded = !root.expanded
        }
    }

    StyledListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: root.expanded
            ? Math.max(Appearance.font.size.bodySmall + Appearance.spacing.md, Math.min(count, 3) * (Appearance.font.size.bodySmall + Appearance.padding.md))
            : 0
        clip: true
        model: ScriptModel {
            values: root.recordings
        }

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: list
        }

        delegate: RowLayout {
            id: recording
            required property FileSystemEntry modelData
            width: list.width
            height: Appearance.font.size.bodySmall + Appearance.padding.md
            spacing: Appearance.spacing.xs

            StyledText {
                Layout.fillWidth: true
                text: {
                    const match = recording.modelData.name.match(/^recording_(\d{4})(\d{2})(\d{2})_(\d{2})-(\d{2})-(\d{2})\.mp4$/);
                    if (!match)
                        return recording.modelData.name;
                    const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]), Number(match[4]), Number(match[5]), Number(match[6]));
                    return qsTr("Recording at %1").arg(date.toLocaleString(Qt.locale(), Locale.ShortFormat));
                }
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            IconButton {
                icon: "play_arrow"
                type: IconButton.Text
                onClicked: Quickshell.execDetached([...Config.general.apps.playback, recording.modelData.path])
            }

            IconButton {
                icon: "folder"
                type: IconButton.Text
                onClicked: Quickshell.execDetached([...Config.general.apps.explorer, recording.modelData.path])
            }

            IconButton {
                icon: "delete_forever"
                type: IconButton.Text
                label.color: Colours.palette.m3error
                stateLayer.color: Colours.palette.m3error
                onClicked: CUtils.deleteFile(Qt.resolvedUrl(recording.modelData.path))
            }
        }

        Loader {
            anchors.centerIn: parent
            active: root.expanded && list.count === 0
            sourceComponent: StyledText {
                text: qsTr("No recordings found")
                color: Colours.palette.m3outline
            }
        }

        Behavior on Layout.preferredHeight {
            Anim {}
        }
    }
}
