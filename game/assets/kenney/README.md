# Kenney Test Asset Library

This folder contains CC0 Kenney packs added for visual and input/UI testing.
The original folder structure, previews, tilemaps, and per-pack `License.txt`
files are preserved so individual assets can be evaluated before runtime use.

## Included Packs

| Pack | Likely project use |
|---|---|
| Input Prompts Pixel | Keyboard/controller prompt experiments (T-079) |
| Pixel UI Pack | Combat, inventory, save/load, and menu framing |
| Roguelike Caves & Dungeons | Tutorial dungeon tiles and props (T-052) |
| Roguelike Characters | Overworld/combat character prototyping (T-053/T-055/T-056) |
| Roguelike Indoors | Interior rooms, furniture, and interactable props |
| Roguelike RPG Pack | General overworld, dungeon, item, and UI prototyping |

## Usage Rules

- All six included packs identify their content as Creative Commons Zero
  (CC0); retain each pack's `License.txt` with its source files.
- Treat these files as an evaluation library, not automatically approved
  runtime art. Copy only selected assets into the established runtime paths
  under `game/assets/art/` when a task adopts them.
- Preserve nearest-neighbor filtering and verify readability against the
  project's 16x16 art-pixel / 4x runtime-cell convention.
- Record the selected source pack and original file path in the matching
  asset task or proof row when an asset is promoted into the game.

Credits are not required by the included CC0 licenses, but the project should
credit Kenney (`kenney.nl`) in a future credits surface as a courtesy if these
assets ship.
