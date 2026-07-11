# Kenney-First Visual Skeleton Plan

**Status:** ready to implement  
**Decision date:** 2026-07-11  
**Owner:** Codex implementation, Kayden windowed acceptance

## Goal

Use the checked-in Kenney CC0 packs to give the entire playable slice a
coherent visual skeleton now. The skeleton should make rooms, actors,
interactables, combat, and prompts understandable without waiting for final
custom art. Custom assets remain replaceable later through the existing
runtime resource and LDtk boundaries.

This plan supersedes the custom-generated world-cohesion lane previously
listed as T-080..T-084. Do not delete the generated knight, wizard, ooze, or
prototype tiles; keep them as optional source/reference art while the Kenney
skeleton becomes the default runtime presentation.

## Asset Roles

| Project surface | Primary Kenney source | Runtime destination |
|---|---|---|
| Forest ground, paths, trees, entrances, pickups | Roguelike RPG Pack | `game/assets/art/tilesets/kenney/` and LDtk tilesets |
| Tutorial dungeon floor, walls, doors, pits, props | Roguelike Caves & Dungeons | `game/assets/art/tilesets/kenney/` and LDtk tilesets |
| Furniture and indoor set dressing | Roguelike Indoors | `game/assets/art/objects/kenney/` |
| Hero, Buddy, NPCs, slimes, bosses | Roguelike Characters | `game/assets/art/sprites/runtime/kenney/` |
| Combat frames, buttons, selection and turn markers | Pixel UI Pack | `game/assets/art/ui/kenney/` |
| Keyboard and controller glyphs | Input Prompts Pixel | `game/assets/art/ui/prompts/kenney/` |

The source library under `game/assets/kenney/` stays untouched. Selected art
is copied into the runtime destinations with a manifest entry recording its
pack, source sheet rectangle, runtime name, consumer, and any palette or scale
change.

## Non-Negotiable Integration Rules

- Preserve the current 16x16 art-pixel vocabulary, rendered at 4x for a 64px
  runtime cell, with nearest filtering and integer positioning.
- Preserve LDtk-authored geometry, entity ids, collision meaning, room flow,
  puzzle behavior, combat logic, and saved-game ids. This is a skin/framework
  pass, not a redesign.
- Use `TileMapLayer`, never deprecated `TileMap`.
- Crop from transparent sheets; do not depend on the magenta-background
  sheets or reference the evaluation-library paths directly at runtime.
- Prefer one coherent pack per surface. Mix packs only at explicit seams
  (characters over RPG terrain, UI over gameplay) and inspect the result at
  1x game scale.
- Keep art references behind TileSet, SpriteFrames, Texture2D, StyleBox, and
  data-resource slots so a later custom asset can replace a Kenney asset
  without changing mechanics.
- Do not remove licenses. Add a courtesy Kenney credit before a public build.

## Implementation Sequence

### 1. Promotion manifest and visual contract - T-080

Create a machine-readable manifest and a contact-sheet scene covering the
selected tiles, characters, objects, UI, and prompt glyphs. Lock the base
palette, 16x16 source cell, 4x display scale, naming, and exact atlas regions
before production scenes change. Include a mapping for every currently visible
placeholder so the pass cannot stop after only the attractive pieces.

**Exit proof:** manifest validates; no duplicate runtime names; source regions
are in bounds; contact sheet is visually inspected at 1280x720.

### 2. Playable world skeleton - T-081

Promote the forest and cave/dungeon tiles first, then update the LDtk tilesets
without changing any collision or entity layers. Replace grass-only/red-square
stand-ins with readable ground, path, trees/walls, entrances, doors, plate,
block, chest, save crystal, keys, and reset lever. Reimport all LDtk projects.

This is the first visible milestone: after T-081, Kayden should be able to walk
the full forest-to-dungeon loop and understand what is floor, obstacle,
entrance, pickup, and interactable even if actors and UI are still transitional.

**Exit proof:** LDtk schema/import checks pass; existing room-flow and puzzle
tests stay green; screenshot tour covers forest, hub, chest, plate room, and
fight room; Kayden can review the tour in under one minute.

### 3. Actor skeleton - T-082

Promote distinct Kenney character sprites for Hero, temporary Buddy, healer,
quest NPC, regular slime, dungeon slime, and boss. Wire them through the
existing SpriteFrames and CharacterStats/EnemyStats texture slots. Use the
pack's modular character construction only in a deterministic preparation
step; commit the resulting runtime sheets so the build does not assemble art
differently between machines.

The skeleton needs distinct silhouettes and team/enemy readability; it does
not need final portraits or elaborate attack animation. Preserve current
generated sprites as unwired alternatives for later comparison.

**Exit proof:** overworld and combat showcase scenes render every role; no
colored actor blocks remain in the playable slice; unit/resource tests and
slice smoke remain green; windowed scale and facing are checked.

### 4. Combat, menus, and prompts - T-083

Apply the Pixel UI Pack to the boot prompt, dialogue, combat command surface,
HP/MP and turn-order framing, target cursor, move/attack highlights, and basic
buttons. Apply Input Prompts Pixel as an input-mode-aware glyph layer for the
locked keyboard/controller pairs tracked by T-079. Keep combat state and input
bindings unchanged.

**Exit proof:** keyboard and controller glyph modes each show one unambiguous
prompt; combat commands, selected cells, legal ranges, turn order, damage, and
item confirmation remain readable at 1280x720 and ultrawide; UI/input tests and
smoke pass.

### 5. Cohesion QA and swap-ready handoff - T-084

Run a complete windowed tour and correct only presentation defects: wrong
scale, filtering, draw order, anchor, palette clash, hidden collision, unclear
state pairs, or unreadable UI. Produce forest, dungeon, and combat comparison
screenshots plus a coverage report showing that every visible placeholder has
either been replaced or deliberately retained with a reason.

Document the later custom-art swap points by resource/tileset path. Do not
start a second art style during this task.

**Exit proof:** Godot import, relevant units, full slice smoke, main boot, and
the three visual tours pass; Kayden accepts the skeleton or records specific
follow-up tasks.

## Delivery Order

T-080 -> **T-081 visible world milestone** -> T-082 -> T-083 -> T-084.

T-081 is deliberately ahead of character polish because a readable world
eliminates the red-square/blank-map stall fastest. The lane may proceed beside
the authored-arena work, but each implementation task should use a short-lived
branch from the latest `integration` and land through `integration` before the
next task begins.

## Deferred Until After The Skeleton

- Custom directional animation beyond what is needed for readable movement.
- Bespoke portraits, attack/VFX strips, and final boss presentation.
- Palette overhauls that require repainting whole packs.
- New rooms, mechanics, puzzles, enemies, abilities, or UI flows.
- Deleting prototype/generated art before a replacement is accepted.
