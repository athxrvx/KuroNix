pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool running: false
    property bool starting: false
    property bool stopping: false
    property string error: ""
    property real elapsed: 0
    property string area: "full"
    property string audio: "none"

    readonly property string outputDir: Paths.recordings
    readonly property string stateFile: `${Paths.home}/.cache/quickshell/gpu-screen-recorder.pid`

    function start(captureArea = "full", audioMode = "none", selectedGeometry = ""): void {
        if (running || starting)
            return;

        error = "";
        elapsed = 0;
        area = captureArea;
        audio = audioMode;
        starting = true;
        Quickshell.execDetached(["kuro-capture", "record", area, audio, selectedGeometry]);
        startupTimeout.restart();
        recorderState.reload();
    }

    function stop(): void {
        if ((!running && !starting) || stopping)
            return;
        error = "";
        stopping = true;
        Quickshell.execDetached(["kuro-capture", "stop"]);
        stopTimeout.restart();
    }

    function toggle(): void {
        if (running || starting)
            stop();
        else
            start();
    }

    FileView {
        id: recorderState
        path: root.stateFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (text().trim() !== "") {
                const newlyRunning = !root.running;
                root.running = true;
                root.starting = false;
                root.stopping = false;
                startupTimeout.stop();
                stopTimeout.stop();
                if (newlyRunning) {
                    root.elapsed = 0;
                    elapsedTimer.start();
                }
            } else {
                root.running = false;
                root.starting = false;
                root.stopping = false;
                elapsedTimer.stop();
                stopTimeout.stop();
            }
        }
        onLoadFailed: {
            if (!root.starting) {
                root.running = false;
                root.stopping = false;
                elapsedTimer.stop();
            }
        }
    }

    Timer {
        id: startupTimeout
        interval: 8000
        onTriggered: {
            recorderState.reload();
            startupCheck.restart();
        }
    }

    Timer {
        id: startupCheck
        interval: 300
        onTriggered: {
            if (!root.running && root.starting) {
                root.starting = false;
                root.error = qsTr("Screen recorder did not start. Check that GPU Screen Recorder can capture this display.");
            }
        }
    }

    Timer {
        id: stopTimeout
        interval: 8000
        onTriggered: recorderState.reload()
    }

    Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        onTriggered: root.elapsed++
    }
}
