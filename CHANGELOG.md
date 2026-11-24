# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]
### Changed
- About half the GPU time per frame, with the same picture. The shader does a third less work per pixel (no `atan`,
  the theme and per-frame maths moved out of it into a vertex shader), and it is drawn opaque, so the still
  wallpaper hidden under it is no longer drawn every frame.

### Fixed
- After about a day of accumulated animation the light froze (or jumped around) while the wallpaper kept
  redrawing: the shader got the time as one big float. The animation phases are now wrapped before they reach it.

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
