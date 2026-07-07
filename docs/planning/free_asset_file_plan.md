# Dungeon Friends - Free Asset File Plan

**Created:** 2026-07-07  
**Scope:** character and environment art files for the Phase 1 real-art pass
and the Phase 2 tutorial dungeon.  
**Default license rule:** use CC0/Public Domain or first-party generated art.
Use attribution-required assets only after adding a credits file. Do not use
noncommercial, no-redistribution, GPL, or share-alike assets as the default.

## Answer

Use a CC0-first file manifest:

1. Pull Kenney Tiny-series CC0 packs for the base dungeon/town/environment
   vocabulary.
2. Pull Tiny Creatures CC0 for slimes, animals, and early enemy placeholders.
3. Generate or hand-edit Dungeon Friends-specific hero/NPC/party sprites on
   top of the 16x16 runtime art grid so the game has its own identity.
4. Commit only normalized project files, license notes, and source-pack
   manifests. Keep untouched downloaded zips out of the shipped art path.

This keeps the project free to use, free to redistribute as a game, and clean
for a future commercial decision if Kayden changes direction later.

## Approved Source Shortlist

| Source | Use | License | Decision |
|---|---|---|---|
| Kenney Tiny Dungeon | Dungeon walls, floors, doors, chests, keys, weapons, items, simple characters | CC0 1.0 Universal | Default pull source |
| Kenney Tiny Town | Forest/town/overworld tiles, props, paths, fences, house/town pieces | CC0 | Default pull source |
| Tiny Creatures by Clint Bellanger | Slimes, animals, early monsters, boss placeholders | CC0 1.0 Universal | Default pull source |
| First-party generated art | Hero, party member, named NPCs, project-specific props | Project-owned | Default for identity-critical sprites |
| OpenGameArt Tiny 16: Basic | Backup tiles if CC0 packs cannot cover a need | CC-BY 3.0/4.0 or OGA-BY | Backup only; requires attribution |
| Kenmi Cute Fantasy RPG free version | Nice visual fit, but noncommercial/no redistribution | Noncommercial + no redistribution | Reject for this repo |
| LPC base assets | Broad RPG set, but share-alike/GPL | CC-BY-SA 3.0 / GPL 3.0 | Reject unless Kayden explicitly accepts license impact |

## Target Folder Layout

```text
game/assets/
  art/
    raw/
      third_party/
        kenney_tiny_dungeon/
        kenney_tiny_town/
        tiny_creatures/
      generated/
        dungeon_friends/
    sprites/
      characters/
      enemies/
      objects/
    tilesets/
      environment/
      dungeon/
    ui/
  licenses/
    THIRD_PARTY_ASSETS.md
```

Rules:

- `raw/third_party/` keeps source-pack extracts or source sheets.
- `sprites/`, `tilesets/`, and `ui/` hold the normalized files Godot imports.
- `licenses/THIRD_PARTY_ASSETS.md` records source URL, author, license,
  downloaded date, and exact files used.
- If any attribution-required asset is accepted later, the attribution text
  must be added before the art lands in gameplay.

## Required Character Files

| Target file | Need | Source route | Notes |
|---|---|---|---|
| `game/assets/art/sprites/characters/hero_walk.png` | Player overworld movement | Generate first-party | 16x16 source cells, 4 directions, minimum 2 frames each |
| `game/assets/art/sprites/characters/hero_idle.png` | Player idle/facing state | Generate first-party | Can share cells with walk sheet frame 0 |
| `game/assets/art/sprites/characters/hero_combat.png` | Combat menu readability | Generate first-party | Bigger silhouette is acceptable if still pixel-clean |
| `game/assets/art/sprites/characters/npc_old_man.png` | Healer/respawn NPC | Generate first-party or edit CC0 base | Must read distinct from player |
| `game/assets/art/sprites/characters/npc_quest_giver.png` | Quest NPC in forest slice | Generate first-party or edit CC0 base | Different palette and head shape |
| `game/assets/art/sprites/characters/party_friend_01.png` | First recruit placeholder | Generate first-party | Needed before party system, but can land early as art |
| `game/assets/art/sprites/enemies/slime.png` | Regular slime | Pull from Tiny Creatures or generate | Must include hostile color variant |
| `game/assets/art/sprites/enemies/boss_slime.png` | Boss Slime | Edit regular slime or pull larger creature | Larger/darker outline; still grid-readable |
| `game/assets/art/sprites/enemies/tutorial_enemy.png` | Phase 2 key-drop fight | Pull from Tiny Creatures | Pick visually distinct from overworld slimes |

## Required Environment Files

