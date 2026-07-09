# Dungeon Friends - Blueprint

> Generated from LLM Workbench v2.1. See `RUNBOOK.md` -> Upgrading The
> Harness.

**Last reviewed:** 2026-07-05
**Status:** partial
**Source root:** `/Users/kayden/GPT_OS/Projects/Dungeon_Friends_Game`

This is the stable reference for what the project is. This file is the
canonical design doc and the summary a future agent should read first; the
toolchain research behind its decisions is in [`docs/research/audited_research.md`](docs/research/audited_research.md).
(The former `docs/planning/Gameplan.md` was retired 2026-07-08 - its content is
absorbed here, in `RUNBOOK.md`, and in `TASKBOARD.md`.)

## What This Project Is

A 2D top-down adventure RPG: **Zelda meets BG3**. Exploration is in the
structural tradition of classic Zelda games (grid-based overworld and dungeons,
block-pushing puzzles, switches, locked doors, key items that unlock new areas).
Combat is **tactics-RPG**: touching a visible enemy drops the game into a
dedicated turn-based battle mode (BG3's turn-based mode is the direct model) -
you command a party of up to four "Dungeon Friends" on a zoomed-in tactical
grid, selecting a unit, seeing its movement and attack range highlighted (Fire
Emblem is the *visual* reference for that presentation, not a separate combat
model), and spending ability-driven turns in strict initiative order. This is
**not a JRPG**: positioning, range, and ability choice carry real weight; the
party is not a menu-driven line-up. The player explores a hand-authored world -
beginning in a fantasy forest with a Kokiri-Forest-from-Ocarina-of-Time mood,
later opening into a castle city, mountains, rivers, and surrounding wilderness -
while recruiting the party members who fight alongside them.

Visually it's retro-pixel-art *inspired*, not any specific handheld-accurate:
a flexible HD/ultrawide base resolution (1280x720 design reference, scaling
cleanly up through 1920x1080 and 3440x1440), nearest-neighbor filtering,
unrestricted palette - retro sprite silhouette (chunky pixel art, grid
movement, tile-based dungeons), not a hardware recreation and not locked to
any one fixed low-res canvas. See Visual Language below for the specific
GBA-fantasy-adventure look (bright/readable, toy-like overworlds, chunky
silhouettes, 8x8/16x16 tile logic) this project targets.

On the D&D question: BG3 is itself a D&D-shaped RPG, and that *shape* (classes,
roles, abilities, a small stat block, party builds) is the target. What this
project is **not** is a literal D&D implementation - no pulling 5e
rules-as-written or SRD/OGL content into the game. A D&D-shaped RPG that isn't
Wizards-of-the-Coast's ruleset. Combat resolution uses a d10 percentage system
(see Core Logic And Invariants), not literal D&D dice.

Core promise:

> Walk a hand-built overworld, get pulled into a readable turn-based tactical
> battle without a jarring scene change (the camera zooms into where you were
> standing, early-Final-Fantasy style, so the world reads as bigger than its
> actual grid), command your party of Dungeon Friends on the zoomed-in grid,
> solve a block/switch/key puzzle, and grow that party across a forest, a
> castle city, and a mountain/river region.

Primary users:

- Kayden - solo player and primary tester.
- Friends/family Kayden shares built exports with (macOS/Windows/Android).
- A future AI agent (Claude, Codex, or other) picking this repo up cold.

## Design Pillars

The five product pillars, in priority order (confirmed 2026-07-08, Kayden -
these replace the four dev-discipline pillars from the retired Gameplan
(movement precision, combat-simple-to-build, party-collection, scope-discipline);
pillar 1 survives as the quality-bar note below):

1. **Adventure First.** The player should always feel like they are on a clear
   fantasy adventure: walk the overworld, find secrets, enter dungeons, solve
   puzzles, earn key items, open new paths.
2. **Party-Based Progression.** Companions are not just story flavor. Each
   Dungeon Friend should change how the player fights, explores, or solves
   problems.
3. **Readable, Tactical Combat.** BG3-style turn-based tactics on a zoomed-in
   grid: positioning, range, and ability choice carry real weight, and depth is
   the point (the earlier "quick decisions over tactical depth" framing is
   retired - see Design Decisions, 2026-07-08). "Readable" is the constraint,
   not a cap on depth: small parties, clear stats, distinct abilities, visible
   outcomes, and a legible board keep the tactics from becoming bloated.
4. **Compact Open World.** The world should feel open and interconnected but
   not endless. Regions are dense, authored, and full of meaningful gates,
   shortcuts, secrets, and dungeon entrances - hand-built, never procedurally
   generated.
5. **Retro Feel, Modern Flexibility.** The game looks and feels like a chunky
   pixel-art adventure RPG, but it is not a strict hardware recreation. Use
   retro visual logic where it helps readability, not where it limits the game.

The most important quality bar underneath these: movement and puzzle feel
(precise, grid-snapped, no floaty physics) over feature breadth.

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
| Tiles | Strong grid logic, built from reusable 16x16 tile pieces rendered at 4x (decided at M1.1, 2026-07-06 - resolves the former "TBD" within the 8x8/16x16 range this table set) |
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

Target shape once Phase 0-6 (the MVP) is complete - **not yet built**; see
`TASKBOARD.md` for what actually exists today. When the project is working, a
user can:

- Walk a grid-based overworld and dungeon with precise, snapped movement.
- Solve pushable-block / pressure-plate / locked-door puzzles gated by key
  items.
- See enemies on the map, touch one, and enter a dedicated turn-based tactical
  battle (BG3 turn-based mode is the model): select a party unit, see its
  movement and attack range highlighted (Fire Emblem-style presentation), move
  it within range, and act. Each combatant takes its own turn in strict
  initiative (speed) order - never a whole-team phase - resolved with a d10
  percentage roll (party of up to four, Attack/Ability/Item/Defend), with a
  camera-zoom transition into the encounter and back.
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
above (no full dungeon, no boss, no save/load, no full party depth
required) - treat it as the walking skeleton the fuller Phase 6 slice builds
on top of, not a replacement for it.

**Status (2026-07-07, post-playtest rework): the Phase 2 tutorial dungeon is
playable from `main.tscn` in its revised four-room layout** - still
placeholder art, all through the LDtk pipeline. Kayden's first windowed pass
(2026-07-07) found the forest's tree colliders rendering as plain grass
(fixed: every Wall cell now draws its tree tile, plus new open-field
clusters) and the pressure-plate flow reading as broken (its momentary
semantics re-lock the door the moment you step off) - **plates are ON HOLD**
and out of the dungeon. The reworked dungeon (`tutorial_dungeon.ldtk`,
4 levels): hub with lock-behind entry and an Oracle-style **13-brick wall
where exactly one brick pushes free** (fixed bricks can't wedge; reset lever
kept as escape valve); a locked **north door** (dungeon_key) to the new
**chest room** holding the shield chest (door locked, chest not - Kayden's
call); the pit room reworked to two 1-wide jumpable ledges plus the 2-wide
chasm solved by block-fill (T-025 jump, Alt/C); the fight room's Dungeon
Slime drops the **dungeon_key**; west loop-back shortcut; opening the chest
unbolts the entry. Party defeat restarts from the beginning (T-029/D-004).
Debug builds carry an F1 dev overlay (T-030). Verified by a 109/109-check
headless smoke test plus 17 unit suites (351 checks) including the exhaustive
soft-lock solver, now jump- and fixed-brick-aware, over the real shipped
rooms. **Kayden's windowed re-check passed 2026-07-08 - Phase 2 is
accepted** (his one feel note, "block movement is a bit chunky", is parked
as `TASKBOARD.md` T-059); real art comes in the post-Phase-2 art pass.

The most important quality bar is:

- Movement and puzzle feel (precise, grid-snapped, no floaty physics) over
  feature breadth - see Design Pillars above (the canonical five, 2026-07-08),
  which replace the retired Gameplan's four dev-discipline pillars.

## Direction And Build Order

Current phase:

- **Phase 2 accepted (Kayden's windowed re-check, 2026-07-08); Phase 4
  (Combat MVP) is the current phase - Kayden's explicit pull-forward.**
  Everything in "Phase 2 Target: Tutorial Dungeon" below (including the
  2026-07-07 revision block) is implemented, headless-verified, and now
  play-confirmed: the LDtk entity pipeline (T-031), the LDtk-authored
  forest (T-011), the puzzle primitives (T-023/T-025/T-026; T-024 plates
  built but ON HOLD), defeat-restart (T-029), dev tools (T-030), and the
  four-room tutorial dungeon (T-027). Phase 1 is fully done (T-020's
  windowed 3-resolution check also passed 2026-07-08); Phase 0's M0.3
  (export presets) stays in the TASKBOARD Backlog. **Build-order
  re-sequencing (2026-07-08, Kayden):** combat is his main complaint, so
  Phase 4 starts ahead of Phase 3's save/load half. Phase 3's M3.1
  data-class half (ItemData, AbilityData, EncounterData/MapMeta stubs, XP
  shape, stat alignment, shield-gates-Defend) moves with Phase 4 as its
  data foundation; the M3.2/M3.3 save/load half (SaveData, registry,
  crystal, load flow, checkpoint respawn, pit falls, enemy respawn) stays
  planned in `TASKBOARD.md` and resumes after combat. The Phase 4 lane is
  `TASKBOARD.md` T-060..T-069.

Build order (each phase is a real milestone with a stated "done" condition;
live milestone tracking is in `TASKBOARD.md`):

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
5. **Phase 4 - Combat MVP** - the turn-based tactical combat core (BG3
   turn-based mode as the model, Fire Emblem-style range highlighting):
   `TurnManager`, two-layer FSM, unit selection + highlighted move/attack range,
   Attack/Ability/Item/Defend.
6. **Phase 5 - Party System & Progression** - recruitment, XP/leveling,
   party management menu. **The overworld avatar stays a single character**
   (revised 2026-07-06 - see Party And Combat Model below); the party's
   multiple characters appear only inside tactical combat, not as overworld
   followers.
7. **Phase 6 - First Playable Slice** - one full forest dungeon (3-5 rooms,
   puzzles, encounters, boss) proving the whole loop end to end. This is the
   MVP finish line.
8. **World expansion (post-MVP, content work, no new architecture)** - castle
   city, then mountains, then rivers, and the surrounding wilderness, each
   authored as new `world.ldtk` regions using the systems already built for the
   forest.
9. **Stretch goals (sequenced)** - see `TASKBOARD.md` Deferred lane: equipment/
   weapon variety and elemental/magic system are the two highest-priority
   stretch items given the emphasis on magic and weapon variety in this
   project's founding vision, followed by telegraphed combat UI, traversal
   abilities, resource-gauge mechanics, more dungeons/full overworld map,
   cosmetic shader, roguelike postgame.

### Movement-State Roadmap (2026-07-06, Kayden)

Kayden's priority ordering for movement/traversal capability. Rows 1-3 are
MVP work (Phases 1-2); rows 4-5 are Deferred (`TASKBOARD.md` S-009/S-010) -
do not build them early.

| Priority | Movement type | Why | Where it lands |
|---:|---|---|---|
| 1 | Walk, face, act lock-in | Core feel | Phase 1 - T-021 (walk exists; feel polish + turn-in-place is the open work) |
| 2 | Door transitions, ledges, stairs | Room/world structure | T-022 (door transition, Phase 1) + T-025 (ledges/pits + jump, Phase 2) |
| 3 | Push/pull objects | Zelda puzzle baseline | Phase 2 - T-023 (PushableBlock) |
| 4 | Dash/roll | Makes overworld feel better | Deferred S-009 |
| 5 | Swim (or similar) | First major traversal upgrade | Deferred S-010 - pairs naturally with the post-MVP rivers region |

### Phase 2 Target: Tutorial Dungeon (2026-07-06, Kayden)

Phase 2's puzzle primitives are built *in service of* a concrete 3-room
tutorial dungeon behind the Boss Slime's locked east door (the door the
current slice already unlocks). Each room teaches one mechanic; the whole
thing is the Phase 2 "done" condition. The Phase 6 forest dungeon then builds
on these same primitives.

Layout (revised 2026-07-06 round 2, Kayden): Room 1 is a **hub** connected to
two other rooms - Zelda-style, so the reward loop reads spatially instead of
via a surprise trigger.

- **Room 1 - hub: block + plate + the locked chest.** The door locks behind
  the player on entry. A **locked treasure chest is visible from the start**
  (no ceiling-drop trigger - "if you're confused the players will be too");
  it holds the shield and can't be opened until the chest key comes back
  from Room 3. A **3x3 pushing space** sits in the room with the
  `PressurePlate` at its **center** and a `PushableBlock` in a **corner** of
  that 3x3, plus a 2-cell walking margin around it (see the plate-geometry
  note in Core Logic): the player circles the block via the margin and pushes
  it - an L-shaped, non-diagonal path - onto the center plate. The plate opens
  the next door while pressed and re-locks it when released - the player
  standing on it demonstrates the mechanic; the block parked on it is the real
  solution.
- **Room 2 - pit room.** A **2-cell-wide** pit spans the full room width -
  deliberately beyond the 1-cell jump limit, so jumping alone can't cross
  it. The intended solution: push the room's block into the pit (fills one
  cell), then **jump the remaining 1-cell gap from the filled cell** -
  teaching block-fills-pit, the jump, and the jump's limit in one move.
