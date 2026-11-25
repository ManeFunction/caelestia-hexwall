# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2026-11-25
### Added
- `--config FILE` takes the options from a text file (`key = value` lines with the same names as the flags:
  `theme`, `animate`, `size`, `shift`, `seed`, `shell-dir`, `no-restart`). Flags on the command line win over it.
- `[monitor NAME]` sections in the config set `size`, `shift` and `seed` for one monitor, so each screen of a
  multi-monitor setup can have its own hex size, placement and pattern.

### Changed
- `hexwall status` groups the per-monitor settings under `Monitor NAME:`, showing only what differs from the main
  settings there; the random seed each monitor picked moved from the `seed:` line into its group.

## [1.1.0] - 2026-11-25
### Added
- `--size` sets the hex size: `hexwall activate --size 2` makes the hexes twice as big (from 0.25 to 8, default 1).
- `--shift N` moves the whole pattern down by a part of a hex height, from 0 to 1 (one whole hex).
- `--seed N` keeps one hex pattern, from 0 to 65535, through restarts and reboots; `random` (the default) picks a
  new one at every launch. `hexwall status` shows the seed in use, so a pattern you like can be kept.

### Changed
- About half the GPU time per frame, with the same picture. The shader does a third less work per pixel (no `atan`,
  the theme and per-frame maths moved out of it into a vertex shader), and it is drawn opaque, so the still
  wallpaper hidden under it is no longer drawn every frame.
- A new random pattern at every launch (shell start, `hexwall activate`): which hexes are lighter, darker or
  black, and when each one lights up. Each monitor gets its own. No extra GPU time.

### Fixed
- After about a day of accumulated animation the light froze (or jumped around) while the wallpaper kept
  redrawing: the shader got the time as one big float. The animation phases are now wrapped before they reach it.
- No more visible bands inside the hexes where the dark gradient steps from one colour level to the next: the
  output is dithered by less than one level (about 3% more GPU time).

## [1.0.0] - 2026-11-19
### Changed
- The animation also pauses while a window is fullscreen on the wallpaper's monitor (in `--animate auto`).

## [0.9.0] - 2026-11-08
### Added
- Initial release: an animated hexagonal-grid wallpaper for the Caelestia shell.
- Two different palettes follows the Caelestia light and dark mode.
- Animates only on AC power and freezes on battery by default; `--animate on|off|auto` overrides it, and
  `--theme light|dark|auto` forces the palette.
- With `--animate auto` the wallpaper also freezes while Caelestia's game mode is on.
- The `hexwall` command: `hexwall activate | deactivate | status` to add the wallpaper to the Caelestia shell; `install.sh` for installing without Homebrew (and `./install.sh --uninstall` to remove everything).
- `activate` and `deactivate` restart the shell so the change shows at once; `--no-restart` skips that.
- Homebrew formula in `manefunction/tap`.
