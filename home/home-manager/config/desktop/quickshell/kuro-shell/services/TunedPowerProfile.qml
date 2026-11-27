pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// TuneD's tuned-ppd compatibility service exposes the standard PPD D-Bus API.
Singleton {
    id: root

    property bool available: false
    property string current: ""
    property var profiles: []
    property bool applying: false
    property string error: ""
    property bool refreshPending: false

    property string busDest: "org.freedesktop.UPower.PowerProfiles"
    property string busPath: "/org/freedesktop/UPower/PowerProfiles"
    property string busIface: "org.freedesktop.UPower.PowerProfiles"

    function refresh(): void {
        if (setProc.running || readProc.running) {
            refreshPending = true;
            return;
        }
        readProc.running = true;
    }

    function set(profile: string): void {
        if (!available || !profiles.includes(profile) || setProc.running || profile === current)
            return;
        error = "";
        applying = true;
        setProc.command = ["busctl", "set-property", busDest, busPath, busIface, "ActiveProfile", "s", profile];
        setProc.running = true;
    }

    function pretty(profile: string): string {
        return ({ "power-saver": qsTr("Power saver"), "balanced": qsTr("Balanced"), "performance": qsTr("Performance") })[profile] ?? profile;
    }

    readonly property string readScript: [
        'if ! busctl get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile >/dev/null 2>&1; then',
        '  dest="net.hadess.PowerProfiles"; path="/net/hadess/PowerProfiles"; iface="net.hadess.PowerProfiles"',
        'else',
        '  dest="org.freedesktop.UPower.PowerProfiles"; path="/org/freedesktop/UPower/PowerProfiles"; iface="org.freedesktop.UPower.PowerProfiles"',
        'fi',
        'current=$(busctl get-property "$dest" "$path" "$iface" ActiveProfile 2>/dev/null | sed -nE \'s/^s "([^"]+)"$/\\1/p\') || exit 1',
        '[ -n "$current" ] || exit 1',
        'echo "$dest|$path|$iface"',
        'echo "$current"',
        'busctl get-property "$dest" "$path" "$iface" Profiles 2>/dev/null | grep -oE \'"Profile" s "[^"]+"\' | sed -nE \'s/^"Profile" s "([^"]+)"$/\\1/p\''
    ].join("\n")

    Process {
        id: readProc
        command: ["sh", "-c", root.readScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length < 3 || !lines[1]) {
                    root.available = false;
                    root.current = "";
                    root.profiles = [];
                    return;
                }

                const bus = lines[0].split("|");
                if (bus.length === 3) {
                    root.busDest = bus[0];
                    root.busPath = bus[1];
                    root.busIface = bus[2];
                }

                root.current = lines[1];
                root.profiles = [...new Set(lines.slice(2).filter(profile => profile.length > 0))];
                root.available = root.profiles.length > 0;
            }
        }
        onExited: root.scheduleRefresh()
    }

    Process {
        id: setProc
        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim()
        }
        onExited: (code) => {
            root.applying = false;
            if (code !== 0 && !root.error)
                root.error = qsTr("Could not change the TuneD power profile");
            root.refreshPending = false;
            root.refresh();
        }
    }

    function scheduleRefresh(): void {
        if (refreshPending && !setProc.running)
            refreshTimer.restart();
    }

    Timer {
        id: refreshTimer
        interval: 100
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
