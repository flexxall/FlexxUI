# FlexxUI

Custom **World of Warcraft** interface add-on: unit frames, cast bars, font styling, minimap button, and an in-game options panel.

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

- **Options:** `/flexxui`, `/flexxui config`, or **click the minimap button** (FlexxUI icon).
- **General** — global toggles, reload/reset; **Fonts** — UI and unit typography.
- **Unit Frames** — per-unit tabs (Player, Target, Pet): health, resource text, class bar, cast-related options, name/text overrides.
- **Saved variables:** `FlexxUIDB` (options), `FlexxUILayout` (frame positions from movers).

## Slash commands

| Command | Action |
|--------|--------|
| `/flexxui` | Open settings (same as `/flexxui config`). |
| `/flexxui help` | Short help in chat. |
| `/flexxui version` | Add-on version and WoW interface (TOC) version. |
| `/flexxui config` | Open settings. |
| `/flexxui reload` | `ReloadUI()`. |
| `/flexxui reset` | Reset FlexxUI options to defaults (reloads). |
| `/flexxui resetlayout` | Clear saved frame positions (reloads). |
| `/flexxui texture <name>` | Health bar texture: `none`, `default`, `flat`, `smooth`. |
| `/flexxui color <mode>` | Player health color: `class`, `blizzard`, `dark`. |

Aliases: `/flexx` where applicable.

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

## Repository

- **GitHub:** [flexxall/FlexxUI](https://github.com/flexxall/FlexxUI)
- **Clone:** `git clone https://github.com/flexxall/FlexxUI.git`
