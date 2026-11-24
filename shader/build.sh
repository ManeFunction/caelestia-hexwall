#!/usr/bin/env bash
# Compiles the shaders into the Qt shader packs that hexwall installs (run it after editing them):
#   shader/hexgrid.vert -> share/caelestia-hexwall/hexgrid.vert.qsb
#   shader/hexgrid.frag -> share/caelestia-hexwall/hexgrid.frag.qsb
# Needs qsb, the Qt Shader Baker (Fedora: qt6-qtshadertools). QSB=/path/to/qsb picks a specific one.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_qsb() {
    if [ -n "${QSB:-}" ]; then [ -x "$QSB" ] || return 1; echo "$QSB"; return 0; fi
    if command -v qsb >/dev/null 2>&1; then command -v qsb; return 0; fi
    # usually not in PATH: look in Qt's own bin folder
    local dir
    for dir in "$(qtpaths6 --query QT_HOST_BINS 2>/dev/null)" /usr/lib64/qt6/bin /usr/lib/qt6/bin; do
        if [ -n "$dir" ] && [ -x "$dir/qsb" ]; then echo "$dir/qsb"; return 0; fi
    done
    return 1
}

qsb="$(find_qsb)" || { echo "qsb not found: install the Qt 6 shader tools, or set QSB to its path" >&2; exit 1; }

# -p compiles per target, so GLSL 120 / ES 100 get no `flat`; 300 es is for GLES builds of Qt
for s in vert frag; do
    "$qsb" --glsl "100 es,120,150,300 es" --hlsl 50 --msl 12 -p \
        -o "$ROOT/share/caelestia-hexwall/hexgrid.$s.qsb" "$ROOT/shader/hexgrid.$s"
    echo "built share/caelestia-hexwall/hexgrid.$s.qsb"
done
