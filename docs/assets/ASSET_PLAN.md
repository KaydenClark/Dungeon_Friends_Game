# Dungeon Friends - Asset Plan

**Last updated:** 2026-07-11
**Status:** Kenney-first visual skeleton implemented; owner acceptance pending

This file is the asset production checklist for Dungeon Friends. It answers
what must be made, when it should be made, and where image-generation prompts
are recorded.

Keep this file about asset needs and phase timing. Store exact prompts,
negative prompts, model/settings notes, generated file paths, and acceptance
notes in [`IMAGE_PROMPTS.md`](IMAGE_PROMPTS.md).

## Source Of Truth

- Visual direction: `BLUEPRINT.md` -> Visual Language.
- Build order: `BLUEPRINT.md` -> Direction And Build Order.
- Live work queue: `TASKBOARD.md`.
- Runtime art path: `game/assets/art/`.
- Runtime audio path: `game/assets/audio/`.
- Level source path: `game/assets/levels/`.

## Kenney-First Runtime Direction

**Added:** 2026-07-11 under `game/assets/kenney/`.

Six original Kenney packs are checked in as the source library: Input
Prompts Pixel, Pixel UI, Roguelike Caves & Dungeons, Roguelike Characters,
Roguelike Indoors, and Roguelike RPG Pack. Each pack includes its original
CC0 `License.txt`; the library inventory and promotion rules are documented in
`game/assets/kenney/README.md`.

The route in [`KENNEY_IMPLEMENTATION_PLAN.md`](KENNEY_IMPLEMENTATION_PLAN.md)
is implemented through T-083; T-084's automated and windowed QA is green and
awaits Kayden's acceptance. The deterministic selection contract is
`game/assets/art/kenney_manifest.json`, generated runtime crops live under the
`kenney/` folders in `game/assets/art/`, and the review sheet is
`docs/assets/previews/kenney_contact_sheet.png`. Existing generated/prototype
batches below remain later custom-art candidates.

### Custom-art swap points

| Surface | Replace here | Mechanics remain behind |
|---|---|---|
| Forest/dungeon terrain | `game/assets/art/tilesets/kenney/world_tiles.png` and the LDtk tileset definition | LDtk IntGrid/entity layers and `LdtkRoom` collision adoption |
| Interactables | `game/assets/art/objects/kenney/*.png` | `Chest`, `LockedDoor`, `PressurePlate`, `PushableBlock`, `Lever`, `SaveCrystal` scripts |
| Hero/Buddy/slimes | `game/data/sprites/kenney_*.tres` | `CharacterStats` / `EnemyStats` `sprite_frames` slots |
| NPCs | `game/assets/art/sprites/runtime/kenney/healer.png` and `quest_npc.png` | LDtk `Npc` fields and `NPC` behavior |
| Combat/UI | `game/assets/art/ui/kenney/*.png` | combat FSM, range sets, turn order, and command input |

T-086 owner exception: `door_closed.png` and `pushable_block.png` remain in the
reference library but are intentionally unwired after the 2026-07-11
playthrough rejected their half-door/fence silhouettes. `LockedDoor` and
`PushableBlock` use the accepted full-cell door and two-tone slab renderings.
| Input prompts | `game/assets/art/ui/prompts/kenney/*.png` | InputMap actions and `InputPrompts` active-device selection |

Coverage note: every colored actor/interactable stand-in in the playable
slice is replaced. The main/combat full-screen background `ColorRect`s and
text labels are deliberately retained as layout/color surfaces rather than
asset placeholders; prototype/generated character sheets remain checked in
but are no longer the default resources.

## Global Art Constraints

- Retro pixel-art-inspired, not hardware-accurate.
- Bright, readable, GBA-era fantasy-adventure feel.
- Top-down / slight 3/4 overhead camera.
- 16x16 art pixels rendered at 4x as the current runtime cell size.
- Nearest filtering; avoid anti-aliased edges.
- Unrestricted palette, but keep silhouettes clear.
- No 3D or photorealistic assets.
- Asset prompts must avoid naming living artists or copyrighted game assets as
  direct style targets. Use project-owned language from `BLUEPRINT.md` instead.

