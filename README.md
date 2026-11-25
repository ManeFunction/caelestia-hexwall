# caelestia-hexwall

An animated hexagonal-grid wallpaper for the [Caelestia](https://github.com/caelestia-dots/shell) shell. Caelestia
itself only supports still images as wallpapers; this adds an optimmized, abstract hexes grid drawn with a code (no video).

Made with a tiny shader patched right to your shell.

![](https://raw.githubusercontent.com/wiki/ManeFunction/caelestia-hexwall/dark.png)
[> watch animated video (~4.5 Mb)](https://raw.githubusercontent.com/wiki/ManeFunction/caelestia-hexwall/dark.mp4)
 
![](https://raw.githubusercontent.com/wiki/ManeFunction/caelestia-hexwall/light.png)
[> watch animated video (~4.5 Mb)](https://raw.githubusercontent.com/wiki/ManeFunction/caelestia-hexwall/light.mp4)

You can change hexes `--size`, vertical `--shift` and pin your favourite random pattern with `--seed` parameters:
![](https://raw.githubusercontent.com/wiki/ManeFunction/caelestia-hexwall/big-hex.png)

## Features

- **Hexagonal grid** with light running along the hex edges, in greys with black accents. The pattern is new at
  every launch, or the one you keep with `--seed`.
- **Power aware:** by default it animates (about 30 fps) only on AC power and freezes the picture as it is on
  battery, while Caelestia's game mode is on, or while a window is fullscreen on that monitor. `--animate on|off` overrides that.
- **Follows the theme:** by default it switches between light and dark palettes when Caelestia is in light or dark mode accordingly.
  `--theme light|dark` forces one.
- **Light on the system:** one shader pass, no video, no extra daemon. It is drawn by the shell itself, on top of
  your normal wallpaper.
- **Easy to remove:** `hexwall deactivate` puts the shell back exactly as it was.

## Installation

**caelestia-hexwall** is available from a few sources.

1) **Homebrew**
    - Type `brew tap manefunction/tap` in your Terminal to add my custom tap (app source) to your brew sources,
      if you haven't already.
    - Type `brew install caelestia-hexwall` to install the application itself.
    - Verify the installation with `hexwall --version` (or `-v`).
    - Type `hexwall activate` to add the wallpaper to your Caelestia shell.
    - You are perfect, you can tune your wallpaper settings with `hexwall` from any folder in your system.
2) **Install script (no Homebrew needed)**
    - Clone the repository or download the source code from GitHub.
    - Go to the folder with the code in your Terminal.
    - Run `./install.sh`. It installs the command into `~/.local/bin` and activates the wallpaper in your
      Caelestia shell.
    - Run `hexwall --version` (or `-v`) to verify the install.

## Usage

```bash
hexwall activate                  # add the wallpaper
hexwall activate --theme dark     # force the dark palette
hexwall activate --animate on     # animate on battery too
hexwall activate --size 2         # hexes twice as big
hexwall activate --shift 0.5      # the whole pattern half a hex lower
hexwall activate --seed 41234     # keep one pattern instead of a new one at every launch
hexwall status                    # is it active, with which options and which seed
hexwall deactivate                # disable hexwall
```

- `--theme`: `light`, `dark`, or `auto` (follow the Caelestia light/dark mode). Default: `auto`.
- `--animate`: `on` (always), `off` (still picture), or `auto` (only on AC power, frozen on battery, in game
  mode and behind fullscreen windows). Default: `auto`.
- `--size`: hex size, from `0.25` to `8` (`1.5` works too). `2` makes the hexes twice as big; the lines and the
  light keep their width. Default: `1`.
- `--shift`: moves the whole pattern down by a part of a hex height, from `0` to `1` (one whole hex), e.g. `0.5`.
  Default: `0`.
- `--seed`: the hex pattern. `random` picks a new one at every launch, a different one on each monitor. A number
  from `0` to `65535` keeps that pattern on every monitor, through restarts and reboots. Default: `random`.
  `hexwall status` shows the seed in use (`seed: random, now 41234 on eDP-1`), so you can keep a pattern you like.

Every `activate` sets all the options; the ones you leave out go back to their defaults.

`activate` and `deactivate` restart the shell (`caelestia shell -r -d`) so the change shows at once. Open panels
and notifications disappear when it restarts. With `--no-restart` the tool leaves it to you and prints the command.

**Removing it**

- Installed with brew: run `hexwall deactivate` first, then `brew uninstall caelestia-hexwall`
  (brew does not know about the changes inside your Caelestia folder).
- Installed with the script: `./install.sh --uninstall` deactivates the wallpaper in Caelestia and
  removes the command itself.

**Things to know**

- The shell folder is `~/.config/quickshell/caelestia`, or `$CAELESTIA_SHELL_DIR`, or `--shell-dir DIR`.
- If you use the packaged Caelestia (for example the Fedora COPR build in `/etc/xdg/quickshell/caelestia`), there is
  no personal copy yet: `activate` makes one and puts the wallpaper into it. A personal copy takes precedence over
  the system one, so after upgrading Caelestia re-create it (delete `~/.config/quickshell/caelestia`, then run
  `activate` again). If you already keep your own copy there, only the wallpaper is added to it.
- Needs a Caelestia version whose `modules/background/Background.qml` has the `Visualiser` block. If the file
  looks different, `activate` stops and changes nothing.
- It draws over the still wallpaper, so that image stays underneath and is not changed.

## How it works

`activate` copies `HexWallpaper.qml` and the compiled shaders `hexgrid.vert.qsb` and `hexgrid.frag.qsb` into
`modules/background/` of the shell and inserts one `Loader` (marked with `caelestia-hexwall:begin/end` comments)
into `Background.qml`. `deactivate` removes exactly that block and those files. The wallpaper writes the seed it
uses to `$XDG_RUNTIME_DIR/caelestia-hexwall/<monitor>.seed` (emptied at logout), where `status` finds it. The
animation clock stops while UPower reports that the machine runs on battery or Caelestia's game mode is on, and the
colours follow Caelestia's `Colours.light`.

## Development

```bash
bash tests/test.sh      # runs against a fake Caelestia folder
shellcheck bin/hexwall install.sh tests/test.sh shader/build.sh
shader/build.sh         # after editing the shaders: recompiles share/caelestia-hexwall/*.qsb (needs Qt's qsb)
```

## Credits

Built on [Quickshell](https://quickshell.org/) and the Caelestia shell. This is an unofficial add-on and is not
affiliated with the Caelestia project. Tested on Hyprland with the Fedora build of Caelestia 2.5.0 on Intel
graphics; other setups are untested.

## Repository info

This repo follows the [Conventional Commits](https://www.conventionalcommits.org/) specification.

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/ManeFunction/caelestia-hexwall)](https://github.com/ManeFunction/caelestia-hexwall/releases/latest)
[![GitHub All Releases](https://img.shields.io/github/downloads/ManeFunction/caelestia-hexwall/total)](https://github.com/ManeFunction/caelestia-hexwall/releases)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/ManeFunction?label=Sponsor&logo=GitHubSponsors&style=flat)](https://github.com/sponsors/ManeFunction)
