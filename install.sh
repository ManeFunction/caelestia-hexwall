#!/usr/bin/env bash
# Installer for caelestia-hexwall, no Homebrew needed.
#   ./install.sh                 install the tool into ~/.local and activate the wallpaper in Caelestia
#   ./install.sh --theme dark    also --animate on|off|auto (defaults: auto, auto)
#   ./install.sh --no-activate      only install the tool, activate later with: hexwall activate
#   ./install.sh --uninstall     deactivate the wallpaper in Caelestia AND remove the tool
# Options: --prefix DIR (default ~/.local), --shell-dir DIR (Caelestia config), --no-restart (do not restart the shell)
set -euo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
PREFIX="${PREFIX:-$HOME/.local}"
mode="install"
activate=1
pass=()

while [ $# -gt 0 ]; do
    case "$1" in
        --uninstall) mode="uninstall"; shift ;;
        --no-activate) activate=0; shift ;;
        --prefix) [ $# -ge 2 ] || { echo "--prefix needs a value" >&2; exit 1; }; PREFIX="$2"; shift 2 ;;
        --theme|--animate|--shell-dir) [ $# -ge 2 ] || { echo "$1 needs a value" >&2; exit 1; }; pass+=("$1" "$2"); shift 2 ;;
        --no-restart) pass+=("$1"); shift ;;
        -h|--help) sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

BIN="$PREFIX/bin/hexwall"
DATA="$PREFIX/share/caelestia-hexwall"

if [ "$mode" = "uninstall" ]; then
    # take the wallpaper out of Caelestia first (while the tool still exists), then the tool itself
    if [ -x "$BIN" ]; then
        "$BIN" deactivate ${pass[@]+"${pass[@]}"} || echo "could not remove it from Caelestia (already gone?), continuing"
    elif [ -x "$HERE/bin/hexwall" ]; then
        HEXWALL_DATA="$HERE/share/caelestia-hexwall" "$HERE/bin/hexwall" deactivate ${pass[@]+"${pass[@]}"} || true
    fi
    rm -f "$BIN"
    rm -rf "$DATA"
    echo "hexwall removed from $PREFIX"
    exit 0
fi

[ -f "$HERE/bin/hexwall" ] || { echo "run this script from the caelestia-hexwall folder" >&2; exit 1; }
mkdir -p "$PREFIX/bin" "$DATA"
install -m 755 "$HERE/bin/hexwall" "$BIN"
cp "$HERE"/share/caelestia-hexwall/* "$DATA/"
echo "installed to $PREFIX (command: $BIN)"

case ":$PATH:" in *":$PREFIX/bin:"*) ;; *) echo "note: $PREFIX/bin is not in your PATH" ;; esac

if [ "$activate" = 1 ]; then
    "$BIN" activate ${pass[@]+"${pass[@]}"}
else
    echo "activate it with: hexwall activate"
fi