## Phase Timing

| Phase | Asset policy |
|---|---|
| Phase 1 | Test art and export pipeline only. Already has generated placeholder tiles and hero sprite. |
| Phase 2 | Placeholder art is acceptable; mechanics and room readability come first. |
| Post-Phase-2 art pass | First real overworld/dungeon art batch. This is the next meaningful visual-production window after Kayden accepts the reworked tutorial dungeon. |
| Phase 3 | Only make assets that unblock data/save work: item icons, save crystal, placeholder portraits/sprite slots, and UI affordances needed for save/load clarity. |
| Phase 4 | Combat sprites, battle UI, action/effect animation, targeting/readability assets. |
| Phase 5 | Party member portraits/sprites, recruitment presentation, party menu assets, ability icons. |
| Phase 6 | First-playable polish: final forest-dungeon art, boss presentation, transition polish, music, and SFX. |
| Post-MVP | Castle city, mountain, river, extra dungeon, traversal, equipment, magic, and optional cosmetic assets. |

## Asset Batches

### Batch A - Forest Overworld Art

**Phase:** Post-Phase-2 art pass.
**Taskboard:** T-051.
**Started:** 2026-07-08 with a reproducible first-pass sheet at
`game/assets/art/tilesets/forest_overworld_tiles.png`, generated by
`game/assets/art/_scripts/generate_forest_overworld_tiles.py`.

Required:

- Grass base tile.
- Path tile and path edges/corners.
- Tree-on-grass tile readable as collision.
- Shrub/bush tile.
- Rock or stump obstacle tile.
- Dungeon entrance / cave mouth.
- Campfire / healer camp object.
- Sign or small interactable marker.
- Optional flowers, dirt variation, shadow accents.

Current first-pass sheet order:

| Index | Asset |
|---:|---|
| 0 | Grass base |
| 1 | Path center |
| 2 | Path north edge |
| 3 | Path northeast corner |
| 4 | Tree-on-grass collision tile |
| 5 | Shrub/bush |
| 6 | Rock obstacle |
| 7 | Stump obstacle |
| 8 | Dungeon entrance / cave mouth |
| 9 | Campfire |
| 10 | Sign |
| 11 | Flowers |
| 12 | Dirt variation |
| 13 | Shadow patch |
| 14 | Reserved grass duplicate |
| 15 | Reserved grass duplicate |

Acceptance:

- Every blocking Wall cell in the current forest reads as a visible obstacle.
- The path to the dungeon entrance is readable without making the map a maze.
- Tiles align cleanly at 16x16 with nearest filtering.
- T-020 display-scaling check still reads clearly at 1280x720, 1920x1080,
  and 3440x1440.

Remaining:

- Wire the accepted forest sheet into the LDtk tileset/map after Kayden's
  T-032 round-2 windowed acceptance, then run the screenshot tour and T-020
  display-scaling check against the real sheet.

### Batch B - Tutorial Dungeon Tiles And Objects

**Phase:** Post-Phase-2 art pass.
**Taskboard:** T-052.
**Started:** 2026-07-08 with a reproducible first-pass sheet at
`game/assets/art/tilesets/tutorial_dungeon_tiles.png`, generated by
`game/assets/art/_scripts/generate_tutorial_dungeon_tiles.py`.

Required:

- Dungeon floor tile.
- Dungeon wall tile.
- Fixed stone brick tile.
- Loose/movable brick variant that still looks related to fixed bricks.
- Pit tile.
- Jumpable ledge edge.
- Filled-pit/bridge tile.
- Locked door and unlocked/open door states.
- Chest open/closed states.
- Lever idle/used states.

Current first-pass sheet order:

