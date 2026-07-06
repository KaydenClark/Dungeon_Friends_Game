# Dungeon Friends - Blueprint

> Generated from LLM Workbench v2.1. See `RUNBOOK.md` -> Upgrading The
> Harness.

**Last reviewed:** 2026-07-05
**Status:** partial
**Source root:** `/Users/kayden/GPT_OS/Projects/Dungeon_Friends_Game`

This is the stable reference for what the project is. Full architecture and
milestone-level rationale lives in [`docs/planning/Gameplan.md`](docs/planning/Gameplan.md)
(545 lines - read it for the "why" behind anything below); the toolchain
research behind that plan is in [`docs/research/audited_research.md`](docs/research/audited_research.md).
This file is the dense summary a future agent should read first.

## What This Project Is

A 2D top-down adventure RPG in the structural tradition of classic Zelda games
(grid-based overworld and dungeons, block-pushing puzzles, switches, locked
doors, key items that unlock new areas) layered with turn-based party combat
inspired by Baldur's Gate and Fire Emblem. The player explores a hand-authored
world - beginning in a fantasy forest with a Kokiri-Forest-from-Ocarina-of-Time
mood, later opening into a castle city, mountains, and rivers - while
recruiting party members ("Dungeon Friends") who fight alongside them.
Visually it's retro-pixel-art *inspired*, not any specific handheld-accurate:
a flexible HD/ultrawide base resolution (1280x720 design reference, scaling
cleanly up through 1920x1080 and 3440x1440), nearest-neighbor filtering,
unrestricted palette - retro sprite silhouette (chunky pixel art, grid
movement, tile-based dungeons), not a hardware recreation and not locked to
any one fixed low-res canvas. See Visual Language below for the specific
GBA-fantasy-adventure look (bright/readable, toy-like overworlds, chunky
silhouettes, 8x8/16x16 tile logic) this project targets. The combat/ability
system borrows the shape of Dungeons & Dragons (classes, abilities, a small
stat block) without being a literal D&D implementation - adapt what serves a
small, well-balanced turn-based system, skip the rest. Combat resolution uses
a d10 percentage system (see Core Logic And Invariants), not literal D&D dice.

Core promise:

> Walk a hand-built overworld, get pulled into a readable turn-based fight
> without a jarring scene change (the camera zooms into where you were
> standing, early-Final-Fantasy style, so the world reads as bigger than its
> actual grid), solve a block/switch/key puzzle, and grow a small recruited
> party across a forest, a castle city, and a mountain/river region.

Primary users:

- Kayden - solo player and primary tester.
- Friends/family Kayden shares built exports with (macOS/Windows/Android).
- A future AI agent (Claude, Codex, or other) picking this repo up cold.

## Visual Language

Confirmed 2026-07-05 (Kayden's reference table, GBA-era fantasy-adventure
games as the touchstone - e.g. the Golden Sun/Fire Emblem/Pokemon generation's
art direction, not any one licensed title): bright, readable, tile-based, toy-
like overworlds with chunky silhouettes, dense environmental texture, and a
clean top-down camera. This narrows, but does not contradict, the flexible-
HD/ultrawide rendering decision in Architecture below - the *canvas* renders
natively at 1280x720+, but the *art* is built from small GBA-style tile units.

| Category | What it means for Dungeon Friends |
|---|---|
| Camera | Top-down / slight 3/4 overhead - the player reads space like a board, not a painting |
| World scale | Compressed, symbolic maps - towns, forests, rivers, mountains simplified into clear, readable chunks |
| Tiles | Strong grid logic, built from reusable 8x8 or 16x16 tile pieces (narrows the "TBD at M1.1" tile-grid-unit question in Architecture below to this range - exact pixel size is still an M1.1 art decision) |
| Palette | Bright greens, tans, blues, soft shadows - friendly adventure tone even where danger exists |
| Texture | Repeating grass/path/roof/water/tree patterns - visually active but still readable |
| Sprites | Small characters, oversized heads, clear outlines - identity from silhouette and color, not fine detail |
| Objects | Chests, signs, doors, fences, shrubs are iconic and instantly recognizable |
| Layout | Paths visually guide movement - the player should know where they can walk at a glance |
| Tone | Cozy but adventurous - safe towns, mysterious forests, tactical danger outside |
| Combat readability | Grid-friendly spacing, strong contrast - even action scenes stay clean and legible |

