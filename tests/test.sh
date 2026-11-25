#!/usr/bin/env bash
# Tests against a fake Caelestia shell folder; no Caelestia needed.
# check() evals single-quoted strings, so BG etc. are used there (SC2034/SC2016).
# shellcheck disable=SC2016,SC2034
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/bin/hexwall"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# stub `caelestia` so the tests never touch a real shell; it logs its arguments
mkdir -p "$TMP/stub"
printf '#!/bin/sh\necho "$@" >> "%s/caelestia.log"\n' "$TMP" > "$TMP/stub/caelestia"
chmod +x "$TMP/stub/caelestia"
export PATH="$TMP/stub:$PATH"
# where the running wallpaper leaves the seeds it picked; never the real one
export XDG_RUNTIME_DIR="$TMP/run"
mkdir -p "$XDG_RUNTIME_DIR"
fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

fake_shell() { # $1 = dir
    mkdir -p "$1/modules/background"
    : > "$1/shell.qml"
    cat > "$1/modules/background/Background.qml" <<'QML'
Item {
    Loader {
        id: wallpaper
        sourceComponent: Wallpaper {}
    }

            Visualiser {
                anchors.fill: parent
            }
}
QML
}

SH="$TMP/shell"; fake_shell "$SH"
cp "$SH/modules/background/Background.qml" "$TMP/orig.qml"
BG="$SH/modules/background/Background.qml"

check "--version prints name and version" '[ "$("$TOOL" --version)" = "hexwall v$(sed -n "s/^VERSION=\"\(.*\)\"/\1/p" "$TOOL")" ]'
check "-v is the same as --version" '[ "$("$TOOL" -v)" = "$("$TOOL" --version)" ]'
check "VERSION is semver" 'grep -Eq "^VERSION=\"[0-9]+\.[0-9]+\.[0-9]+\"" "$TOOL"'

"$TOOL" activate --shell-dir "$SH" >/dev/null
check "activate restarts the shell by default" '[ "$(grep -c "shell -r -d" "$TMP/caelestia.log")" = 1 ]'
"$TOOL" activate --no-restart --shell-dir "$SH" >/dev/null
check "--no-restart does not restart" '[ "$(grep -c "shell -r -d" "$TMP/caelestia.log")" = 1 ]'
"$TOOL" deactivate --shell-dir "$SH" >/dev/null
check "deactivate restarts the shell by default" '[ "$(grep -c "shell -r -d" "$TMP/caelestia.log")" = 2 ]'
"$TOOL" activate --shell-dir "$SH" >/dev/null
check "activate adds the hex loader once" '[ "$(grep -c "sourceComponent: HexWallpaper {" "$BG")" = 1 ]'
check "activate copies the files" '[ -f "$SH/modules/background/HexWallpaper.qml" ] && [ -f "$SH/modules/background/hexgrid.vert.qsb" ] && [ -f "$SH/modules/background/hexgrid.frag.qsb" ]'
check "loader is placed before Visualiser" '[ "$(grep -n "caelestia-hexwall:begin" "$BG" | cut -d: -f1)" -lt "$(grep -n "Visualiser {" "$BG" | cut -d: -f1)" ]'

"$TOOL" activate --shell-dir "$SH" >/dev/null
check "activate twice does not duplicate" '[ "$(grep -c "caelestia-hexwall:begin" "$BG")" = 1 ]'


check "default options are auto" '"$TOOL" status --shell-dir "$SH" | grep -q "theme: auto" && "$TOOL" status --shell-dir "$SH" | grep -q "animate: auto"'
check "default size is 1" 'grep -qE "^ +size: 1$" "$BG" && "$TOOL" status --shell-dir "$SH" | grep -qx "size: 1"'
check "default seed is random" 'grep -qE "^ +seed: -1$" "$BG" && "$TOOL" status --shell-dir "$SH" | grep -qx "seed: random"'
"$TOOL" activate --theme light --animate off --size 1.5 --shell-dir "$SH" >/dev/null
check "theme, animate and size are written" 'grep -q "theme: \"light\"" "$BG" && grep -q "animation: \"off\"" "$BG" && grep -qE "^ +size: 1.5$" "$BG"'
check "status shows them" '"$TOOL" status --shell-dir "$SH" | grep -q "theme: light" && "$TOOL" status --shell-dir "$SH" | grep -q "animate: off" && "$TOOL" status --shell-dir "$SH" | grep -qx "size: 1.5"'
"$TOOL" activate --shell-dir "$SH" >/dev/null
check "options not given go back to the defaults" 'grep -q "theme: \"auto\"" "$BG" && grep -q "animation: \"auto\"" "$BG" && grep -qE "^ +size: 1$" "$BG"'
check "options are not duplicated" '[ "$(grep -c "theme:" "$BG")" = 1 ] && [ "$(grep -c "size:" "$BG")" = 1 ]'
if "$TOOL" activate --style hex --shell-dir "$SH" >/dev/null 2>&1; then bad "--style option is gone"; else ok "--style option is gone"; fi
if "$TOOL" activate --theme blue --shell-dir "$SH" >/dev/null 2>&1; then bad "unknown theme is rejected"; else ok "unknown theme is rejected"; fi
if "$TOOL" activate --animate maybe --shell-dir "$SH" >/dev/null 2>&1; then bad "unknown animate value is rejected"; else ok "unknown animate value is rejected"; fi
for s in 0 0.1 9 -1 abc 1,5 01 1. .5 "1; color: 2" ""; do
    if "$TOOL" activate --size "$s" --shell-dir "$SH" >/dev/null 2>&1; then bad "size '$s' is rejected"; else ok "size '$s' is rejected"; fi
