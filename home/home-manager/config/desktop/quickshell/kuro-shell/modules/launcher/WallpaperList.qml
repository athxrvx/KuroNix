pragma ComponentBehavior: Bound

import "items"
import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls

PathView {
    id: root

    required property TextField search
    required property PersistentProperties visibilities
    required property var panels
    required property var wrapper

    readonly property int itemWidth: Config.launcher.sizes.wallpaperWidth * 0.8 + Appearance.padding.lg * 2

    readonly property int numItems: {
        const screen = QsWindow.window?.screen;
        if (!screen)
            return 0;

        // Screen width - 4x outer rounding - 2x max side thickness (cause centered)
        let outerMargins = Math.max(Config.border.thickness, panels.bar.implicitWidth);
        if (panels.popouts.hasCurrent && panels.popouts.currentCenter + panels.popouts.nonAnimHeight / 2 > screen.height - wrapper.implicitHeight - Config.border.thickness * 2)
            outerMargins = panels.bar.implicitWidth + panels.popouts.nonAnimWidth;
        const maxWidth = screen.width - Config.border.rounding * 4 - outerMargins * 2;

        if (maxWidth <= 0)
            return 0;

        const maxItemsOnScreen = Math.floor(maxWidth / itemWidth);
        const visible = Math.min(maxItemsOnScreen, Config.launcher.maxWallpapers, scriptModel.values.length);

        if (visible === 2)
            return 1;
        if (visible > 1 && visible % 2 === 0)
            return visible - 1;
        return visible;
    }

    model: ScriptModel {
        id: scriptModel

        readonly property string search: root.search.text.split(" ").slice(1).join(" ")

        values: Wallpapers.query(search)
        onValuesChanged: root.currentIndex = search ? 0 : values.findIndex(w => w.path === Wallpapers.actualCurrent)
    }

    Component.onCompleted: currentIndex = Wallpapers.list.findIndex(w => w.path === Wallpapers.actualCurrent)
    Component.onDestruction: Wallpapers.stopPreview()

    Timer {
        id: previewDebounce
        interval: 250
        onTriggered: {
            if (root.currentItem)
                Wallpapers.preview(root.currentItem.modelData.path);
        }
    }

    onCurrentItemChanged: {
        if (currentItem)
            previewDebounce.restart();
    }

    implicitWidth: Math.min(numItems, count) * itemWidth
    pathItemCount: numItems
    cacheItemCount: 4

    snapMode: PathView.SnapToItem
    interactive: true
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange

    delegate: WallpaperItem {
        visibilities: root.visibilities
    }

    property real horizontalWheelDelta: 0

    Timer {
        id: wheelReset
        interval: 220
        onTriggered: root.horizontalWheelDelta = 0
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            const rawDelta = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 3;
            if (rawDelta === 0)
                return;

            root.horizontalWheelDelta += rawDelta;
            wheelReset.restart();
            if (Math.abs(root.horizontalWheelDelta) >= 36 && root.count > 1) {
                const direction = root.horizontalWheelDelta < 0 ? 1 : -1;
                root.currentIndex = (root.currentIndex + direction + root.count) % root.count;
                root.horizontalWheelDelta = 0;
            }
            event.accepted = true;
        }
    }

    StyledRect {
        z: 10
        visible: root.count > 1
        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.sm
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 42
        implicitHeight: 42
        radius: Appearance.rounding.full
        color: Colours.palette.m3surfaceContainerHigh

        StateLayer {
            radius: parent.radius
            function onClicked(): void {
                if (root.count > 1)
                    root.currentIndex = (root.currentIndex - 1 + root.count) % root.count;
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "chevron_left"
            color: Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.titleLarge
        }
    }

    StyledRect {
        z: 10
        visible: root.count > 1
        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.sm
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 42
        implicitHeight: 42
        radius: Appearance.rounding.full
        color: Colours.palette.m3surfaceContainerHigh

        StateLayer {
            radius: parent.radius
            function onClicked(): void {
                if (root.count > 1)
                    root.currentIndex = (root.currentIndex + 1) % root.count;
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "chevron_right"
            color: Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.titleLarge
        }
    }

    path: Path {
        startY: root.height / 2

        PathAttribute {
            name: "z"
            value: 0
        }
        PathLine {
            x: root.width / 2
            relativeY: 0
        }
        PathAttribute {
            name: "z"
            value: 1
        }
        PathLine {
            x: root.width
            relativeY: 0
        }
    }
}