| Index | Asset |
|---:|---|
| 0 | Dungeon floor |
| 1 | Dungeon wall |
| 2 | Fixed stone brick |
| 3 | Loose/movable brick variant |
| 4 | Pit |
| 5 | Jumpable ledge edge |
| 6 | Filled-pit bridge |
| 7 | Locked door |
| 8 | Open door |
| 9 | Chest closed |
| 10 | Chest open |
| 11 | Lever idle |
| 12 | Lever used |
| 13 | Cracked floor variation |
| 14 | Wall shadow variation |
| 15 | Reserved floor duplicate |

Acceptance:

- The one movable brick is discoverable through play without making the fixed
  bricks look like different objects at first glance.
- Pits, ledges, and filled pits are visually distinct.
- Locked-door state is clear before interaction.
- The existing screenshot tour shows readable forest, hub, pit, fight, and
  chest rooms with no invisible collision reads.

Remaining:

- Import the sheet through Godot, wire accepted tiles into
  `tutorial_dungeon.ldtk`, then run the screenshot tour and smoke test.

### Batch C - Overworld Characters And Enemies

**Phase:** Post-Phase-2 art pass to early Phase 3.
**Taskboard:** T-053.

Required:

- Hero overworld idle and four-direction walk.
- Healer/old-man NPC idle.
- Quest NPC idle.
- Forest slime idle/move.
- Boss slime readable as stronger than a normal slime.
- Dungeon slime / key guardian.
- Slime aggro/angry state for T-028.

Acceptance:

- Hero facing direction reads at game scale.
- Slime normal/chase states are readable at a glance.
- Boss/key guardian variants are distinct without needing labels.
- SpriteFrames can be wired into the existing actor scenes without changing
  movement architecture.

### Batch D - Items, Save Objects, And Small UI Icons

**Phase:** Phase 3.
**Taskboard:** T-054.
**Started:** 2026-07-08 with a reproducible first-pass sheet at
`game/assets/art/icons/item_save_icons.png`, generated by
`game/assets/art/_scripts/generate_item_save_icons.py` and imported by Godot
4.7.

Required:

- Forest key icon.
- Dungeon key icon.
- Shield icon.
- Save crystal object sprite.
- Minimal inventory/HUD item icon presentation.
- Optional Continue/New Game prompt frame accents if needed.

Acceptance:

- Icons map cleanly to `ItemData` ids: `forest_key`, `dungeon_key`, `shield`.
- Save crystal is visually distinct from ordinary scenery.
- Save/load UI remains functional and readable without creating a full title
  screen early.

Current first-pass sheet order:

| Index | Asset |
|---:|---|
| 0 | Forest key icon |
| 1 | Dungeon key icon |
| 2 | Shield icon |
| 3 | Save crystal object sprite |
| 4 | Empty inventory slot |
| 5 | Selected inventory slot |
| 6 | Continue prompt badge |
| 7 | New Game prompt badge |

Remaining:

- Wire accepted icons into `ItemData`, save crystal, inventory/HUD, and
  boot-prompt UI when those Phase 3 systems land.

### Batch E - Combat MVP Assets

**Phase:** Phase 4.
**Taskboard:** T-055.

**Source intake (2026-07-10):** three generated concept sheets were added under
`game/assets/art/sprites/` (armored knight, wizard, and red ooze) and logged in
`docs/assets/IMAGE_PROMPTS.md`. They are source references only: each has a
baked checkerboard rather than transparency, irregular frame bounds, and
incomplete original prompt/model provenance. Do not wire them into runtime
SpriteFrames until those gaps are resolved and character roles are assigned.

**Runtime pass (2026-07-10):** the concepts now have role-assigned derivatives:
Hero = armored knight, temporary Buddy = wizard, and the current slime family =
red ooze. Each ships as a four-frame 128px idle strip with real alpha, shared
scale, and bottom-center anchoring under `game/assets/art/sprites/runtime/`.
`CharacterStats`/`EnemyStats` carry the SpriteFrames, so the same data-driven
art renders in overworld and tactical combat without changing grid movement.
The permanent showcase command is documented in `RUNBOOK.md`. Remaining Batch
E work is targeting/effect/menu polish and distinct slime variants; this pass
does not complete the full batch.

