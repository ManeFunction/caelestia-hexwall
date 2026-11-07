# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.9.0] - 2026-11-07
### Added
- Initial release: an animated hexagonal-grid wallpaper for the Caelestia shell.
- Two different palettes follows the Caelestia light and dark mode.
- Animates only on AC power and freezes on battery by default; `--animate on|off|auto` overrides it, and
  `--theme light|dark|auto` forces the palette.
- The `hexwall` command: `hexwall activate | deactivate | status` to add the wallpaper to the Caelestia shell; `install.sh` for installing without Homebrew (and `./install.sh --uninstall` to remove everything).
- `activate` and `deactivate` restart the shell so the change shows at once; `--no-restart` skips that.
- Homebrew formula in `manefunction/tap`.
