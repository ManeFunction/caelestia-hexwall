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
check "default shift is 0" 'grep -qE "^ +shift: 0$" "$BG" && "$TOOL" status --shell-dir "$SH" | grep -qx "shift: 0"'
check "default seed is random" 'grep -qE "^ +seed: -1$" "$BG" && "$TOOL" status --shell-dir "$SH" | grep -qx "seed: random"'
"$TOOL" activate --theme light --animate off --size 1.5 --shift 0.5 --shell-dir "$SH" >/dev/null
check "theme, animate, size and shift are written" 'grep -q "theme: \"light\"" "$BG" && grep -q "animation: \"off\"" "$BG" && grep -qE "^ +size: 1.5$" "$BG" && grep -qE "^ +shift: 0.5$" "$BG"'
check "status shows them" '"$TOOL" status --shell-dir "$SH" | grep -q "theme: light" && "$TOOL" status --shell-dir "$SH" | grep -q "animate: off" && "$TOOL" status --shell-dir "$SH" | grep -qx "size: 1.5" && "$TOOL" status --shell-dir "$SH" | grep -qx "shift: 0.5"'
"$TOOL" activate --shell-dir "$SH" >/dev/null
check "options not given go back to the defaults" 'grep -q "theme: \"auto\"" "$BG" && grep -q "animation: \"auto\"" "$BG" && grep -qE "^ +size: 1$" "$BG" && grep -qE "^ +shift: 0$" "$BG"'
check "options are not duplicated" '[ "$(grep -c "theme:" "$BG")" = 1 ] && [ "$(grep -c "size:" "$BG")" = 1 ] && [ "$(grep -c "shift:" "$BG")" = 1 ]'
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

"$TOOL" activate --shift 0.5 --shell-dir "$SH" >/dev/null
for s in -0.5 1.01 2 abc .5 01 1. 0,5 "0; color: 1" ""; do
    if "$TOOL" activate --shift "$s" --shell-dir "$SH" >/dev/null 2>&1; then bad "shift '$s' is rejected"; else ok "shift '$s' is rejected"; fi
done
check "a rejected shift leaves the block alone" 'grep -qE "^ +shift: 0.5$" "$BG"'
for s in 0 1 0.25; do "$TOOL" activate --shift "$s" --shell-dir "$SH" >/dev/null || bad "shift $s is accepted"; done
check "shifts at the limits are accepted" 'grep -qE "^ +shift: 0.25$" "$BG"'
sed -i '/^ *shift: /d' "$BG"
check "a block from before --shift reports shift 0" '"$TOOL" status --shell-dir "$SH" | grep -qx "shift: 0"'
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
check "status shows the random seed in use under its monitor" '"$TOOL" status --shell-dir "$SH" | grep -A1 -x "Monitor DP-1:" | grep -qx "  seed: random, now 41234"'
check "the main seed line stays plain" '"$TOOL" status --shell-dir "$SH" | grep -qx "seed: random"'
echo 517 > "$XDG_RUNTIME_DIR/caelestia-hexwall/DP-2.seed"
echo "oops" > "$XDG_RUNTIME_DIR/caelestia-hexwall/DP-3.seed"
check "status lists every monitor and skips broken files" '[ "$("$TOOL" status --shell-dir "$SH" | sed -n "/^Monitor/,\$p")" = "$(printf "Monitor DP-1:\n  seed: random, now 41234\nMonitor DP-2:\n  seed: random, now 517")" ]'
"$TOOL" activate --seed 7 --shell-dir "$SH" >/dev/null
check "a set seed is shown as set" '"$TOOL" status --shell-dir "$SH" | grep -qx "seed: 7"'
check "a set seed hides the monitors that use it" '! "$TOOL" status --shell-dir "$SH" | grep -q "^Monitor"'
sed -i '/^ *seed: /d' "$BG"
check "a block from before --seed reports a random seed" '"$TOOL" status --shell-dir "$SH" | grep -q "^seed: random"'
rm -r "$XDG_RUNTIME_DIR/caelestia-hexwall"
"$TOOL" activate --shell-dir "$SH" >/dev/null

