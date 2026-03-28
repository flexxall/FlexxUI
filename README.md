# FlexxUI

Custom **World of Warcraft** interface add-on: unit frames, cast bars, font styling, a small control shell, and an in-game options panel.

**Repository:** [github.com/flexxall/FlexxUI](https://github.com/flexxall/FlexxUI) · clone: `https://github.com/flexxall/FlexxUI.git`

**Version:** see `FlexxUI.toc` (`## Version`) — also shown in-game with `/flexxui version`.

## Requirements

- **World of Warcraft** — install the add-on folder under `World of Warcraft\_retail_\Interface\AddOns\FlexxUI` (or your client’s equivalent `Interface\AddOns` path).
- **Interface version** — `FlexxUI.toc` lists `## Interface:`; match or exceed your game’s TOC when updating the client (update this number when targeting a new WoW patch).

## Installation

1. Copy the `FlexxUI` folder into `Interface\AddOns\`.
2. Ensure the directory layout includes at least `FlexxUI.toc`, `FlexxUI.lua`, and the `core\`, `modules\`, and `Media\` folders.
3. Enable **FlexxUI** on the character select **AddOns** screen.
4. `/reload` in-game after replacing files.

## Configuration

- **Options:** `/flexxui config` or `/flexxui settings` — or use the shell **Settings** button if the shell is visible.
- **General** — global toggles, reload/reset; **Fonts** — UI and unit typography.
- **Unit Frames** — per-unit tabs (Player, Target, Pet): health, resource text, class bar, cast-related options, name/text overrides.
- **Saved variables:** `FlexxUIDB` (options), `FlexxUILayout` (frame positions from movers).

## Slash commands

| Command | Action |
|--------|--------|
| `/flexxui` | Toggle the FlexxUI shell (when loaded). |
| `/flexxui help` | Short help in chat. |
| `/flexxui version` | Add-on version and WoW interface (TOC) version. |
| `/flexxui config` | Open settings. |
| `/flexxui log` | Toggle output log window. |
| `/flexxui logdiag` | Log diagnostics (if available). |
| `/flexxui reload` | `ReloadUI()`. |
| `/flexxui reset` | Reset FlexxUI options to defaults (reloads). |
| `/flexxui resetlayout` | Clear saved frame positions (reloads). |
| `/flexxui castpreview` | Toggle cast bar layout preview. |
| `/flexxui texture <name>` | Health bar texture: `none`, `default`, `flat`, `smooth`. |
| `/flexxui color <mode>` | Player health color: `class`, `blizzard`, `dark`. |

Aliases: `/flexx` where applicable.

## Versioning

- **Semantic versioning** — `MAJOR.MINOR.PATCH` in `FlexxUI.toc` (`## Version`).
- **Changelog** — see [CHANGELOG.md](./CHANGELOG.md). For each release: bump `## Version`, add a section under `CHANGELOG.md`, and tag in git (`v0.1.0`, etc.).

## Development

- **Lua** — no external build step; edit and `/reload`.
- **TOC** — list new `.lua` files in load order in `FlexxUI.toc`.

## License

Specify your license here (e.g. MIT, All Rights Reserved) when you publish the repository.

## Git workflow (optional)

From the `FlexxUI` add-on directory:

```bash
git init
git add .
git commit -m "Initial release v0.1.0"
git remote add origin https://github.com/flexxall/FlexxUI.git
git branch -M main
git push -u origin main
git tag -a v0.1.0 -m "v0.1.0"
git push origin v0.1.0
```

Keep `## Version` in `FlexxUI.toc`, `CHANGELOG.md`, and git tags in sync when you release.

## Repository

- **GitHub:** [flexxall/FlexxUI](https://github.com/flexxall/FlexxUI)
- **Clone:** `git clone https://github.com/flexxall/FlexxUI.git`