- **Room 3 - fight + loop back.** An enemy that drops the **chest key** on
  defeat. The player loops back to the Room 1 hub, opens the chest, and gets
  the **shield** - a plain inventory item for now (decision D-001 resolved
  2026-07-06: skeleton first; its real effect is a question for
  Phase 3/S-001, asked when we get there).

**Death & respawn (revised 2026-07-06 round 3, Kayden):** for Phase 2, party
defeat simply **restarts from the beginning of the game** - no mid-dungeon
respawn, no puzzle-state snapshot. The richer respawn (old man when defeated
outside, Room 1 with puzzle reset when inside) is **deferred to Phase 3**,
where it rides on the save/load serialization it actually needs. See the
Death & respawn rule in Core Logic.

Design intent: "That is a lot, but that should be a good tutorial, and a good
place to call Phase 2" - this supersedes the generic M2.1-M2.4 test-room
framing as the concrete deliverable, while keeping the
same primitives underneath.

#### 2026-07-07 revision (Kayden's first windowed playthrough)

Kayden's playtest notes rescoped the dungeon to **four rooms** and put the
pressure plate **on hold** ("the pressure plate never worked in the game" -
its momentary re-lock made the flow read as broken; the primitive and its
unit suite stay in the codebase, it just isn't in the shipped dungeon):

- **Room 1 - hub: the brick wall.** Entry locks behind the player. A wall of
  **13 identical stone bricks** spans the room, Oracle-of-Seasons style
  (Kayden supplied a reference screenshot): **only one brick budges** - push
  it through to open the way. Fixed bricks (`PushableBlock` with
  `Movable=false`) can never wedge, "so we don't soft lock ourselves"; the
  reset lever stays as the escape valve for the one movable brick. No chest
  in this room and no plate.
- **Room 2 - chest room (new).** A small side vault behind the hub's north
  **locked door** (`dungeon_key`). Kayden: "I know I said the chest was
  locked but I thought about it some more and I like having the door locked
  instead" - so the door is the lock and the chest inside opens freely,
  holding the shield (D-001).
- **Room 3 - pit room: ledges + chasm.** From the south: two **1-wide
  jumpable ledges** (jump practice at exactly the jump limit), then the
  **2-wide chasm** crossed by pushing the block in and jumping the last gap.
  Wedge-proof by construction: the block sits on the chasm's near bank,
  every column it can be pushed into sinks it usefully, and no push can
  reach the ledges.
- **Room 4 - fight + loop back.** The key guardian drops the **dungeon_key**
  (opens Room 2's door). West loop-back shortcut to the hub unchanged.

Also from the same playtest: the forest's tree walls were rendering as plain
grass (every collider now draws its tree tile) and Kayden wants obstacles
"out in the open" between spawn and the dungeon entry - "maybe not a maze,
but at least trees or something" (added as scattered clusters).

## Architecture

| Layer | Choice | Source / Notes |
|---|---|---|
| Engine/Runtime | Godot 4.7.x, GDScript | Upgraded from 4.6.x on 2026-07-07 (Kayden's call); installed and verified: `4.7.stable.official.5b4e0cb0f` (full clean reimport + unit/smoke suites all green on 4.7) |
| Renderer | Mobile | Locked (audit §4.1) |
| UI | Godot `Control` nodes + `CanvasLayer` (HUD, dialogue, menus) | `game/scenes/ui/` |
| Backend | None - fully local, no server, no accounts | |
| Storage | `Resource` (`.tres`) files for game data; `SaveData` (JSON) to `user://saves/` | `game/data/`; save format per D-006 (see Core Logic) |
| Levels | LDtk, imported via `heygleeson/godot-ldtk-importer`, entities all-in per D-002 | **Importer v2.0 + entity post-import pipeline live 2026-07-06** (T-004/T-031): each `.ldtk` sets `entities_post_import` to `scripts/ldtk/entities_post_import.gd`, which instantiates the matching game object per entity (conventions documented in that script); `LdtkRoom` adopts them into the runtime grid. Current worlds: `forest.ldtk` (T-011), `tutorial_dungeon.ldtk` (4 levels, T-027 + 2026-07-07 rework), `entity_test_room.ldtk` (pipeline test fixture), `test_room.ldtk` (T-004 fixture) - consolidation into one `world.ldtk` can wait for real LDtk-app authoring. The LDtk desktop app is installed (Gatekeeper cleared); the `.ldtk` files are still bootstrap-generated JSON (`assets/levels/_scripts/generate_levels.py`) until Kayden starts hand-authoring |
| Art | Aseprite (primary, Lua/CLI-scriptable, **not yet installed** - purchase is Kayden's call), Pixelorama (fallback) | 1280x720 design-reference base, flexible HD/ultrawide scaling (see Design Decisions); **grid unit decided at M1.1 (2026-07-06): 16x16 art pixels rendered at 4x = the 64px runtime cell** (`RoomGrid.TILE`). First real art exists (`assets/art/tilesets/test_tiles.png`, `sprites/test_hero.png`), generated deterministically by `assets/art/_scripts/generate_test_tileset.gd` as a stopgap; the Aseprite exporter (`export_sheets.lua`/`.sh`) is ready and takes over the same output paths once Aseprite is installed |
| Audio | Furnace Tracker -> `.ogg` -> `AudioStreamPlayer`/`AudioStreamPlayer2D` | No hardware-channel-emulation engine (dropped, not deferred) |
| Testing | Headless Godot CLI checks (`--import`, `--quit-after`) | No GDScript test framework yet - see `RUNBOOK.md` |
| Deployment/Export | Godot editor Export dialog: macOS, Windows, Android | `RUNBOOK.md` -> Test And Build |

Architecture constraints:

- Single Autoload: `SceneManager`. No other autoloads - additional global
  state goes on `SceneManager`'s `GameState`/`SaveData` resource. **Built
  2026-07-07 (T-036):** `SceneManager.state: GameState` holds the mutable
  session (party roster/levels/xp/hp, inventory, flags); `hero_hp`,
  `total_xp`, `inventory`, `flags` are forwarding properties over it and
  `add_item()` is the one deduped inventory write path. Reset/load swap the
  whole `GameState` in one move - the shape `SaveData` (T-037) serializes.
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
│   ├── shaders/
│   └── tests/                       <- first-party headless unit suites + runner (see RUNBOOK.md -> Unit tests)
├── docs/
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
| Overworld / Dungeon (LDtk-instanced) | Grid movement, puzzles, visible enemies | working through the LDtk pipeline: `RoomGrid` runtime grid model + `LdtkRoom` base (imports the level, feeds Wall/Pit IntGrids into the grid, adopts post-import-spawned entities) + `ForestRoom` (`forest.ldtk`) | `game/scripts/overworld/`, `game/scripts/ldtk/entities_post_import.gd`, `game/assets/levels/` |
| Combat | Turn-based tactical party-vs-enemy battle (BG3 turn-based mode) | **Rebuilt 2026-07-08 (T-060..T-064)**: two-layer FSM (Battle FSM in `CombatScene`, per-entity FSM on `CombatUnit`) + `TurnManager` interleaved initiative; party from the GameState roster (hero + D-013 test companion) vs enemy parties (EncounterData-capable); arena seeded from the local room terrain around the contact point, restricted to the contact-connected region (D-012); FE-style move-range highlight + cursor cell pick + threat fringe; Attack/Ability/Item/Defend commands (strike/mend spend MP, potions consume stock, Defend shield-gated per D-007); real `CombatMath` d10 formulas (numbers tunable at T-069); simple close-and-attack AI. Still code-built (no .tscn); fade transition pending the T-065 zoom; HUD strip pending T-067 | `game/scripts/combat/combat.gd`, `combat_unit.gd`, `turn_manager.gd`, `combat_math.gd` |
| UI (HUD, dialogue, pause, party menu) | Player-facing menus and status | dialogue box exists (`DialogueBox`, code-built); HUD/pause/party menus missing | `game/scripts/ui/dialogue_box.gd` |
| `game/scenes/dev/display_scaling_spike.tscn` | Throwaway diagnostic - proves the new flexible HD/ultrawide stretch settings render an undistorted tile grid at 1280x720/1920x1080/3440x1440 | working (placeholder ColorRect tiles, no real art yet) | `game/scenes/dev/display_scaling_spike.tscn`, `game/scripts/dev/display_scaling_spike.gd` |
| Tutorial dungeon (behind the boss door) | The Phase 2 deliverable (T-027, reworked 2026-07-07 after Kayden's playthrough): four LDtk-authored rooms (`tutorial_dungeon.ldtk` levels HubRoom/ChestRoom/PitRoom/FightRoom, scripts `tutorial_*_room.gd`) navigated via `SceneManager.boot_room/enter_room/exit_room(s)` (suspend-not-free downward, freed-and-rebuilt on the way back up - the rebuild is the puzzle escape valve; persistent facts like opened chests/doors and slain unique enemies live in `SceneManager.flags`). Supersedes the T-022 cave stub room, whose wiring it inherits | working (2026-07-07 layout), Kayden's windowed re-check pending | `game/scripts/overworld/tutorial_hub_room.gd` / `tutorial_chest_room.gd` / `tutorial_pit_room.gd` / `tutorial_fight_room.gd`, `game/assets/levels/tutorial_dungeon.ldtk` |

### Commands

Godot Input Map actions (single source of truth for all gameplay input across
keyboard, controller, and mobile touch - per-device bindings below):

| Command | Purpose | Required for done? |
|---|---|---|
| `move_up` / `move_down` / `move_left` / `move_right` | Grid movement | yes |
| `interact` / `confirm` | Interact with objects/NPCs; confirm menu selection | yes |
| `cancel` / `back` | Cancel or back out of a menu | yes |
| `menu` | Open pause/party menu | yes |
| `jump` | Hop one cell over a pit/ledge in the facing direction (Phase 2) - bound to Alt primary, C fallback (2026-07-06) | yes (from Phase 2) |

Per-device bindings (Godot Input Map is the single binding source; migrated
from the retired Gameplan §11):

| Action | Keyboard | Controller | Touch (mobile) |
|---|---|---|---|
| `move_*` | Arrow keys / WASD | D-pad / left stick | On-screen virtual D-pad |
| `interact` / `confirm` | Z / Enter | A (Xbox) / Cross (PS) | On-screen "A" |
| `cancel` / `back` | X / Escape | B / Circle | On-screen "B" |
| `menu` | Enter / Tab | Start / Options | On-screen menu icon |
| `jump` | Alt (primary) / C (fallback) | (TBD) | On-screen button |

`TouchScreenButton` nodes map directly to Input Map actions, so gameplay code
reads `Input.is_action_pressed(...)` regardless of source; the touch UI is only
shown on mobile exports; Godot 4 auto-detects most standard gamepads.

### Data Model

| Entity | Key fields | Stored where | Notes |
|---|---|---|---|
| `CharacterStats` | `id, display_name, max_hp, max_mp, attack, defense, speed, sprite_frames, starting_abilities` | `game/data/characters/*.tres` | Party member stat block |
| `EnemyStats` | `id, display_name, max_hp, attack, defense, speed, abilities, ai_behavior, xp_reward, loot_table` | `game/data/enemies/*.tres` | `ai_behavior`: `RANDOM_WALK` / `BIASED_TRACKING` / `PATTERN` |
| `ItemData` | `id, display_name, item_type, stat_modifiers, on_use_ability` | `game/data/items/*.tres` | `item_type`: `KEY_ITEM` / `CONSUMABLE` / `EQUIPMENT` |
| `AbilityData` | `id, display_name, mp_cost, target_type, element, power, overworld_use` | `game/data/abilities/*.tres` | `element`/equipment-adjacent fields exist for Stretch Goals 1-2, unused at MVP |
| `MapMeta` | `ldtk_level_id, display_name, music_track, encounter_table` | one companion `.tres` per level | LDtk is the source of truth for layout; this covers non-visual metadata |
| `EncounterData` | `id, enemy_group, background_id` | `game/data/encounters/*.tres` | Referenced directly by overworld enemy instances - no random rolls |
| `SaveData` | `schema_version, current_map, player_position, party_roster, party_levels/xp/hp/mp, inventory, flags` | `user://saves/slot_N.json` (JSON - D-006, 2026-07-07) | Never saved mid-combat; 3 slots from the start; no `defeated_enemy_ids` - enemies always respawn (D-009) |

*Note (2026-07-05, reaffirmed 2026-07-08):* the tactics-RPG combat model means
`CharacterStats`/`EnemyStats`/`AbilityData` **will need** move-range and
attack-range fields (they drive the highlighted movement/attack ranges in
battle) - not yet added to the table above; exact field names/shape are a
Phase 3/4 implementation decision, not decided here.

*Status (2026-07-05, second session; ItemData row updated 2026-07-08):*
`CharacterStats` and `EnemyStats` exist (`game/scripts/data/`) with the
fields listed above, plus first instances `game/data/characters/hero.tres`
and `game/data/enemies/forest_slime.tres`. **`ItemData` is built (T-034,
2026-07-08)**: `item_data.gd` + `item_library.gd` (id -> ItemData lookup
over `game/data/items/`, where forest_key/dungeon_key/shield now live as
`.tres`), and the session inventory is a `{item_id: qty}` Dictionary on
`GameState` - key items/equipment never stack, consumables do, and
`SceneManager.add_item()/remove_item()` are the only write paths.
`AbilityData`/`MapMeta`/`EncounterData`/`SaveData` are still open (T-035/
T-044/T-037). `EnemyStats.loot_table` deliberately stays a
`PackedStringArray` of item ids resolved through the library - the T-043
deviation.

## Party And Combat Model

Clarified 2026-07-06, combat model sharpened 2026-07-08 (Kayden) - this shapes
the overworld, combat, and Phase 5, and **supersedes the old "snake-follow
formation" party idea** (from the retired Gameplan §10, never built):

- **The overworld avatar is a single character** representing the whole party.
  No snake-follow train of `PartyFollower` bodies. Movement, pushing, jumping,
  and puzzles are all single-actor in the overworld - the systems Phase 2
  builds don't need to anticipate follower actors.
- **The party's individual characters exist only inside combat.** Touching a
  visible overworld enemy is a **party encounter**, not a single-character one
  (the slime you bumped represents an enemy party; your avatar represents
  yours). The game zooms **way in** on the contact point - far enough that the
  enemy is no longer on top of you, reading as "they entered the same zone and
  spotted you" - and switches into a dedicated **turn-based tactical battle
  mode**. **The model is BG3's turn-based mode**: top-down tactical control of a
  **party of up to four** against the enemy party on a local mini-map.
- **Control in battle mode:** you **select a unit**; its **movement range and
  attack range light up on the grid** (this is the Fire Emblem *visual*
  affordance Kayden wants - range highlighting and a distinct combat mode - not
  a second combat model). You then move that unit anywhere inside its range and
  spend its turn on an ability-driven action. Units act one at a time in strict
  initiative order; when the enemy party is defeated the battle ends and play
  returns to exploration at the contact point.
- This keeps the overworld simple and readable while concentrating the
  positioning depth in the tactical battles, and is consistent with the
  already-locked grid-based, per-unit-initiative, d10 combat below (it names the
  *control scheme, framing, and genre* - tactics-RPG, not JRPG - not new combat
  math).

## Core Logic And Invariants

The combat/movement/data rules below are locked technical decisions (resolved
2026-06-11 per the research audit; the Combat rule below was extended
2026-07-05 with grid/range/d10 specifics directly from Kayden, 2026-07-06 with
the single-avatar tactical-control framing above, and 2026-07-08 with the
tactics-RPG / BG3-turn-based-mode identity and party-of-four size) - do not
relitigate without flagging to Kayden first; see `AGENTS.md` -> When To Ask,
Proceed, Or Stop.

Rules:

- **Grid movement**: compute the target cell, raycast/tile-check it, then
  `Tween`-interpolate over ~0.12-0.2s. Entities always rest exactly on grid.
  Never velocity-based `CharacterBody2D` free movement.
  - **Feel bar (added 2026-07-06, Kayden):** grid-locked but never
    *feels* locked - the Zelda/Pokemon standard where the player is on a grid
    but never reads as "clicking into place". Held movement chains steps with
    no inter-step hitch; a tap turns the player to face first, then a
    continued press steps (turn-in-place); facing locks during
    interactions. This is a feel requirement on top of the invariant, not a
    change to it (T-021).
- **Jump (added 2026-07-06, revised same day - Kayden)**: a **player-pressed
  button** (`jump` input action, bound to Alt primary / C fallback - see
  Commands), not automatic - Kayden: "I don't want to trust that my character
  will jump the right way." Pressing jump hops one cell in the facing
  direction as a `Tween` arc (like any other step, never physics). **Max jump
  distance is exactly 1 cell** - a 1-cell gap is the definitional jumpable
  gap; 2+ cells is never jumpable. The jump only *succeeds* over a
  jumpable gap/ledge (a jump into a wall or across too-wide a pit just plays
  a small in-place hop or is refused); it is not a free traversal everywhere.
  Single overworld avatar (see Party model below), so no follower-jump to
  coordinate.
- **Pathfinding**: `AStarGrid2D`, `diagonal_mode = DIAGONAL_MODE_NEVER`,
  Manhattan heuristic.
- **Combat**: a **tactics-RPG battle** (BG3 turn-based mode as the model, Fire
  Emblem-style range highlighting as presentation - **not a JRPG**), grid-based
  and turn-based, with a party of up to four units the player selects and moves
  within a highlighted move range. Resolved with a **d10 percentage system** -
  roll 1-10 against a stat-derived success threshold, so success chances map
  directly to clean percentages (e.g. a threshold of 7 reads as a 70% chance). Exact threshold/damage formula is TBD at the Phase 3/4
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
- **Enemies** are visible on the overworld map, move on their own clock
  (autonomous real-time stepping - revised 2026-07-05 after playtest feedback,
  supersedes the old synchronized-turn/Lufia-II model), and trigger combat on
  contact. They wander until the player is within a notice radius, then path
  toward them. Movement is still grid-snapped Tween stepping (the locked
  movement invariant is unchanged - only the *trigger* moved from player-steps
  to a timer). No random or invisible encounters.
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
  debug than fully-automatic wiring). Semantics confirmed 2026-07-06 (Kayden):
  - **PressurePlate is momentary** (pressed while any grid occupant - player
    *or* block - stands on it, released the moment the cell is vacated; a
    plate-driven door re-locks on release), **and is ON HOLD as of
    2026-07-07**: in Kayden's windowed playthrough the re-lock made the flow
    read as broken ("the pressure plate never worked in the game"). The
    primitive and its unit suite stay in the codebase, but no shipped room
    uses a plate until the mechanic is revisited (likely needing a visible
    cause-effect cue or latching variant).
  - **PushableBlock.movable (added 2026-07-07)**: `Movable=false` makes a
    fixed brick - identical placeholder look, occupies and blocks its cell,
    refuses every push. This is the hub brick-wall primitive ("wall where
    you can only push some bricks, so we don't soft lock ourselves"); the
    2026-07-06 3x3-plate geometry note is retired with the plate hold.
  - **Pits (revised 2026-07-07, D-008 - supersedes "impassable, not
    lethal")**: a 1-cell-wide pit can be jumped (see Jump above); a
    `PushableBlock` pushed into a pit **fills it**, permanently converting
    that cell to walkable floor (classic Zelda). **Walking into a pit is a
    Zelda-style fall** (T-047): small damage (tunable, first cut 1 HP) and
    respawn at the last entrance the player came through into that room; a
    fall that reaches 0 HP triggers the defeat flow. Enemies and pathfinding
    still treat pits as blocked.
  - **Chests**: a `Chest` interactable holds a reward and may be locked
    (opens only with its matching key item), reusing the `LockedDoor`
    key-check pattern. Chests are placed visibly in the room from the start -
    no surprise reveal triggers ("if you're confused the players will be
    too", 2026-07-06).
- **Death & respawn (revised 2026-07-07, D-008 - the Phase 3 rule)**: party
  defeat is never a game-over dead end, and **redoing content is never the
  punishment - losing XP is** (money may join/replace it once currency
  exists). On defeat: **keep inventory; lose XP but never below the current
  level's floor** (T-045 curve; exact penalty tunable); respawn at the
  **dungeon entrance** when defeated inside a dungeon (rooms between reset -
  puzzles and enemies alike), or at the healer's campfire outside. Defeat
  never touches save files. Full HP on respawn (agent interpretation, flag
  if wrong). The Phase 2 restart-from-the-beginning rule is retired once
  T-041 lands; `restart_game()` remains a dev tool.
- **Enemy respawns (added 2026-07-07, D-009)**: **enemies respawn every time
  a room is left and rebuilt** - the same reset that un-wedges puzzles
  applies to enemies, uniques and bosses included (duplicate key drops are
  prevented by loot dedup; opened doors/chests stay open via flags).
  Suspended-and-restored rooms (mid-trip) keep their in-visit state.
  Deliberate deviation from the original Lufia-II defeated-enemies-stay-dead
  pattern (retired Gameplan §12); `SaveData` carries no `defeated_enemy_ids`.
- **Save (revised 2026-07-07, D-006/D-011)**: save points are physical map
  objects (SaveCrystal); `SaveData` serializes to **JSON** at
  `user://saves/slot_N.json` (authored data stays `.tres` under `res://`);
  never saved mid-combat; defeat/checkpoints never write saves; 3 slots in
  the format, slot 1 via the crystal at MVP; a minimal Continue/New Game
  prompt when a save exists at boot.

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
| Scope creep from an oversized feature wishlist | High | The MVP/Stretch split (Non-Goals above; Deferred lane in `TASKBOARD.md`) is the guardrail - revisit it before adding any new system mid-phase |
| Solo + AI-assisted dev underestimates UI work (menus, inventory, party management) | Medium | UI-heavy phases (4, 5) get dedicated milestones rather than being bundled into "just add combat" |
| Android export friction (SDK/JDK setup, device-specific quirks) | Medium | Addressed in Phase 0 (M0.3), not deferred to the end |
| `heygleeson/godot-ldtk-importer` is a community plugin - could break on Godot updates | Low-Medium | Pin Godot to the current 4.7.x and the importer version (2.0); check its GitHub issues before any engine upgrade. **2026-07-07: the 4.6->4.7 upgrade re-verified clean** - importer 2.0 reimported all four `.ldtk` worlds with no errors/deprecations |
| Ultrawide (21:9) aspect ratios could show too much/too little world at the screen edges under `expand` | Low-Medium | **Resolved 2026-07-08**: Kayden's windowed T-020 run at 1280x720/1920x1080/3440x1440 with the real tileset confirmed `expand` reads fine - no `keep`+letterbox fallback needed. Re-open only if a future region's level art over-reveals at 21:9 |
| "Authentic hardware constraint" scope creep (chasing GB/GBA-accuracy that doesn't serve gameplay) | Low | Any remaining hardware-accuracy ideas (e.g. a CRT shader) stay optional, cosmetic Stretch Goals, never load-bearing |
| Aseprite CLI/Lua automation has a learning curve before it pays off | Low | Start with simple batch-export scripts in M1.1; Pixelorama remains a no-cost manual fallback |
| **No narrative/story/world-lore design exists yet** - the design so far is systems-and-architecture-first, but "go through a story" is part of the founding vision | Medium | Needs deliberate attention before Phase 6 (First Playable Slice) means anything narratively - a vertical slice needs at least one real story beat, not just working systems. Not yet scheduled; flagged here rather than invented unprompted |
| Grid-based combat with per-unit movement/range is more implementation work than flat menu-only JRPG battles (positioning, move-range calc, attack-range validation, arena layout) | Medium | Reuse the overworld's existing `AStarGrid2D`/grid-movement patterns for combat positioning instead of inventing a parallel system; keep Phase 4 MVP range rules simple (e.g. melee = adjacent tile, ranged = fixed tile distance) and defer tactics depth (flanking, terrain bonuses) to Stretch Goals |
| **Block-puzzle soft-locks** (added 2026-07-06): pushable blocks + doors that lock behind the player can create unsolvable states - a block shoved into a corner/off the path, leaving the player trapped in a locked room (and Phase 2 death just restarts the game, so a soft-lock is a hard restart). This is *the* classic block-puzzle bug, ongoing across every puzzle room, not just the tutorial | Medium | Mitigations built at T-024/T-027 (keep applying them to every future puzzle room): (1) blocks can never be pushed onto a doorway cell **or its approach cells** (`RoomGrid.no_block_cells`; the approach-cell rule was found by the solver - a block parked on the exit's only approach was just as fatal as one on the exit); (2) the hub's reset **Lever** returns blocks to their start cells; (3) leaving and re-entering a dungeon room rebuilds it fresh; (4) `tests/test_tutorial_softlock.gd` runs an exhaustive BFS over every reachable block/player state of the real shipped rooms (jump- and fixed-brick-aware since 2026-07-07) and fails if any state can neither solve nor recover; (5) fixed bricks (`Movable=false`, 2026-07-07) make wall-shaped block puzzles wedge-proof by construction - only the one loose brick can move at all. Every new puzzle room must be added to that suite |

## Design Decisions

| Decision | Rationale | Date / Source |
|---|---|---|
| ~~Godot 4.6.x~~ -> **Godot 4.7.x**, GDScript, Mobile renderer | Original 4.6.x matched the audited toolchain recommendation; **upgraded to 4.7.x on 2026-07-07 (Kayden's explicit decision)** after the local toolchain moved to `4.7.stable` - project verified clean on 4.7 (reimport + unit 18 suites/369 checks + smoke 109/109). Mobile renderer + GDScript unchanged | 2026-06-11, rev. 2026-07-07 / audited_research.md §8 |
~~240x160 base resolution (GBA-like, 3:2), nearest filter, integer scaling, `keep` aspect, unrestricted palette~~ - **superseded 2026-07-05, see the flexible HD/ultrawide row below** | GBA-*inspired* not GBC-accurate; more screen real estate than 160x144 while staying grid-friendly (240 = 15x16px, 160 = 10x16px) | 2026-06-11 / audited_research.md §8 |
| Flexible HD/ultrawide base resolution (1280x720 design reference), nearest filter, `canvas_items` stretch mode, `expand` aspect, `fractional` scale mode, unrestricted palette | Kayden decided to drop the fixed low-res GBA-locked canvas in favor of native HD/ultrawide rendering while keeping the retro sprite-art look (nearest-neighbor filtering, chunky pixel silhouettes); `canvas_items`+`expand` shows more world on wider displays (e.g. 3440x1440) instead of pillarboxing, validated by the T-007 display-scaling spike at 1280x720/1920x1080/3440x1440 | 2026-07-05 / this session, supersedes the 2026-06-11 row above |
| No global palette-swap shader / `SCREEN_TEXTURE` post-process in MVP | Was the source of a Compatibility-renderer bug risk; no longer needed once the palette isn't artificially constrained | 2026-06-11 / audited_research.md section 4.1, section 8 decision #2 |
| Single Autoload (`SceneManager`); all other state on `Resource` objects | Keeps global state from becoming a junk drawer; save/load becomes trivial since `GameState` is itself a `Resource` | audited_research.md (SceneManager pattern) |
| Enemies visible on map, ~~synchronized-turn movement~~ **autonomous real-time movement** (revised 2026-07-05), no random encounters | Originally synchronized (audit's Lufia-II pattern) for simplicity; changed after Kayden's playtest - the slime freezing whenever the player stood still felt unnatural. Enemies now step on their own timer (wander, then chase on sight); still grid-snapped, still visible-on-map, still no random encounters | audited_research.md (Lufia-II pattern); revised 2026-07-05 (playtest) |
| Aseprite primary art tool (Lua/CLI-scriptable), Pixelorama fallback | Scriptable batch export lets an agent drive the art pipeline without manual GUI steps | 2026-06-11 / audited_research.md section 8.1 |
| Furnace Tracker for audio *sound*, not a literal hardware-channel-emulation engine | Authenticity of sound, not of engine architecture - the hardware-emulation idea was dropped entirely, not deferred | 2026-06-11 / audited_research.md section 8 decision #4 |
| `game/` subfolder holds the entire Godot project; docs/config live at repo root | Keeps `.godot/` cache and Godot-specific concerns cleanly separated from `docs/`/agent config | repo-structure decision (audit) |
| Combat framed as a camera zoom into the encounter point, not a hard scene cut | Founding vision calls for an early-Final-Fantasy-style transition so the overworld reads as bigger than its grid; layers onto the existing SceneManager context-passing pattern rather than replacing it | 2026-07-05 / this session's founding prompt |
| World authored in this order: forest (Kokiri-Forest mood) -> castle city -> mountains -> rivers -> surrounding wilderness | Founding vision's explicit world-progression arc; ties a creative goal to the concrete post-MVP content milestones | 2026-07-05 / this session's founding prompt |
| Equipment (weapon variety) and elemental/magic systems are the highest-priority Stretch Goals after MVP | Founding vision emphasizes magic and weapon variety; the plan already licensed building these "once the base loop is fun" - this reprioritizes within the existing Stretch sequencing rather than reopening MVP scope | 2026-07-05 / this session's founding prompt (Stretch sequencing; see `TASKBOARD.md` Deferred) |
~~No separate integration branch; branch-per-milestone -> PR directly into `main`~~ - **superseded 2026-07-05 (second session), see the `integration` staging-branch row below** | Solo hobby project - matches how Kayden's other personal-scale projects (e.g. DigitalTome) actually run day to day; the workbench's own 3-tier convention is calibrated for the shared harness repo, not every downstream product | 2026-07-05 / this Adoption run |
| `integration` branch as staging before `main` - work accumulates on `integration`; Kayden explicitly syncs `integration` -> `main` when ready, rather than every task PRing straight to `main` | Kayden's call once the first-playable slice was working and felt worth protecting - gives a reviewable, shippable line separate from in-progress work, at the cost of one extra branch for a solo project | 2026-07-05 (second session) / this session |
| Concrete first-playable scenario: forest test area, grid-snapped walk, talk to one NPC, touch a visible enemy, win a simple turn-based battle, return to the same forest position, get a key/reward, open a blocked path | Kayden gave this as the smallest testable slice to build toward - smaller than the full Phase 6 finish line (no boss/save/party depth required), useful as an early integration smoke test once combat exists (see TASKBOARD.md T-013, deferred) | 2026-07-05 / this session |
| GBA-fantasy-adventure visual language: bright, readable, toy-like overworlds with chunky silhouettes, dense environmental texture, clean top-down camera; tiles built from 8x8/16x16 units | Kayden's explicit visual-reference table (GBA-era fantasy-adventure art direction as the touchstone, not any one licensed title); narrows rather than contradicts the flexible-HD/ultrawide rendering decision above - the canvas renders natively at 1280x720+, the art itself is built from small GBA-style tile units | 2026-07-05 / this session, see Visual Language section |
| General moment-to-moment loop confirmed as explore -> interact with an object/NPC/enemy -> take an action -> see the consequence -> continue exploring | Kayden's explicit framing for what "first playable" should feel like at every scale; confirms rather than changes the existing concrete first-playable scenario (row above) | 2026-07-05 / this session |
| Combat is grid-based (units occupy cells, check move/attack range, can move each turn); turn order is strict per-character initiative (speed), never a whole-team phase | Kayden's explicit combat-loop framing: check ranges -> move -> attack phase -> results, repeated per unit in initiative order, not team-by-team; the `TurnManager` design already sorted all combatants together by speed - only the Battle FSM's stale `PlayerPhase`/`EnemyPhase` state names implied team-phasing, and those are retired | 2026-07-05 / this session |
| Combat resolution uses a d10 percentage system (roll 1-10 against a stat-derived success threshold) instead of flat deterministic damage-only math | Kayden's explicit request for a system where success chances read as clean percentages; exact threshold/damage formula is a Phase 3/4 combat-math implementation decision (red/green/refactor per `AGENTS.md`), not decided here | 2026-07-05 / this session |
| Movement-state roadmap locked: (1) walk/face/act lock-in, (2) door transitions/ledges/stairs, (3) push/pull, (4) dash/roll, (5) swim - rows 1-3 MVP, rows 4-5 Deferred (S-009/S-010) | Kayden's explicit priority table; sequences movement investment by feel-impact and keeps dash/swim from being built early | 2026-07-06 / this session, see Movement-State Roadmap |
| Grid movement must *feel* continuous (Zelda/Pokemon bar): held steps chain with no hitch, tap turns-in-place before stepping, no "clicking into place" read - the grid-snap invariant itself is unchanged | Kayden: "In zelda and pokemon games I am locked into a grid but it never feels like I am clicking into place" - a feel requirement layered on the locked invariant, not a relitigation of it | 2026-07-06 / this session (T-021) |
| Jump added to MVP: contextual grid-snapped hop at ledge/pit edges, max exactly 1 cell, Tween-arc implementation (never physics) | Kayden: "not whenever but like when there are ledges and pits I want to be able to jump over them with my party"; the 1-cell limit is load-bearing for Room 2 of the tutorial dungeon (the pit is exactly at the jump limit) | 2026-07-06 / this session |
| PressurePlate is momentary (pressed by player *or* block, releases on vacate; plate-driven doors re-lock on release); a block pushed into a pit fills it permanently; pits block walking but aren't lethal at MVP | Kayden's explicit plate spec ("unlocks the doors, but locks again if we step off"); block-fills-pit and non-lethal pits are the smallest classic-Zelda reading of his Room 2 spec - flag if fall-in damage is ever wanted | 2026-07-06 / this session |
| Phase 2's deliverable is the 3-room tutorial dungeon behind the boss door (hub room with block+plate puzzle and a visible locked chest -> 2-wide-pit room -> key-drop fight room -> loop back, open chest, shield reward) | Kayden's room-by-room spec; gives Phase 2's puzzle primitives a concrete, testable integration target instead of abstract test rooms - "a good tutorial, and a good place to call phase 2" | 2026-07-06 / this session, see Phase 2 Target: Tutorial Dungeon; layout revised same day (round 2 rows below) |
| Tutorial chest is visible in the hub room from the start, not ceiling-dropped on puzzle solve; Room 1 is a hub connected to two other rooms so the reward loop reads spatially | Kayden: "I think if you're confused the players will be too. Zelda fixes this by adding another room" - replaces the surprise-trigger chest with legible dungeon structure | 2026-07-06 round 2 / this session |
| Tutorial pit widened to 2 cells: jump alone can't cross it; intended solve is block-into-pit (fills 1 cell) then jump the remaining 1-cell gap from the filled cell | Kayden: with block-fills-pit in play, "we need to make the pit 2 wide so they can't jump across it and have to push the block into it"; the block-then-jump crossing is the smallest mechanical reading that still teaches the jump - **flagged as agent interpretation, confirm in windowed play** (alternatives: two blocks, or a walk-across bridge reading) | 2026-07-06 round 2 / this session |
| Death/respawn: party defeat outside the dungeon respawns at the old man (healer NPC); defeat inside respawns in Room 1 with dungeon puzzle state fully reset ("you have to redo it all"). Pits stay non-lethal/impassable | Kayden's explicit respawn spec - death is a setback, not a game-over dead end; chest-key retention across death is TBD at T-029 | 2026-07-06 round 2 / this session |
| Enemy aggro telegraph (oozes get visibly angry + faster when they spot you, replacing ambiguous wander-to-chase) is a real task, deferred until sprites exist | Kayden's clarification of "attack lock-in" from the movement table - it's an *enemy* feel feature, not player movement; parked as T-028 until T-003 art gives it something to show | 2026-07-06 round 2 / this session |
| Shield is a plain inventory item at Phase 2 (D-001 resolved) | Kayden: "We are building the skeleton so we can just continue to ask the questions like 'Well, what does the shield do'" - effect decided at Phase 3/S-001. **Answered 2026-07-07 (D-007): the shield unlocks the Defend command** - see the Phase 3 rows below | 2026-07-06 round 2 / this session |
| Levels authored **all-in as LDtk entities** (not a code/LDtk hybrid): blocks, plates, doors, chests, NPCs, enemies placed as LDtk entity instances with custom fields (link IDs, key names), instantiated by a post-import hook | Kayden picked all-in but conditioned it on documentation; confirmed the importer's entity path is the well-documented one - `post-import/entity-template.gd` + a complete `entity-spawn-lights.gd` example (match `entity.identifier`, read `entity.fields`, instantiate a scene, `update_instance_reference`) + `docs/classes.md` for `LDTKEntity` | 2026-07-06 round 3 / this session |
| Jump is a **player-pressed button** (Alt primary, C fallback), not automatic/contextual | Kayden: "I don't want to trust that my character will jump the right way"; adds a `jump` input action (the map's first addition beyond the original 8). Note: Alt is an OS modifier on macOS - C is the safety binding if Alt reads poorly | 2026-07-06 round 3 / this session, supersedes the round-2 "contextual hop" wording |
| Phase 2 death = restart from the beginning of the game; the richer old-man/room-reset respawn moves to Phase 3 | Kayden: "I agree this is starting to be phase 3" - the dungeon-puzzle-state reset a mid-dungeon respawn needs is the same serialization `SaveData` provides, so it belongs with save/load, not Phase 2 | 2026-07-06 round 3 / this session, supersedes the round-2 respawn row |
| Overworld is a **single party avatar** (no snake-follow); the party's characters appear only in **Fire-Emblem-Sacred-Stones-style tactical combat** (select a character, WASD picks its destination cell, mini action menu below) | Kayden: "I kinda imagined one character in this overworld being your party... These are party encounters, not character encounters"; concentrates positioning depth in the tactical battles and keeps the overworld simple - **supersedes the snake-follow-formation decision** (retired Gameplan §10) | 2026-07-06 round 3 / this session |
| Puzzle geometry primitive: plate at the center of a 3x3 pushing space, block in a corner, 2-cell walking margin around it (the margin enables the around-the-block L-shaped push, since pushing needs the opposite side and there are no diagonals) | Kayden's sketch-in-words for Room 1; exact cells/push-count finalized at build against his drawing | 2026-07-06 round 3 / this session |
| Placeholder art through Phase 2, one art pass afterward; invest in dev tools (room warp, puzzle reset, grant item, skip combat) as early as possible instead | Kayden: "Lets do art at the end, but build out some dev tools like your suggesting as soon as we can" - Phase 2 validates mechanics, and puzzle iteration is playtest-heavy, so tooling pays back faster than art now | 2026-07-06 round 3 / this session |
| Tutorial-dungeon build interpretations (T-027, **agent interpretation - confirm in windowed play**): (a) the hub gets a reset **Lever** as the soft-lock escape valve; (b) blocks can never be pushed onto doorway cells or their approach cells; (c) opening the chest is the dungeon's completion beat - it unbolts the locked entry door; (d) the hub's west door is one-way (opens permanently when the player loops back through it from Room 3); (e) the Room 3 key-carrier is a new `dungeon_slime.tres` (10 HP / atk 3, `unique_id key_guardian` so it stays dead); (f) hub -> pit -> fight rooms suspend on the way in and are freed/rebuilt when backed out of, with chest/door/unique-enemy state persisted in `SceneManager.flags` | Fills the gaps Kayden's room spec left open, biased toward classic-Zelda readings and the Known Risks soft-lock mitigation; none of it touches a locked decision. Flag anything that plays wrong and it can be re-cut cheaply - rooms are LDtk data + thin room scripts | 2026-07-06 / this session (Phase 2 build) |
| **PressurePlate ON HOLD**; dungeon rescoped to four rooms: hub brick wall (13 bricks, one movable - Oracle-style, per Kayden's reference screenshot), new chest room behind a north **locked door** (`dungeon_key`; "I like having the door locked instead" of the chest), pit room gains two 1-wide jumpable ledges before the 2-wide chasm, fight room's guardian drops `dungeon_key` | Kayden's first windowed playthrough (T-032): the plate's momentary re-lock read as broken, so it's shelved rather than debugged mid-tutorial; the brick wall is wedge-proof by construction and keeps Room 1 focused on pushing | 2026-07-07 / playtest-feedback rework |
| Forest fixes from the same playthrough: every Wall cell now draws its tree tile (colliders were rendering as plain grass - the "random places I run into" bug), stray pit under the spawn cell removed, extra tree clusters added in the open stretch between spawn and the dungeon entry | Kayden: "I would like for there to be more things out in the open between me and the entry like there was. Maybe not a maze, but at least trees or something" | 2026-07-07 / playtest-feedback rework |
| **Phase 3 round (D-006..D-011, all resolved)**: (a) saves are **JSON** at `user://saves/slot_N.json` - Kayden delegated the pick; agent chose JSON per the retired Gameplan's own MVP JSON recommendation plus the `.tres`-from-`user://` script-execution risk; (b) **the shield unlocks Defend** - the command is absent from the combat menu until the shield is in inventory (D-001's answer); (c) **checkpoint respawns + XP-as-punishment** - keep inventory, lose XP never-below-level, dungeon-entrance/healer respawn, and walking into pits = Zelda fall back to the room's last-used entrance (supersedes pits-impassable); (d) **enemies respawn every time a room is left-and-rebuilt**, uniques included - the puzzle escape valve applies to enemies too (supersedes the Lufia-II stay-dead pattern; `defeated_enemy_ids` dropped from SaveData); (e) EncounterData/MapMeta built now as stubs, wired Phase 4; (f) minimal Continue/New Game boot prompt; dev warps expand to every built room via the map registry | Kayden's 2026-07-07 planning answers, verbatim rationale on the TASKBOARD Pending Decisions table; agent interpretations flagged there (full-HP respawn, suspended-room semantics, fall damage + XP penalty amounts as tunables) | 2026-07-07 / Phase 3 planning round |
| **Phase 4 (Combat MVP) starts ahead of Phase 3's save/load half**; Phase 3's M3.1 data classes move with it as combat prerequisites, and the M3.2/M3.3 save/load work stays planned and ready, resumed after combat | Kayden accepted Phase 2 in windowed play (2026-07-08) and named combat the priority: "my main complaint right now is combat, which is phase 4. So I think that is a good next place to work." A build-order re-sequencing, not a scope change - the D-006..D-011 save/load resolutions all stand; combat has no dependency on saves, but does need the M3.1 data classes (abilities, items, encounters, XP shape), which is why they ride along | 2026-07-08 / this session |
| **Phase 4 round (D-012/D-013, resolved 2026-07-08)**: (a) the battle arena is **seeded from the local overworld terrain** around the contact point - the combat grid copies the room's blocked/pit cells in a window where the encounter began, with an open-field fallback if too cramped; (b) Phase 4 ships with a **temporary test companion** in the party so multi-unit selection and interleaved initiative are real before Phase 5 recruitment replaces it | Kayden's picks ("use the local terrain where you were touched", "give me a test companion for now") - the local-terrain read matches the zoom-in framing (the world reads bigger because you fight *in* it); the companion proves the party machinery the whole phase exists to build | 2026-07-08 / this session |
| **Combat is a tactics-RPG, not a JRPG**: BG3's turn-based mode is the functional model (select a unit, move it within a highlighted range on a zoomed-in grid, act via abilities, strict per-unit initiative); Fire Emblem is the *visual* reference only (range highlighting, a dedicated battle mode). Active party size is **four**. The "quick decisions matter more than tactical depth" pillar is retired - the game leans into strategic, tactical combat | Kayden clarified the founding combat vision: "top down tactical BG3 style... control my party of 4 people around this new mini map." Fire Emblem was his closest GBA touchstone for the *look* (range highlights, separate mode), not the mechanics; the engine isn't as limited as first assumed, so depth is now in-scope. Reframes the JRPG/menu language and the earlier readable-over-deep pillar; the locked grid/d10/per-unit-initiative decisions are unchanged | 2026-07-08 / this session |

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
