import Quickshell
import Quickshell.Wayland

PanelWindow {
    required property string name

    WlrLayershell.namespace: `kuroShell-${name}`
    color: "transparent"
}