# config file: the same options as the flags, plus size, shift and seed per monitor
CFG="$TMP/hexwall.conf"
cat > "$CFG" <<EOF
# a comment
; another one
theme = dark
animate = "off"
size = 1.5
shift = 0.25
seed = 99
shell-dir = $SH
no-restart = yes

[monitor eDP-1]
size = 2
seed = 41234

[monitor HDMI-A-1]
shift = 0.5
seed = random
EOF
before="$(grep -c "shell -r -d" "$TMP/caelestia.log")"
"$TOOL" activate --config "$CFG" >/dev/null
check "--config sets the options" 'grep -q "theme: \"dark\"" "$BG" && grep -q "animation: \"off\"" "$BG" && grep -qE "^ +size: 1.5$" "$BG" && grep -qE "^ +shift: 0.25$" "$BG" && grep -qE "^ +seed: 99$" "$BG"'
check "--config sets shell-dir and no-restart" '[ "$(grep -c "shell -r -d" "$TMP/caelestia.log")" = "$before" ]'
check "--config writes the monitors" 'grep -qF "\"eDP-1\": { size: 2, seed: 41234 }," "$BG" && grep -qF "\"HDMI-A-1\": { shift: 0.5, seed: -1 }" "$BG"'
check "status shows the settings under each monitor" '[ "$("$TOOL" status --shell-dir "$SH" | sed -n "/^Monitor/,\$p")" = "$(printf "Monitor HDMI-A-1:\n  shift: 0.5\n  seed: random\nMonitor eDP-1:\n  size: 2\n  seed: 41234")" ]'
mkdir -p "$XDG_RUNTIME_DIR/caelestia-hexwall"
echo 41234 > "$XDG_RUNTIME_DIR/caelestia-hexwall/eDP-1.seed"
echo 300 > "$XDG_RUNTIME_DIR/caelestia-hexwall/HDMI-A-1.seed"
echo 99 > "$XDG_RUNTIME_DIR/caelestia-hexwall/DP-3.seed"
check "status adds the seeds in use, and skips monitors like the main settings" '[ "$("$TOOL" status --shell-dir "$SH" | sed -n "/^Monitor/,\$p")" = "$(printf "Monitor HDMI-A-1:\n  shift: 0.5\n  seed: random, now 300\nMonitor eDP-1:\n  size: 2\n  seed: 41234")" ]'
rm -r "$XDG_RUNTIME_DIR/caelestia-hexwall"
printf "size = 1.5\n[monitor DP-1]\nsize = 1.50\nshift = 0\n" > "$TMP/same.conf"
"$TOOL" activate --config "$TMP/same.conf" --shell-dir "$SH" --no-restart >/dev/null
check "monitor settings equal to the main ones are not shown" '! "$TOOL" status --shell-dir "$SH" | grep -q "^Monitor"'
"$TOOL" activate --config "$CFG" >/dev/null
check "monitors do not change the global status" '"$TOOL" status --shell-dir "$SH" | grep -qx "size: 1.5" && "$TOOL" status --shell-dir "$SH" | grep -qx "shift: 0.25" && "$TOOL" status --shell-dir "$SH" | grep -qx "seed: 99"'
"$TOOL" activate --size 3 --config "$CFG" --seed random >/dev/null
check "flags win over the config, wherever --config stands" 'grep -qE "^ +size: 3$" "$BG" && grep -qE "^ +seed: -1$" "$BG" && grep -q "theme: \"dark\"" "$BG"'
printf 'theme = light\n' > "$TMP/plain.conf"
"$TOOL" activate --config "$TMP/plain.conf" --shell-dir "$SH" --no-restart >/dev/null
check "a config without monitors writes none" '! grep -q "monitors:" "$BG" && grep -q "theme: \"light\"" "$BG"'
mkdir -p "$TMP/cfgdir"
printf 'shell-dir = ../shell\nno-restart = true\n' > "$TMP/cfgdir/rel.conf"
check "a relative shell-dir starts at the config folder" '"$TOOL" activate --config "$TMP/cfgdir/rel.conf" >/dev/null'
cp "$BG" "$TMP/before-bad.qml"
bad_cfg() { # $1 = name, $2 = config text
    printf '%b' "$2" > "$TMP/bad.conf"
    if "$TOOL" activate --config "$TMP/bad.conf" --shell-dir "$SH" --no-restart >/dev/null 2>&1; then bad "$1"; else ok "$1"; fi
}
bad_cfg "config: unknown key is rejected" 'colour = red\n'
bad_cfg "config: bad theme is rejected" 'theme = blue\n'
bad_cfg "config: bad size is rejected" 'size = 9\n'
bad_cfg "config: bad monitor seed is rejected" '[monitor eDP-1]\nseed = 70000\n'
bad_cfg "config: theme per monitor is rejected" '[monitor eDP-1]\ntheme = dark\n'
bad_cfg "config: unknown section is rejected" '[colors]\n'
bad_cfg "config: unsafe monitor name is rejected" '[monitor "x"]\nsize = 2\n'
bad_cfg "config: a line without = is rejected" 'size 2\n'
bad_cfg "config: bad no-restart is rejected" 'no-restart = maybe\n'
check "a rejected config leaves the block alone" 'cmp -s "$BG" "$TMP/before-bad.qml"'
check "the error names the file and line" '{ "$TOOL" activate --config "$TMP/bad.conf" --shell-dir "$SH" 2>&1 >/dev/null || true; } | grep -qF "bad.conf:1: invalid no-restart"'
if "$TOOL" activate --config "$TMP/missing.conf" --shell-dir "$SH" >/dev/null 2>&1; then bad "missing config is rejected"; else ok "missing config is rejected"; fi
if "$TOOL" activate --config >/dev/null 2>&1; then bad "--config needs a value"; else ok "--config needs a value"; fi
if "$TOOL" activate --config "$CFG" --config "$CFG" >/dev/null 2>&1; then bad "--config only once"; else ok "--config only once"; fi
printf 'size = 2\r\n[monitor DP-1]\r\nshift = 1\r\n' > "$TMP/crlf.conf"
"$TOOL" activate --config "$TMP/crlf.conf" --shell-dir "$SH" --no-restart >/dev/null
check "a config with Windows line ends works" 'grep -qE "^ +size: 2$" "$BG" && grep -qF "\"DP-1\": { shift: 1 }" "$BG"'
"$TOOL" activate --shell-dir "$SH" >/dev/null
check "activate without the config drops the monitors" '! grep -q "monitors:" "$BG" && ! "$TOOL" status --shell-dir "$SH" | grep -q "^monitor"'

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
"$ROOT/install.sh" --prefix "$PFX" --shell-dir "$SH2" --size 2 --shift 0.5 --seed 42 >/dev/null
check "install.sh installs the tool" '[ -x "$PFX/bin/hexwall" ] && [ -f "$PFX/share/caelestia-hexwall/HexWallpaper.qml" ]'
check "install.sh applies it" 'grep -q "sourceComponent: HexWallpaper {" "$SH2/modules/background/Background.qml"'
check "install.sh passes --size, --shift and --seed on" 'grep -qE "^ +size: 2$" "$SH2/modules/background/Background.qml" && grep -qE "^ +shift: 0.5$" "$SH2/modules/background/Background.qml" && grep -qE "^ +seed: 42$" "$SH2/modules/background/Background.qml"'
check "installed tool finds its data" '"$PFX/bin/hexwall" status --shell-dir "$SH2" | grep -q "active: yes"'
"$ROOT/install.sh" --uninstall --prefix "$PFX" --shell-dir "$SH2" >/dev/null
check "install.sh --deactivate removes tool and wallpaper" '[ ! -e "$PFX/bin/hexwall" ] && [ ! -d "$PFX/share/caelestia-hexwall" ] && ! grep -q "caelestia-hexwall" "$SH2/modules/background/Background.qml"'

if [ "$fails" = 0 ]; then echo "all passed"; else echo "$fails failed"; exit 1; fi
