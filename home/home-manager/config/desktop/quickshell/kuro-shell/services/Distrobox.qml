pragma Singleton

import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property list<var> containers: []
    property bool loading: false
    property string error: ""
    property string _output: ""
    property string _errorOutput: ""

    function refresh(): void {
        if (listProc.running)
            return;

        loading = true;
        error = "";
        _output = "";
        _errorOutput = "";
        listProc.running = true;
    }

    function filtered(search: string): list<var> {
        const prefix = `${Config.launcher.actionPrefix}distrobox`;
        const query = search.slice(prefix.length).trim().toLowerCase();
        if (!query) {
            return [
                {
                    action: "create",
                    name: qsTr("Create a container"),
                    status: qsTr("Choose a name and image"),
                    image: "",
                    running: false
                },
                {
                    action: "refresh",
                    name: qsTr("Refresh containers"),
                    status: loading ? qsTr("Scanning Distrobox") : qsTr("Rescan available containers"),
                    image: "",
                    running: false
                },
                ...containers
            ];
        }

        return containers.filter(container =>
            `${container.name} ${container.image} ${container.status}`.toLowerCase().includes(query));
    }

    function runInTerminal(args: list<string>): void {
        Quickshell.execDetached({
            command: [
                "systemd-run", "--user", "--scope", "--collect", "--quiet", "--",
                ...Config.general.apps.terminal,
                `${Quickshell.shellDir}/assets/wrap_term_launch.sh`,
                ...args
            ]
        });
    }

    function enter(name: string): void {
        runInTerminal(["distrobox", "enter", name]);
    }

    function create(): void {
        const script = "read -r -p 'Container name: ' name; "
            + "read -r -p 'Container image (for example ubuntu:24.04): ' image; "
            + "if [ -n \"$name\" ] && [ -n \"$image\" ]; then "
            + "distrobox create --name \"$name\" --image \"$image\"; "
            + "else echo 'Both a name and image are required.'; fi; "
            + "read -r -p 'Press Enter to close this window.' _";
        runInTerminal(["bash", "-lc", script]);
    }

    Process {
        id: listProc
        command: ["distrobox", "list", "--no-color"]

        stdout: StdioCollector {
            onStreamFinished: root._output = text
        }

        stderr: StdioCollector {
            onStreamFinished: root._errorOutput = text.trim()
        }

        onExited: (code) => {
            root.loading = false;
            if (code !== 0) {
                root.error = root._errorOutput || qsTr("Could not read Distrobox containers");
                root.containers = [];
                return;
            }

            const result = [];
            for (const line of root._output.split("\n")) {
                if (!line.trim())
                    continue;

                const fields = line.split("|").map(field => field.trim());
                if (fields.length < 3 || fields[1].toLowerCase() === "name")
                    continue;

                const name = fields[1];
                const status = fields[2] || "Unknown";
                if (!name)
                    continue;

                result.push({
                    name,
                    status,
                    image: fields.slice(3).join("|").trim(),
                    running: /^(up|running)\b/i.test(status)
                });
            }
            root.containers = result;
        }
    }
}