Required:

- Combat unit sprites for hero, slime, boss slime, dungeon slime.
- Tactical selection cursor.
- Move-range highlight.
- Attack-range highlight.
- Target indicator.
- Attack impact effect.
- Defend effect tied to the shield unlock.
- Damage popup style.
- Combat menu frame and buttons.
- HP bars and turn-order display.

Acceptance:

- Combat grid position, selected unit, valid move cells, and valid targets are
  readable before committing an action.
- Attack/Defend feedback is visible without over-animating the MVP.
- Combat UI works with keyboard/controller flow and remains legible at the
  target resolutions.

### Batch F - Party And Progression Assets

**Phase:** Phase 5.
**Taskboard:** T-056.

Required:

- First recruitable party member overworld portrait.
- First recruitable party member combat sprite.
- Hero portrait.
- Basic party menu portraits or busts.
- Ability icons for the Phase 5 starter ability set.
- Level-up / recruitment presentation accents.

Acceptance:

- The party menu can show active and reserve members clearly.
- Combat can distinguish party units by silhouette and portrait.
- Ability icons communicate their rough role without requiring long text.

### Batch G - Phase 6 First-Playable Polish

**Phase:** Phase 6.
**Taskboard:** T-057.

Required:

- Final pass on the forest dungeon tile set.
- Boss-specific sprite and combat presentation.
- Dungeon reward/key-item presentation.
- Transition/fade visual polish.
- Any missing interactable object states for the 3-5 room forest dungeon.
- One coherent visual pass across forest, dungeon, combat, and UI.

Acceptance:

- The first playable slice feels like one coherent place, not a mix of
  unrelated test assets.
- The boss encounter reads as the end of the slice.
- The final Phase 6 screenshot/recording can be understood without debug text.

### Batch H - Audio

**Phase:** Phase 6 M6.5 polish.
**Taskboard:** T-058.

Required:

- Forest loop.
- Dungeon loop.
- Combat loop.
- Boss or danger sting.
- Victory sting.
- Defeat sting.
- Menu confirm/cancel/move SFX.
- Footstep or grid-step SFX, if it improves feel.
- Push/block SFX.
- Jump/fall SFX.
- Chest open SFX.
- Door unlock/open SFX.
- Save crystal SFX.
- Attack/defend/hit SFX.

Acceptance:

- Furnace source/export workflow produces `.ogg` files under
  `game/assets/audio/music/` and `game/assets/audio/sfx/`.
- Audio is used through Godot `AudioStreamPlayer` or `AudioStreamPlayer2D`.
- No literal hardware-channel-emulation engine is introduced.

### Batch I - Post-MVP Region And Stretch Assets

**Phase:** Post-MVP world expansion and stretch goals.
**Taskboard:** S-006 plus future task rows.

Required later:

- Castle city tiles, NPCs, interiors, and props.
- Mountain tiles, cliffs, cave variants, enemies, and props.
- River/water tiles, swim/traversal states, water objects, enemies, and props.
- Equipment/weapon icons and sprites.
- Elemental/magic ability VFX and icons.
- Optional traversal ability object states.
- Optional cosmetic shader assets/settings UI.

Acceptance:

- Each region extends the established art pipeline and LDtk workflow instead
  of introducing new architecture.
- Stretch assets are only made when their matching stretch system is approved.

## Prompt Logging Rule

Every generated image asset must have a matching entry in
[`IMAGE_PROMPTS.md`](IMAGE_PROMPTS.md) before it is treated as usable project
source. If an image is regenerated, add a new prompt entry rather than
overwriting the old one.

Each prompt entry should include:

- Asset id.
- Task id.
- Intended file path.
- Prompt.
- Negative prompt or exclusions.
- Model/tool and settings if known.
- Source image references if any.
- Result file path.
- Acceptance notes.
