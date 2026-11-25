import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import qs.services

// Animated hexagonal-grid wallpaper: grey palette, black accents, light running around hex edges.
// Animates (30 fps) only on AC power, outside game mode and when no window is fullscreen on its monitor;
// otherwise the picture freezes as it is.
Item {
    id: root

    // seconds of animation; the clock only advances while animating
    property real t: 0
    // Set by `hexwall activate`: theme "auto" | "light" | "dark", animation "auto" | "on" | "off",
    // size: hex size multiplier (1 = hexes 64 px apart; lines and glow keep their width in pixels),
    // shift: moves the whole pattern down by a part of a hex height (0 to 1),
    // seed: hex pattern from 0 to 65535, or -1 for a random one at every launch
    property string theme: "auto"
    property string animation: "auto"
    property real size: 1
    property real shift: 0
    property int seed: -1

    // The pattern shown (which hexes are lighter, darker or black, and when each one lights up): the set seed,
    // or a random one picked when the wallpaper loads, so each monitor gets its own
    readonly property int currentSeed: seed >= 0 ? seed : Math.floor(Math.random() * 65536)

    // `hexwall status` reads the seed in use from $XDG_RUNTIME_DIR/caelestia-hexwall/<monitor>.seed
    // (emptied at logout, like the random seeds it holds)
    readonly property string seedPath: {
        const dir = Quickshell.env("XDG_RUNTIME_DIR");
        const name = (QsWindow.window as QsWindow)?.screen?.name ?? "";
        return dir && name ? `${dir}/caelestia-hexwall/${name}.seed` : "";
    }
    onSeedPathChanged: saveSeed()
    Component.onCompleted: saveSeed()

    function saveSeed(): void {
        if (!seedPath)
            return;
        seedFile.path = seedPath;
        seedFile.setText(`${currentSeed}\n`);
    }

    FileView {
        id: seedFile
        preload: false
        blockWrites: true
    }

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
        // Opaque: drawn without blending, and the still wallpaper hidden behind it is skipped by the depth test
        blending: false

        // Animation phases, wrapped here in double precision so the shader never sees a large time value
        property real pulse: (root.t * 0.35) % (2 * Math.PI)
        property real spin: (root.t * 1.1) % (2 * Math.PI)
        property real cell: 64 * root.size
        property real shift: root.shift
        property real lightMix: root.lightMix
        property size res: Qt.size(width, height)
        // the dither pattern works on device pixels (1.6 per logical pixel at 160% scale)
        property real dpr: (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1
        property real seed: root.currentSeed

        vertexShader: Qt.resolvedUrl("hexgrid.vert.qsb")
        fragmentShader: Qt.resolvedUrl("hexgrid.frag.qsb")
    }
}
