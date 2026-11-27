pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    property bool opened: false
    property bool opening: false
    property string frozenFrame: ""
    property string mode: "screenshot"
    property string area: "selection"
    property string lastRecordingArea: "selection"
    property string audio: "none"
    property string error: ""
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0
    property real dragStartX: 0
    property real dragStartY: 0
    property real moveOffsetX: 0
    property real moveOffsetY: 0
    property string dragMode: "new"

    function resetSelection(): void {
        selectionX = win.width * 0.18;
        selectionY = win.height * 0.18;
        selectionWidth = win.width * 0.64;
        selectionHeight = win.height * 0.48;
    }

    function open(): void {
        if (opened || opening)
            return;
        const recording = Recorder.running || Recorder.starting;
        mode = recording ? "record" : "screenshot";
        area = recording ? lastRecordingArea : "selection";
        error = "";
        resetSelection();
        if (recording) {
            opened = true;
            return;
        }

        // Capture the focused output before showing any layer-shell surface.
        // The overlay then displays this frame and crops from the same file.
        opening = true;
        freezeProc.outputPath = "";
        freezeProc.command = ["kuro-capture", "freeze", win.screen?.name ?? ""];
        freezeProc.running = true;
    }

    function close(): void {
        opening = false;
        opened = false;
        if (frozenFrame !== "") {
            cleanupProc.command = ["kuro-capture", "discard", frozenFrame];
            cleanupProc.running = true;
            frozenFrame = "";
        }
    }

    function toggle(): void {
        if (opened || opening)
            close();
        else
            open();
    }

    function cycleAudio(): void {
        audio = ({ none: "system", system: "external", external: "both", both: "none" })[audio];
    }

    readonly property real captureX: area === "screen" ? 0 : selectionX
    readonly property real captureY: area === "screen" ? 0 : selectionY
    readonly property real captureWidth: area === "screen" ? win.width : selectionWidth
    readonly property real captureHeight: area === "screen" ? win.height : selectionHeight
    readonly property string captureGeometry: `${Math.round((win.screen?.x ?? 0) + captureX)},${Math.round((win.screen?.y ?? 0) + captureY)} ${Math.max(1, Math.round(captureWidth))}x${Math.max(1, Math.round(captureHeight))}`
    readonly property real captureScaleX: frozenImage.sourceSize.width > 0 && win.width > 0 ? frozenImage.sourceSize.width / win.width : 1
    readonly property real captureScaleY: frozenImage.sourceSize.height > 0 && win.height > 0 ? frozenImage.sourceSize.height / win.height : 1
    readonly property string localCaptureGeometry: `${Math.max(1, Math.round(captureWidth * captureScaleX))}x${Math.max(1, Math.round(captureHeight * captureScaleY))}+${Math.max(0, Math.round(captureX * captureScaleX))}+${Math.max(0, Math.round(captureY * captureScaleY))}`

    function captureTarget(): string {
        return "selection";
    }

    function takeScreenshot(): void {
        error = "";
        opened = false;
        screenshotHandoff.restart();
    }

    function startRecording(): void {
        lastRecordingArea = area;
        opened = false;
        recorderHandoff.restart();
    }

    IpcHandler {
        target: "capture"
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function toggle(): void { root.toggle(); }
    }

    Connections {
        target: Recorder
        function onErrorChanged(): void {
            if (Recorder.error !== "")
                root.opened = true;
        }
    }

    Timer {
        id: screenshotHandoff
        interval: 120
        onTriggered: {
            screenshotProc.command = ["kuro-capture", "screenshot", root.area, root.captureGeometry, root.frozenFrame, root.localCaptureGeometry];
            screenshotProc.running = true;
        }
    }

    Timer {
        id: recorderHandoff
        interval: 120
        onTriggered: Recorder.start(root.captureTarget(), root.audio, root.captureGeometry)
    }

    Process {
        id: freezeProc
        property string outputPath: ""
        stdout: StdioCollector { onStreamFinished: freezeProc.outputPath = text.trim() }
        stderr: StdioCollector { onStreamFinished: root.error = text.trim() }
        onExited: (code) => {
            if (code === 0 && outputPath !== "") {
                root.frozenFrame = outputPath;
                if (!root.opening) {
                    cleanupProc.command = ["kuro-capture", "discard", outputPath];
                    cleanupProc.running = true;
                    root.frozenFrame = "";
                    return;
                }
                root.error = "";
            } else {
                if (!root.opening)
                    return;
                root.frozenFrame = "";
                if (!root.error)
                    root.error = qsTr("Could not freeze the screen");
            }
            root.opening = false;
            root.opened = true;
        }
    }

    Process {
        id: cleanupProc
    }

    Process {
        id: screenshotProc
        stderr: StdioCollector { onStreamFinished: root.error = text.trim() }
        onExited: (code) => {
            if (code !== 0) {
                if (!root.error)
                    root.error = qsTr("Screenshot failed");
                root.opened = true;
            } else {
                root.error = "";
            }
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Niri.focusedMonitorName) ?? Quickshell.screens[0]
        visible: root.opened
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "kuroShell-capture-osd"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Item {
            id: overlay
            anchors.fill: parent
            focus: root.opened

            Image {
                id: frozenImage
                z: -1
                anchors.fill: parent
                visible: root.opened && root.mode === "screenshot" && root.frozenFrame !== ""
                source: visible ? `file://${root.frozenFrame}` : ""
                fillMode: Image.Stretch
                cache: false
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.mode === "screenshot") root.takeScreenshot();
                    else if (Recorder.running || Recorder.starting) Recorder.stop();
                    else root.startRecording();
                    event.accepted = true;
                }
            }

            MouseArea {
                z: 0
                anchors.fill: parent
                enabled: root.opened && root.area === "selection" && !Recorder.running && !Recorder.starting
                cursorShape: Qt.CrossCursor
                onPressed: event => {
                    const handle = 26;
                    const left = root.selectionX;
                    const right = left + root.selectionWidth;
                    const top = root.selectionY;
                    const bottom = top + root.selectionHeight;
                    const nearLeft = Math.abs(event.x - left) <= handle;
                    const nearRight = Math.abs(event.x - right) <= handle;
                    const nearTop = Math.abs(event.y - top) <= handle;
                    const nearBottom = Math.abs(event.y - bottom) <= handle;

                    if (nearLeft && nearTop) {
                        root.dragMode = "resize"; root.dragStartX = right; root.dragStartY = bottom;
                    } else if (nearRight && nearTop) {
                        root.dragMode = "resize"; root.dragStartX = left; root.dragStartY = bottom;
                    } else if (nearLeft && nearBottom) {
                        root.dragMode = "resize"; root.dragStartX = right; root.dragStartY = top;
                    } else if (nearRight && nearBottom) {
                        root.dragMode = "resize"; root.dragStartX = left; root.dragStartY = top;
                    } else if (event.x >= left && event.x <= right && event.y >= top && event.y <= bottom) {
                        root.dragMode = "move";
                        root.moveOffsetX = event.x - left;
                        root.moveOffsetY = event.y - top;
                    } else {
                        root.dragMode = "new";
                        root.dragStartX = event.x;
                        root.dragStartY = event.y;
                        root.selectionX = event.x;
                        root.selectionY = event.y;
                        root.selectionWidth = 1;
                        root.selectionHeight = 1;
                    }
                }
                onPositionChanged: event => {
                    if (!pressed) return;
                    const pointerX = Math.max(0, Math.min(parent.width, event.x));
                    const pointerY = Math.max(0, Math.min(parent.height, event.y));
                    if (root.dragMode === "move") {
                        root.selectionX = Math.max(0, Math.min(parent.width - root.selectionWidth, pointerX - root.moveOffsetX));
                        root.selectionY = Math.max(0, Math.min(parent.height - root.selectionHeight, pointerY - root.moveOffsetY));
                    } else {
                        root.selectionX = Math.min(root.dragStartX, pointerX);
                        root.selectionY = Math.min(root.dragStartY, pointerY);
                        root.selectionWidth = Math.abs(pointerX - root.dragStartX);
                        root.selectionHeight = Math.abs(pointerY - root.dragStartY);
                    }
                }
            }

            // Shade everything outside the capture area.
            Rectangle {
                z: 1
                visible: root.area === "selection"
                x: 0; y: 0; width: parent.width; height: root.captureY
                color: "#99000000"
            }
            Rectangle {
                z: 1
                visible: root.area === "selection"
                x: 0; y: root.captureY; width: root.captureX; height: root.captureHeight
                color: "#99000000"
            }
            Rectangle {
                z: 1
                visible: root.area === "selection"
                x: root.captureX + root.captureWidth; y: root.captureY
                width: Math.max(0, parent.width - x); height: root.captureHeight
                color: "#99000000"
            }
            Rectangle {
                z: 1
                visible: root.area === "selection"
                x: 0; y: root.captureY + root.captureHeight
                width: parent.width; height: Math.max(0, parent.height - y)
                color: "#99000000"
            }

            Rectangle {
                id: selectionFrame
                z: 2
                visible: root.area === "selection"
                x: root.captureX; y: root.captureY
                width: root.captureWidth; height: root.captureHeight
                color: Qt.alpha(Colours.palette.m3primary, 0.12)
                border.color: Colours.palette.m3primary
                border.width: Math.max(1, Appearance.padding.xs / 2)
            }

            Repeater {
                z: 3
                model: [
                    { right: false, bottom: false }, { right: true, bottom: false },
                    { right: false, bottom: true }, { right: true, bottom: true }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: 24; height: 24; radius: 12
                    x: selectionFrame.x + (modelData.right ? selectionFrame.width - width / 2 : -width / 2)
                    y: selectionFrame.y + (modelData.bottom ? selectionFrame.height - height / 2 : -height / 2)
                    visible: selectionFrame.visible
                    color: Colours.palette.m3primary
                    border.width: 2
                    border.color: Colours.palette.m3background
                }
            }

            StyledRect {
                id: card
                z: 10
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 46
                width: Math.min(270, parent.width - Appearance.padding.xl * 2)
                radius: Appearance.rounding.large
                color: Colours.tPalette.m3surfaceContainer
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
                implicitHeight: captureLayout.implicitHeight + Appearance.padding.lg * 2
                height: captureLayout.implicitHeight + Appearance.padding.lg * 2

                ColumnLayout {
                    id: captureLayout
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.lg
                    spacing: Appearance.spacing.md

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.xs

                        Repeater {
                            model: [
                                { id: "selection", label: qsTr("Selection"), icon: "crop_free" },
                                { id: "screen", label: qsTr("Screen"), icon: "monitor" }
                            ]
                            delegate: StyledRect {
                                id: areaButton
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 74
                                enabled: !Recorder.running && !Recorder.starting
                                radius: Appearance.rounding.normal
                                color: root.area === modelData.id ? Colours.palette.m3primaryContainer : "transparent"

                                StateLayer {
                                    radius: parent.radius
                                    function onClicked(): void {
                                        root.area = areaButton.modelData.id;
                                        if (root.area === "selection" && root.selectionWidth < 20)
                                            root.resetSelection();
                                        root.error = "";
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Appearance.spacing.xs
                                    MaterialIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: areaButton.modelData.icon
                                        color: root.area === areaButton.modelData.id ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Appearance.font.size.titleLarge
                                    }
                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: areaButton.modelData.label
                                        color: root.area === areaButton.modelData.id ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Appearance.font.size.labelMedium
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.error !== "" || Recorder.error !== ""
                        text: root.error || Recorder.error
                        color: Colours.palette.m3error
                        font.pointSize: Appearance.font.size.labelMedium
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 80
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 62

                            StyledRect {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 80
                                height: 42
                                radius: Appearance.rounding.full
                                color: Colours.tPalette.m3surfaceContainerLow
                                border.width: 1
                                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Repeater {
                                        model: [
                                            { id: "screenshot", icon: "photo_camera" },
                                            { id: "record", icon: "videocam" }
                                        ]
                                        delegate: StyledRect {
                                            required property var modelData
                                            width: 38; height: 36
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: Appearance.rounding.full
                                            color: root.mode === modelData.id ? Colours.palette.m3secondaryContainer : "transparent"

                                            StateLayer {
                                                radius: parent.radius
                                                function onClicked(): void {
                                                    if (!Recorder.running && !Recorder.starting)
                                                        root.mode = parent.modelData.id;
                                                }
                                            }
                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                text: parent.modelData.icon
                                                color: root.mode === parent.modelData.id ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                                font.pointSize: Appearance.font.size.titleMedium
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        StyledRect {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 62
                            Layout.preferredHeight: 62
                            radius: Appearance.rounding.normal
                            color: root.mode === "record" ? Colours.palette.m3error : Colours.palette.m3primary
                            border.width: 2
                            border.color: Qt.alpha(root.mode === "record" ? Colours.palette.m3onError : Colours.palette.m3onPrimary, 0.2)

                            StateLayer {
                                radius: parent.radius
                                function onClicked(): void {
                                    if (Recorder.running || Recorder.starting) Recorder.stop();
                                    else if (!Recorder.starting) {
                                        if (root.mode === "screenshot") root.takeScreenshot();
                                        else root.startRecording();
                                    }
                                }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: Recorder.running || Recorder.starting ? "stop" : root.mode === "record" ? "radio_button_checked" : "photo_camera"
                                color: root.mode === "record" ? Colours.palette.m3onError : Colours.palette.m3onPrimary
                                font.pointSize: Appearance.font.size.titleLarge
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 90
                            Layout.preferredWidth: 90
                            Layout.preferredHeight: 62

                            StyledRect {
                                id: audioChip
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.mode === "record" && !Recorder.running && !Recorder.starting
                                width: audioLabel.implicitWidth + Appearance.padding.md * 2
                                height: 34
                                radius: Appearance.rounding.full
                                color: Colours.tPalette.m3surfaceContainerLow
                                border.width: 1
                                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)

                                StateLayer {
                                    function onClicked(): void { root.cycleAudio(); }
                                }

                                StyledText {
                                    id: audioLabel
                                    anchors.centerIn: parent
                                    text: qsTr("Audio %1").arg(({ none: qsTr("off"), system: qsTr("system"), external: qsTr("mic"), both: qsTr("both") })[root.audio])
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Appearance.font.size.labelSmall
                                }
                            }

                            StyledRect {
                                id: recordingChip
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Recorder.running || Recorder.starting
                                width: recordingRow.implicitWidth + Appearance.padding.md * 2
                                height: 34
                                radius: Appearance.rounding.full
                                color: Colours.tPalette.m3surfaceContainerLow
                                border.width: 1
                                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)

                                Row {
                                    id: recordingRow
                                    anchors.centerIn: parent
                                    spacing: Appearance.spacing.xs
                                    MaterialIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "fiber_manual_record"
                                        color: Colours.palette.m3error
                                        font.pointSize: Appearance.font.size.labelMedium
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Recorder.starting ? qsTr("Starting…") : `${Math.floor(Recorder.elapsed / 60).toString().padStart(2, "0")}:${Math.floor(Recorder.elapsed % 60).toString().padStart(2, "0")}`
                                        color: Colours.palette.m3onSurface
                                        font.pointSize: Appearance.font.size.labelMedium
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                z: 11
                anchors.horizontalCenter: card.right
                anchors.bottom: card.top
                anchors.bottomMargin: -Appearance.spacing.sm
                width: 34
                height: 34
                implicitWidth: 34
                implicitHeight: 34
                radius: Appearance.rounding.normal
                color: Colours.tPalette.m3surfaceContainerHigh
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)

                StateLayer {
                    radius: parent.radius
                    function onClicked(): void { root.close(); }
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "close"
                    color: Colours.palette.m3onSurface
                    font.pointSize: Appearance.font.size.titleMedium
                }
            }
        }
    }
}
