import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.services

// Animated hexagonal-grid wallpaper: grey palette, black accents, light running around hex edges.
// Animates (30 fps) only on AC power, outside game mode and when no window is fullscreen on its monitor;
// otherwise the picture freezes as it is.
Item {
    id: root

    // seconds of animation; the clock only advances while animating
    property real t: 0
    // Set by `hexwall activate`: theme "auto" | "light" | "dark", animation "auto" | "on" | "off"
    property string theme: "auto"
    property string animation: "auto"

    // follows the Caelestia light/dark mode (unless forced), with a short fade
    readonly property bool isLight: theme === "light" || (theme === "auto" && Colours.light)
    property real lightMix: isLight ? 1 : 0
    Behavior on lightMix { NumberAnimation { duration: 500 } }

    // A fullscreen window on this monitor hides the wallpaper completely (same check Caelestia's drawers use)
    readonly property HyprlandMonitor monitor: Hypr.monitorFor((QsWindow.window as QsWindow)?.screen ?? null)
    readonly property string specialWs: monitor?.lastIpcObject.specialWorkspace?.name ?? ""
    readonly property bool covered: {
        const ws = specialWs.length > 0 ? Hypr.workspaces.values.find(w => w.name === specialWs) : monitor?.activeWorkspace;
        return ws?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
    }

    // auto: only on AC power, while Caelestia's game mode is off and nothing is fullscreen on this monitor
    readonly property bool animate: animation === "on" || (animation === "auto" && !UPower.onBattery && !GameMode.enabled && !covered)

    Timer {
        interval: 33
        repeat: true
        running: root.animate
        onTriggered: root.t += 0.033
    }

    ShaderEffect {
        anchors.fill: parent

        property real time: root.t
        property real cell: 64
        property real lightMix: root.lightMix
        property size res: Qt.size(width, height)

        fragmentShader: Qt.resolvedUrl("hexgrid.frag.qsb")
    }
}