| Target file | Need | Source route | Notes |
|---|---|---|---|
| `game/assets/art/tilesets/environment/forest_ground_16.png` | Grass, dirt path, flowers, edge noise | Pull Kenney Tiny Town or generate | Must support LDtk tiles at 16x16 |
| `game/assets/art/tilesets/environment/forest_props_16.png` | Trees, shrubs, signs, fences, rocks | Pull Kenney Tiny Town + edits | Collision tiles need clear silhouettes |
| `game/assets/art/tilesets/environment/water_16.png` | Later rivers/pond edges | Pull Kenney Tiny Town or defer | Not required for Phase 1 unless used in map |
| `game/assets/art/tilesets/dungeon/dungeon_floor_16.png` | Tutorial dungeon walkable floor | Pull Kenney Tiny Dungeon | Keep contrast below characters |
| `game/assets/art/tilesets/dungeon/dungeon_walls_16.png` | Tutorial dungeon walls/collision | Pull Kenney Tiny Dungeon | Must be readable at 4x runtime scale |
| `game/assets/art/tilesets/dungeon/pits_16.png` | Phase 2 pit/jump mechanic | Generate or edit CC0 tiles | Needs unfilled and filled states |
| `game/assets/art/sprites/objects/push_block.png` | Pushable block | Pull Tiny Dungeon or generate | Should sit exactly one grid cell |
| `game/assets/art/sprites/objects/pressure_plate.png` | Plate pressed/released | Generate or edit CC0 | Needs clear off/on states |
| `game/assets/art/sprites/objects/locked_door.png` | Forest/dungeon door | Pull Tiny Dungeon + edits | Needs locked/unlocked state |
| `game/assets/art/sprites/objects/chest.png` | Locked chest reward | Pull Tiny Dungeon | Needs closed/open states |
| `game/assets/art/sprites/objects/forest_key.png` | Boss Slime drop | Pull Tiny Dungeon or generate | Small icon, still readable in HUD |
| `game/assets/art/sprites/objects/chest_key.png` | Room 3 reward key | Generate recolor | Must differ from forest key |
| `game/assets/art/sprites/objects/shield.png` | Tutorial reward | Pull Tiny Dungeon or generate | Inventory item only for Phase 2 |

## Pull Plan

1. Create `game/assets/art/raw/third_party/` and `game/assets/licenses/`.
2. Download source packs into a temporary `downloads/` directory outside
   `game/assets/art/sprites/` and `game/assets/art/tilesets/`.
3. Extract each pack into its own `raw/third_party/<source>/` folder.
4. Add one row per source to `game/assets/licenses/THIRD_PARTY_ASSETS.md`.
5. Copy only selected PNG sheets into normalized target paths.
6. If a pack ships separate sprites and tilesheets, prefer tilesheets for
   Godot imports and separate sprites only where animation setup is clearer.
7. Run Godot import and the existing smoke test before replacing placeholder
   ColorRect art in scenes.

Candidate source URLs:

- `https://kenney.nl/assets/tiny-dungeon`
- `https://kenney.nl/assets/tiny-town`
- `https://opengameart.org/content/tiny-creatures`

## Generate Plan

Use generation for identity-critical files where a generic pack would make the
game feel like a stock demo:

1. Start from a 16x16 cell grid and the project's bright GBA-fantasy visual
   language.
2. Generate or draw one base sheet per character role.
3. Limit animation scope for now: idle + walk for overworld, simple attack
   pose for combat.
4. Export PNG sheets into `game/assets/art/sprites/characters/`.
5. Record the generator prompt or art script path in
   `game/assets/licenses/THIRD_PARTY_ASSETS.md` under "First-party generated".
6. Verify import in Godot and visually check at 4x runtime scale.

## Acceptance Checklist Per File

- The file has a known source and license.
- The file is free for this repo's use.
- The file can be redistributed as part of the game.
- The file is not noncommercial-only.
- The file is not GPL/share-alike unless Kayden explicitly accepts that.
- The pixel grid matches 16x16 source cells or is documented as an exception.
- The sprite reads at 1280x720 and remains readable at 1920x1080 and 3440x1440.
- Godot imports the file without errors.
- Placeholder ColorRect art is replaced only after the matching target file
  passes import and visual review.

## Verification

For the first asset pull/generation task:

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/main.tscn --quit-after 1
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

Then run one windowed visual check of `scenes/main.tscn`:

- player and NPC silhouettes are distinct;
- enemies read as hostile before contact;
- walls/trees/pits/blocking tiles are visually obvious;
- walkable tiles do not fight the sprites for contrast;
- the 16x16 art still looks intentional at 4x runtime scale.

## Immediate Next Task

Pull only the minimum art needed to replace the current forest placeholder
slice:

1. `forest_ground_16.png`
2. `forest_props_16.png`
3. `hero_walk.png`
4. `npc_old_man.png`
5. `npc_quest_giver.png`
6. `slime.png`
7. `boss_slime.png`
8. `locked_door.png`
9. `forest_key.png`

Do not pull the full world-expansion set yet. Keep Phase 1 focused on proving
real-art readability in the existing playable slice.