done
check "a rejected size leaves the block alone" 'grep -qE "^ +size: 1$" "$BG" && [ "$(grep -c "caelestia-hexwall:begin" "$BG")" = 1 ]'
for s in 0.25 8 2; do "$TOOL" activate --size "$s" --shell-dir "$SH" >/dev/null || bad "size $s is accepted"; done
check "sizes at the limits are accepted" 'grep -qE "^ +size: 2$" "$BG"'
sed -i '/^ *size: /d' "$BG"
check "a block from before --size reports size 1" '"$TOOL" status --shell-dir "$SH" | grep -qx "size: 1"'
"$TOOL" activate --shell-dir "$SH" >/dev/null

"$TOOL" activate --seed 1234 --shell-dir "$SH" >/dev/null
"$TOOL" activate --seed 1234 --shell-dir "$SH" >/dev/null
check "--seed is written and shown" 'grep -qE "^ +seed: 1234$" "$BG" && "$TOOL" status --shell-dir "$SH" | grep -qx "seed: 1234"'
check "seed is not duplicated" '[ "$(grep -c "seed:" "$BG")" = 1 ]'
for s in -1 65536 99999 123456 abc 1.5 01 00 0x10 " 1" "1; color: 2" ""; do
    if "$TOOL" activate --seed "$s" --shell-dir "$SH" >/dev/null 2>&1; then bad "seed '$s' is rejected"; else ok "seed '$s' is rejected"; fi
done
check "a rejected seed leaves the block alone" 'grep -qE "^ +seed: 1234$" "$BG"'
for s in 0 65535; do "$TOOL" activate --seed "$s" --shell-dir "$SH" >/dev/null || bad "seed $s is accepted"; done
check "seeds at the limits are accepted" 'grep -qE "^ +seed: 65535$" "$BG"'
"$TOOL" activate --seed random --shell-dir "$SH" >/dev/null
check "--seed random goes back to a random seed" 'grep -qE "^ +seed: -1$" "$BG"'
# the running wallpaper writes the seed it picked, one file per monitor
mkdir -p "$XDG_RUNTIME_DIR/caelestia-hexwall"
echo 41234 > "$XDG_RUNTIME_DIR/caelestia-hexwall/DP-1.seed"
check "status shows the random seed in use" '"$TOOL" status --shell-dir "$SH" | grep -qx "seed: random, now 41234 on DP-1"'
echo 517 > "$XDG_RUNTIME_DIR/caelestia-hexwall/DP-2.seed"
echo "oops" > "$XDG_RUNTIME_DIR/caelestia-hexwall/DP-3.seed"
check "status lists every monitor and skips broken files" '"$TOOL" status --shell-dir "$SH" | grep -qx "seed: random, now 41234 on DP-1, 517 on DP-2"'
"$TOOL" activate --seed 7 --shell-dir "$SH" >/dev/null
check "a set seed is shown as set" '"$TOOL" status --shell-dir "$SH" | grep -qx "seed: 7"'
sed -i '/^ *seed: /d' "$BG"
check "a block from before --seed reports a random seed" '"$TOOL" status --shell-dir "$SH" | grep -q "^seed: random"'
rm -r "$XDG_RUNTIME_DIR/caelestia-hexwall"
"$TOOL" activate --shell-dir "$SH" >/dev/null

check "status reports it" '"$TOOL" status --shell-dir "$SH" | grep -q "active: yes"'
"$TOOL" deactivate --shell-dir "$SH" >/dev/null
check "deactivate restores Background.qml exactly" 'cmp -s "$BG" "$TMP/orig.qml"'
check "deactivate removes the files" '[ ! -e "$SH/modules/background/HexWallpaper.qml" ] && [ ! -e "$SH/modules/background/hexgrid.vert.qsb" ] && [ ! -e "$SH/modules/background/hexgrid.frag.qsb" ]'
check "status after deactivate" '"$TOOL" status --shell-dir "$SH" | grep -q "active: no"'


BAD="$TMP/bad"; fake_shell "$BAD"; echo "Item {}" > "$BAD/modules/background/Background.qml"
if "$TOOL" activate --shell-dir "$BAD" >/dev/null 2>&1; then bad "unexpected Background.qml is refused"; else ok "unexpected Background.qml is refused"; fi
check "refused activation leaves the file alone" '[ "$(cat "$BAD/modules/background/Background.qml")" = "Item {}" ]'

if "$TOOL" activate --shell-dir "$TMP/nothing" >/dev/null 2>&1; then bad "missing shell is refused"; else ok "missing shell is refused"; fi

# installer script: install, apply, uninstall everything
PFX="$TMP/prefix"; SH2="$TMP/shell2"; fake_shell "$SH2"
"$ROOT/install.sh" --prefix "$PFX" --shell-dir "$SH2" --size 2 --seed 42 >/dev/null
check "install.sh installs the tool" '[ -x "$PFX/bin/hexwall" ] && [ -f "$PFX/share/caelestia-hexwall/HexWallpaper.qml" ]'
check "install.sh applies it" 'grep -q "sourceComponent: HexWallpaper {" "$SH2/modules/background/Background.qml"'
check "install.sh passes --size and --seed on" 'grep -qE "^ +size: 2$" "$SH2/modules/background/Background.qml" && grep -qE "^ +seed: 42$" "$SH2/modules/background/Background.qml"'
check "installed tool finds its data" '"$PFX/bin/hexwall" status --shell-dir "$SH2" | grep -q "active: yes"'
"$ROOT/install.sh" --uninstall --prefix "$PFX" --shell-dir "$SH2" >/dev/null
check "install.sh --deactivate removes tool and wallpaper" '[ ! -e "$PFX/bin/hexwall" ] && [ ! -d "$PFX/share/caelestia-hexwall" ] && ! grep -q "caelestia-hexwall" "$SH2/modules/background/Background.qml"'

if [ "$fails" = 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