This directly informs M1.1 (art) and the LDtk tile vocabulary; no architecture
impact beyond what Architecture below already decides.

## Non-Goals

This project is not trying to:

- Be a literal Dungeons & Dragons implementation or licensed product - no
  SRD/OGL content. Combat resolution is a d10 percentage system (see Core
  Logic And Invariants), not D&D's d20/dice-pool mechanics. Inspiration, not
  rules-as-written.
- Support multiplayer or any online/networked play.
- Be a commercial or monetized product unless Kayden explicitly decides
  otherwise.
- Use 3D or photorealistic visuals - committed to a retro pixel-art aesthetic,
  rendered flexibly across HD/ultrawide displays rather than locked to one
  fixed low resolution.
- Use random or invisible encounters - enemies are always visible on the map.
- Hardware-accurately emulate any specific handheld console - no forced
  palette limit, no fixed low-res canvas, no literal 4-channel hardware audio
  engine (see Design Decisions).

## Current Product Shape

**Moment-to-moment loop (confirmed 2026-07-05):** explore -> interact with an
object/NPC/enemy -> take an action -> see the consequence of that action ->
continue exploring. Everything below is this same loop playing out at a
different scale - a single NPC conversation, a single puzzle switch, or a full
combat encounter.

Target shape once Phase 0-6 (the Gameplan's MVP, see Gameplan.md section 16)
is complete - **not yet built**; see `TASKBOARD.md` for what actually exists
today. When the project is working, a user can:

- Walk a grid-based overworld and dungeon with precise, snapped movement.
- Solve pushable-block / pressure-plate / locked-door puzzles gated by key
  items.
- See enemies on the map, touch one, and enter a grid-based turn-based fight:
  each combatant checks its move/attack range, moves, then acts on its own
  turn in strict initiative (speed) order - never a whole-team phase -
  resolved with a d10 percentage roll (3-character active party,
  Attack/Ability/Item/Defend), with a camera-zoom transition into the
  encounter and back.
- Recruit at least one additional party member and swap the active three.
- Save at physical save points (3 slots) and reload with puzzle/enemy state
  intact.
- Play through one complete forest dungeon (Kokiri-Forest-vibe) start to
  finish, including a boss, as the first vertical slice.

**Updated first-playable target (2026-07-05, Kayden's phrasing):** the
smallest concrete scenario every Phase 1-4 milestone should be building
toward, and a good smoke test once combat exists:

> A high-resolution forest test area where the player walks with
> grid-snapped movement, talks to one NPC, touches a visible enemy,
> transitions into a simple turn-based battle, wins, returns to the same
> forest position, gets a key/reward, and opens a blocked path.

This is a smaller, more testable slice than the full Phase 6 finish line
above (no full dungeon, no boss, no save/load, no party-of-three depth
required) - treat it as the walking skeleton the fuller Phase 6 slice builds
on top of, not a replacement for it.

**Status (2026-07-05, second session): this walking skeleton now exists and
is playable from `main.tscn`** - placeholder ColorRect art, a code-built room
(`game/scripts/dev/forest_slice.gd`), one NPC, one slime, a minimal d10 grid
battle, a key drop, and a locked door with goal tiles behind it. Verified by
a 26/26-check headless smoke test (`game/scenes/dev/slice_smoke_test.tscn`);
Kayden's windowed play-check is still owed. Real art (T-003) and LDtk
authoring (T-004/T-011) replace the placeholders without changing the
entity/RoomGrid logic.

The most important quality bar is:

- Movement and puzzle feel (precise, grid-snapped, no floaty physics) over
  feature breadth - see Gameplan.md section 1 Design Pillars, which this
  Blueprint treats as still authoritative and unchanged by the direction
  notes below.

## Direction And Build Order

Current phase:

- Phase 1-2 walking skeleton built (2026-07-05 second session, see
  `TASKBOARD.md` T-016): grid movement, interaction/dialogue, enemy contact,
  minimal d10 combat with transition, key/door reward loop - all on
  placeholder art. Phase 0's M0.3 (export presets) is still open, as are the
  content-pipeline tasks (T-003 Aseprite art, T-004 LDtk importer, T-011 real
  forest map) that turn the skeleton into the real Phase 1.

Build order (phases per Gameplan.md section 15; each is a real milestone with
a stated "done" condition there):

1. **Phase 0 - Foundation** - harness + a scaffold that actually runs. Nothing
   else can start on a trustworthy base without this.
2. **Phase 1 - Movement & World Skeleton** - grid movement, first LDtk room.
   Proves the core Zelda-style movement feel before investing in systems on
   top of it.
3. **Phase 2 - Puzzle Primitives & Room Transitions** - the world-building
   toolkit (pushable blocks, plates, locked doors, camera-panned transitions)
   every dungeon after this depends on.
4. **Phase 3 - Data Model & Save/Load** - the Resource-based data pipeline
   (`CharacterStats`, `EnemyStats`, etc.) combat and party both build on.
5. **Phase 4 - Combat MVP** - the turn-based Baldur's Gate/Fire-Emblem-inspired
   core loop: `TurnManager`, two-layer FSM, Attack/Ability/Item/Defend.
6. **Phase 5 - Party System & Progression** - recruitment, XP/leveling,
   multi-character active party with snake-follow formation.
7. **Phase 6 - First Playable Slice** - one full forest dungeon (3-5 rooms,
   puzzles, encounters, boss) proving the whole loop end to end. This is the
   MVP finish line (Gameplan.md section 16).
8. **World expansion (post-MVP, content work, no new architecture)** - castle
   city, then mountains, then rivers, each authored as new `world.ldtk`
   regions using the systems already built for the forest.
9. **Stretch goals (sequenced)** - see `TASKBOARD.md` Deferred lane: equipment/
   weapon variety and elemental/magic system are the two highest-priority
   stretch items given the emphasis on magic and weapon variety in this
   project's founding vision, followed by telegraphed combat UI, traversal
   abilities, resource-gauge mechanics, more dungeons/full overworld map,
   cosmetic shader, roguelike postgame.

## Architecture

| Layer | Choice | Source / Notes |
|---|---|---|
| Engine/Runtime | Godot 4.6.x, GDScript | Installed and confirmed: `4.6.3.stable.official` |
| Renderer | Mobile | Locked, Gameplan.md section 3.2 |
| UI | Godot `Control` nodes + `CanvasLayer` (HUD, dialogue, menus) | `game/scenes/ui/` |
| Backend | None - fully local, no server, no accounts | |
| Storage | `Resource` (`.tres`) files for game data; `SaveData` to `user://saves/` | `game/data/`, section 12 of Gameplan.md |
| Levels | LDtk, single `world.ldtk`, imported via `heygleeson/godot-ldtk-importer` | Not yet installed - Milestone M1.2 |
| Art | Aseprite (primary, Lua/CLI-scriptable), Pixelorama (fallback) | 1280x720 design-reference base, flexible HD/ultrawide scaling (see Design Decisions); tile grid unit TBD when M1.1 art lands - the T-007 display spike uses 64px placeholder tiles as a reasonable ratio for this base |
| Audio | Furnace Tracker -> `.ogg` -> `AudioStreamPlayer`/`AudioStreamPlayer2D` | No hardware-channel-emulation engine (dropped, not deferred) |
| Testing | Headless Godot CLI checks (`--import`, `--quit-after`) | No GDScript test framework yet - see `RUNBOOK.md` |
| Deployment/Export | Godot editor Export dialog: macOS, Windows, Android | Gameplan.md section 14 |

Architecture constraints:

- Single Autoload: `SceneManager`. No other autoloads - additional global
  state goes on `SceneManager`'s `GameState`/`SaveData` resource.
- Grid-snapped movement only, via `Tween`; never raw `velocity`-based free
  movement.
- All stats/items/abilities/encounters are `Resource` subclasses defined in
  `scripts/data/`; never hardcode balance numbers in scene scripts.

## Directory Map

```text
Dungeon_Friends_Game/
├── game/                          <- Godot project root (game/project.godot)
│   ├── addons/                    <- third-party plugins (LDtk importer, once installed in M1.2)
│   ├── assets/art/                <- Aseprite sources, exported sheets, _scripts/ batch tools
│   ├── assets/audio/               <- Furnace .ogg exports (music/, sfx/)
│   ├── assets/levels/               <- world.ldtk (once authored)
│   ├── data/                        <- .tres Resource instances (characters/, enemies/, items/, abilities/, encounters/)
│   ├── scenes/                      <- .tscn files (overworld/, dungeons/, combat/, entities/, ui/, dev/ for throwaway spikes)
│   ├── scripts/                     <- .gd files (autoload/, data/, combat/, overworld/, puzzles/, save/, dev/ for throwaway spikes)
│   └── shaders/
├── docs/
│   ├── planning/Gameplan.md        <- full architecture/design rationale
│   ├── research/audited_research.md <- toolchain research audit
│   └── LEGACY_HARNESS.md            <- archived pre-v2 AGENTS.md/CLAUDE.md
├── AGENTS.md                        <- agent behavior and read/edit scope
├── BLUEPRINT.md                     <- this file
├── TASKBOARD.md                     <- live task queue, blockers, proof log
└── RUNBOOK.md                       <- setup, operation, verification, recovery
```

## Main Contracts

### Scenes

| Scene | Purpose | Status | Source |
|---|---|---|---|
| `game/scenes/main.tscn` | Root: `SceneManager` wiring, `WorldContainer`/`CombatContainer`/`UILayer`/`TransitionLayer` | working - `scripts/main.gd` registers the containers with `SceneManager` and boots the forest slice into `WorldContainer` | `game/scenes/main.tscn`, `game/scripts/main.gd` |
| Overworld / Dungeon (LDtk-instanced) | Grid movement, puzzles, visible enemies | walking skeleton: `RoomGrid` runtime grid model + code-built placeholder room (`ForestSlice`); LDtk authoring still missing (T-004/T-011) | `game/scripts/overworld/`, `game/scripts/dev/forest_slice.gd` |
| Combat | Turn-based party-vs-enemy encounter | MVP walking skeleton (2026-07-05): per-unit initiative, AStarGrid2D arena movement, melee-adjacent d10 attacks, Pokemon-style two-tier command menu (Fight/Defend -> move list) with step-in/swing/step-back per turn, fade transition; built in code (`CombatScene`), no .tscn yet; formulas are placeholders pending Phase 3/4 | `game/scripts/combat/combat.gd` |
| UI (HUD, dialogue, pause, party menu) | Player-facing menus and status | dialogue box exists (`DialogueBox`, code-built); HUD/pause/party menus missing | `game/scripts/ui/dialogue_box.gd` |
| `game/scenes/dev/display_scaling_spike.tscn` | Throwaway diagnostic - proves the new flexible HD/ultrawide stretch settings render an undistorted tile grid at 1280x720/1920x1080/3440x1440 | working (placeholder ColorRect tiles, no real art yet) | `game/scenes/dev/display_scaling_spike.tscn`, `game/scripts/dev/display_scaling_spike.gd` |

### Commands

Godot Input Map actions (single source of truth for all gameplay input across
keyboard, controller, and mobile touch - see Gameplan.md section 11):

| Command | Purpose | Required for done? |
|---|---|---|
| `move_up` / `move_down` / `move_left` / `move_right` | Grid movement | yes |
| `interact` / `confirm` | Interact with objects/NPCs; confirm menu selection | yes |
| `cancel` / `back` | Cancel or back out of a menu | yes |
| `menu` | Open pause/party menu | yes |

### Data Model

| Entity | Key fields | Stored where | Notes |
|---|---|---|---|
| `CharacterStats` | `id, display_name, max_hp, max_mp, attack, defense, speed, sprite_frames, starting_abilities` | `game/data/characters/*.tres` | Party member stat block |
| `EnemyStats` | `id, display_name, max_hp, attack, defense, speed, abilities, ai_behavior, xp_reward, loot_table` | `game/data/enemies/*.tres` | `ai_behavior`: `RANDOM_WALK` / `BIASED_TRACKING` / `PATTERN` |
| `ItemData` | `id, display_name, item_type, stat_modifiers, on_use_ability` | `game/data/items/*.tres` | `item_type`: `KEY_ITEM` / `CONSUMABLE` / `EQUIPMENT` |
| `AbilityData` | `id, display_name, mp_cost, target_type, element, power, overworld_use` | `game/data/abilities/*.tres` | `element`/equipment-adjacent fields exist for Stretch Goals 1-2, unused at MVP |
| `MapMeta` | `ldtk_level_id, display_name, music_track, encounter_table` | one companion `.tres` per level | LDtk is the source of truth for layout; this covers non-visual metadata |
| `EncounterData` | `id, enemy_group, background_id` | `game/data/encounters/*.tres` | Referenced directly by overworld enemy instances - no random rolls |
| `SaveData` | `current_map, player_position, party_roster, party_levels/xp/hp/mp, inventory, flags, defeated_enemy_ids` | `user://saves/slot_N` (`.tres` or `.json`) | Never saved mid-combat; 3 slots from the start |

*Note (2026-07-05):* grid-based combat means `CharacterStats`/`EnemyStats`/
`AbilityData` will need move-range and attack-range fields once Phase 4
implements it - not yet added to the table above; exact field names/shape are
a Phase 3/4 implementation decision, not decided here.

*Status (2026-07-05, second session):* `CharacterStats` and `EnemyStats` now
exist (`game/scripts/data/`) with the fields listed above, plus first
instances `game/data/characters/hero.tres` and
`game/data/enemies/forest_slime.tres`. `ItemData`/`AbilityData`/`MapMeta`/
`EncounterData`/`SaveData` are still Phase 3 work. `EnemyStats.loot_table` is
a `PackedStringArray` of item ids for now - it becomes richer when `ItemData`
lands.

## Core Logic And Invariants

The combat/movement/data rules below are locked technical decisions (resolved
2026-06-11 per the research audit; the Combat rule below was extended
2026-07-05 with grid/range/d10 specifics directly from Kayden) - do not
relitigate without flagging to Kayden first; see `AGENTS.md` -> When To Ask,
Proceed, Or Stop.

Rules:

- **Grid movement**: compute the target cell, raycast/tile-check it, then
  `Tween`-interpolate over ~0.12-0.2s. Entities always rest exactly on grid.
  Never velocity-based `CharacterBody2D` free movement.
- **Pathfinding**: `AStarGrid2D`, `diagonal_mode = DIAGONAL_MODE_NEVER`,
  Manhattan heuristic.
- **Combat**: grid-based, turn-based, resolved with a **d10 percentage
  system** - roll 1-10 against a stat-derived success threshold, so success
  chances map directly to clean percentages (e.g. a threshold of 7 reads as a
  70% chance). Exact threshold/damage formula is TBD at the Phase 3/4
  combat-math implementation (red/green/refactor per `AGENTS.md` ->
  Verification And Proof), not decided here. Two-layer FSM - Battle FSM
  (`Initialize -> CalculateInitiative -> UnitTurn (loop) -> EncounterEnd`) and
  per-Entity FSM (`AwaitingTurn -> CheckRange (move + attack range) -> Moving
  -> SelectingAction -> ExecutingCommand -> TakingDamage/Healing -> back or
  Dead`) - plus a `TurnManager` that sorts *all* combatants (party and enemy
  together) by individual `speed`/initiative each round and steps through them
  one at a time. Turn order is strict per-character initiative, never a
  whole-team "all players, then all enemies" phase - this retires the old
  `PlayerPhase -> EnemyPhase` Battle-FSM state names, which had drifted out of
  sync with the `TurnManager`'s always-interleaved-by-speed behavior.
- **Enemies** are visible on the overworld map, move only when the player
  moves (synchronized turns), and trigger combat on contact. No random or
  invisible encounters.
- **Combat transition**: touching an enemy pauses the overworld, instances
  Combat with party/enemy refs plus the return position, and on victory/defeat
  frees Combat and restores the overworld at the exact pre-combat position.
  This transition should read as a camera zoom into the contact point
  (early-Final-Fantasy style) rather than a hard cut - an animation/UI
  refinement layered on this same SceneManager context-passing pattern, not a
  rearchitecture.
- **Data**: all stats/items/abilities/encounters are `Resource` (`.tres`)
  subclasses defined in `scripts/data/`. Never hardcode balance numbers in
  scene scripts.
- **Architecture**: single Autoload (`SceneManager`). No other autoloads -
  additional global state goes on `SceneManager`'s `GameState`/`SaveData`
  resource, not a new singleton.
- **Levels**: one LDtk project (`world.ldtk`). IntGrid layers for
  `Wall`/`Water`-`Pit`/`PuzzleTrigger`; entity layers for spawns, NPCs,
  enemies, pushable blocks, locked doors, room-transition triggers. Use
  `TileMapLayer`, never the deprecated `TileMap` node.
- **Puzzle primitives**: `PushableBlock`, `PressurePlate`, `Switch`/`Lever`,
  `LockedDoor` - LDtk entity custom fields carry linking IDs; a per-room
  `PuzzleController` wires signals at `_ready()` (MVP choice - simpler to
  debug than fully-automatic wiring).
- **Save**: save points are physical map objects; `SaveData` serializes to
  `user://saves/slot_N`; never saved mid-combat; 3 slots supported from the
  start.

Do not duplicate this logic in:

- Scene-local scripts that hardcode stats or damage numbers that belong in a
  `Resource` file under `game/data/`.

## Trust, Privacy, And Safety Boundaries

Sensitive data:

- Android release keystores (`.jks`/`.keystore`) and any export signing
  passwords.

Rules:

- Never commit keystore files. Never paste signing passwords into
  `export_presets.cfg` - enter them per-export in the Godot editor instead.
- No other secrets or private data exist in this project (no backend, no user
  accounts, no telemetry, no API keys).

## Known Risks

| Risk | Impact | Mitigation / owner |
|---|---|---|
| Scope creep from an oversized feature wishlist | High | The MVP/Stretch split (Non-Goals above, Gameplan.md section 16/17) is the guardrail - revisit it before adding any new system mid-phase |
| Solo + AI-assisted dev underestimates UI work (menus, inventory, party management) | Medium | UI-heavy phases (4, 5) get dedicated milestones rather than being bundled into "just add combat" |
| Android export friction (SDK/JDK setup, device-specific quirks) | Medium | Addressed in Phase 0 (M0.3), not deferred to the end |
| `heygleeson/godot-ldtk-importer` is a community plugin - could break on Godot updates | Low-Medium | Pin Godot to 4.6.x and the importer version; check its GitHub issues before any engine upgrade |
| Ultrawide (21:9) aspect ratios could show too much/too little world at the screen edges under `expand` | Low-Medium | Validated by the T-007 display-scaling spike at 1280x720/1920x1080/3440x1440 before producing more art; revisit `keep`+letterbox if `expand` reads poorly once real level art exists |
| "Authentic hardware constraint" scope creep (chasing GB/GBA-accuracy that doesn't serve gameplay) | Low | Any remaining hardware-accuracy ideas (e.g. a CRT shader) stay optional, cosmetic Stretch Goals, never load-bearing |
| Aseprite CLI/Lua automation has a learning curve before it pays off | Low | Start with simple batch-export scripts in M1.1; Pixelorama remains a no-cost manual fallback |
| **No narrative/story/world-lore design exists yet** - the Gameplan is systems-and-architecture-first, but "go through a story" is part of the founding vision | Medium | Needs deliberate attention before Phase 6 (First Playable Slice) means anything narratively - a vertical slice needs at least one real story beat, not just working systems. Not yet scheduled; flagged here rather than invented unprompted |
| Grid-based combat with per-unit movement/range is more implementation work than flat menu-only JRPG battles (positioning, move-range calc, attack-range validation, arena layout) | Medium | Reuse the overworld's existing `AStarGrid2D`/grid-movement patterns for combat positioning instead of inventing a parallel system; keep Phase 4 MVP range rules simple (e.g. melee = adjacent tile, ranged = fixed tile distance) and defer tactics depth (flanking, terrain bonuses) to Stretch Goals |

## Design Decisions

| Decision | Rationale | Date / Source |
|---|---|---|
| Godot 4.6.x, GDScript, Mobile renderer | Confirmed installed and matches the audited toolchain recommendation | 2026-06-11 / Gameplan.md section 3.2 |
~~240x160 base resolution (GBA-like, 3:2), nearest filter, integer scaling, `keep` aspect, unrestricted palette~~ - **superseded 2026-07-05, see the flexible HD/ultrawide row below** | GBA-*inspired* not GBC-accurate; more screen real estate than 160x144 while staying grid-friendly (240 = 15x16px, 160 = 10x16px) | 2026-06-11 / Gameplan.md section 3.2 |
| Flexible HD/ultrawide base resolution (1280x720 design reference), nearest filter, `canvas_items` stretch mode, `expand` aspect, `fractional` scale mode, unrestricted palette | Kayden decided to drop the fixed low-res GBA-locked canvas in favor of native HD/ultrawide rendering while keeping the retro sprite-art look (nearest-neighbor filtering, chunky pixel silhouettes); `canvas_items`+`expand` shows more world on wider displays (e.g. 3440x1440) instead of pillarboxing, validated by the T-007 display-scaling spike at 1280x720/1920x1080/3440x1440 | 2026-07-05 / this session, supersedes the 2026-06-11 row above |
| No global palette-swap shader / `SCREEN_TEXTURE` post-process in MVP | Was the source of a Compatibility-renderer bug risk; no longer needed once the palette isn't artificially constrained | 2026-06-11 / audited_research.md section 4.1, section 8 decision #2 |
| Single Autoload (`SceneManager`); all other state on `Resource` objects | Keeps global state from becoming a junk drawer; save/load becomes trivial since `GameState` is itself a `Resource` | Gameplan.md section 3.1 |
| Enemies visible on map, synchronized-turn movement, no random encounters | Matches the audit's Lufia-II-confirmed pattern; simpler to implement and matches the intended feel | Gameplan.md section 8 |
| Aseprite primary art tool (Lua/CLI-scriptable), Pixelorama fallback | Scriptable batch export lets an agent drive the art pipeline without manual GUI steps | 2026-06-11 / audited_research.md section 8.1 |
| Furnace Tracker for audio *sound*, not a literal hardware-channel-emulation engine | Authenticity of sound, not of engine architecture - the hardware-emulation idea was dropped entirely, not deferred | 2026-06-11 / audited_research.md section 8 decision #4 |
| `game/` subfolder holds the entire Godot project; docs/config live at repo root | Keeps `.godot/` cache and Godot-specific concerns cleanly separated from `docs/`/agent config | Gameplan.md section 4 |
| Combat framed as a camera zoom into the encounter point, not a hard scene cut | Founding vision calls for an early-Final-Fantasy-style transition so the overworld reads as bigger than its grid; layers onto the existing SceneManager context-passing pattern rather than replacing it | 2026-07-05 / this session's founding prompt |
| World authored in this order: forest (Kokiri-Forest mood) -> castle city -> mountains -> rivers | Founding vision's explicit world-progression arc; ties a creative goal to the concrete post-MVP content milestones | 2026-07-05 / this session's founding prompt |
| Equipment (weapon variety) and elemental/magic systems are the highest-priority Stretch Goals after MVP | Founding vision emphasizes magic and weapon variety; Gameplan already licenses building these "once the base loop is fun" - this reprioritizes within the existing Stretch sequencing rather than reopening MVP scope | 2026-07-05 / this session's founding prompt, Gameplan.md section 10/17 |
~~No separate integration branch; branch-per-milestone -> PR directly into `main`~~ - **superseded 2026-07-05 (second session), see the `integration` staging-branch row below** | Solo hobby project - matches how Kayden's other personal-scale projects (e.g. DigitalTome) actually run day to day; the workbench's own 3-tier convention is calibrated for the shared harness repo, not every downstream product | 2026-07-05 / this Adoption run |
| `integration` branch as staging before `main` - work accumulates on `integration`; Kayden explicitly syncs `integration` -> `main` when ready, rather than every task PRing straight to `main` | Kayden's call once the first-playable slice was working and felt worth protecting - gives a reviewable, shippable line separate from in-progress work, at the cost of one extra branch for a solo project | 2026-07-05 (second session) / this session |
| Concrete first-playable scenario: forest test area, grid-snapped walk, talk to one NPC, touch a visible enemy, win a simple turn-based battle, return to the same forest position, get a key/reward, open a blocked path | Kayden gave this as the smallest testable slice to build toward - smaller than the full Phase 6 finish line (no boss/save/party depth required), useful as an early integration smoke test once combat exists (see TASKBOARD.md T-013, deferred) | 2026-07-05 / this session |
| GBA-fantasy-adventure visual language: bright, readable, toy-like overworlds with chunky silhouettes, dense environmental texture, clean top-down camera; tiles built from 8x8/16x16 units | Kayden's explicit visual-reference table (GBA-era fantasy-adventure art direction as the touchstone, not any one licensed title); narrows rather than contradicts the flexible-HD/ultrawide rendering decision above - the canvas renders natively at 1280x720+, the art itself is built from small GBA-style tile units | 2026-07-05 / this session, see Visual Language section |
| General moment-to-moment loop confirmed as explore -> interact with an object/NPC/enemy -> take an action -> see the consequence -> continue exploring | Kayden's explicit framing for what "first playable" should feel like at every scale; confirms rather than changes the existing concrete first-playable scenario (row above) | 2026-07-05 / this session |
| Combat is grid-based (units occupy cells, check move/attack range, can move each turn); turn order is strict per-character initiative (speed), never a whole-team phase | Kayden's explicit combat-loop framing: check ranges -> move -> attack phase -> results, repeated per unit in initiative order, not team-by-team; the `TurnManager` design already sorted all combatants together by speed - only the Battle FSM's stale `PlayerPhase`/`EnemyPhase` state names implied team-phasing, and those are retired | 2026-07-05 / this session |
| Combat resolution uses a d10 percentage system (roll 1-10 against a stat-derived success threshold) instead of flat deterministic damage-only math | Kayden's explicit request for a system where success chances read as clean percentages; exact threshold/damage formula is a Phase 3/4 combat-math implementation decision (red/green/refactor per `AGENTS.md`), not decided here | 2026-07-05 / this session |

## Health Criteria

The project is healthy when:

- `game/` opens headlessly with zero errors (`Godot --headless --path game
  --import`, then `Godot --headless --path game scenes/main.tscn
  --quit-after 1`) - the only baseline that applies at Phase 0.
- Once Phase 1+ lands: the primary user workflow - walk the overworld, solve a
  puzzle, fight a visible enemy, win or lose, return to the same spot - passes
  as a manual check end to end.
- Empty, error, and degraded states do not crash (no active save slot, party
  wiped in combat, missing input device).
- Android keystores and signing passwords never appear in committed or
  exported output.

Verification commands live in `RUNBOOK.md`. Current task status and proof
history live in `TASKBOARD.md`.
