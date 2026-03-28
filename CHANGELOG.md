# Changelog

All notable changes to **FlexxUI** are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- (Add items as you work.)

---

## [0.1.0] - 2026-03-27

### Added

- Initial public packaging with versioned releases, `CHANGELOG.md`, and `README.md`.
- Runtime version via `ns.version` (from `## Version` in `FlexxUI.toc`) and `/flexxui version`.
- `/flexxui help` — short command reference.

### Features (existing in this release)

- **Options** — `/flexxui`, `/flexxui config` — settings UI: General (settings + fonts), Unit Frames (player / target / pet), Debug.
- **Shell** — lock/unlock, movers, layout; saved positions in `FlexxUILayout`.
- **Unit frames** — player, target, pet: health/power, name text, class bar pips, optional hide Blizzard frames.
- **Cast bars** — player and target cast bars with layout options.
- **Fonts** — UI and unit font presets and scaling.
- **Slash commands** — `log`, `logdiag`, `reload`, `reset`, `resetlayout`, `texture`, `color`, `castpreview`, etc. (see README).

[Unreleased]: https://github.com/flexxall/FlexxUI/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/flexxall/FlexxUI/releases/tag/v0.1.0
