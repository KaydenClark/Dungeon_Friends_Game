# Dungeon Friends — Gameplan

Status: Draft v2, 2026-06-11 — all 5 open decisions from the audit resolved (see audit §8)
**Revision, 2026-07-05:** §3.2's fixed 240x160 base resolution has been superseded — see §3.2 and BLUEPRINT.md → Design Decisions. The rest of this document (loop, architecture, data model, combat, milestones) is unaffected; only the rendering/resolution decision changed.
**Revision, 2026-07-05 (2):** Combat is now confirmed grid-based with per-unit movement/range, strict per-character initiative order (§7's `TurnManager` already sorted all combatants by speed — only this document's §7 `PlayerPhase → EnemyPhase` Battle-FSM state names implied team-phasing, and that reading is retired), and a d10 percentage resolution system in place of flat deterministic damage math. Visual language is narrowed to a GBA-fantasy-adventure look built from 8x8/16x16 tile units. See BLUEPRINT.md → Visual Language, → Current Product Shape, and → Core Logic And Invariants for the current detail — this document's §2/§7 prose itself is not yet rewritten to match.
Companion document: `docs/research/audited_research.md` (read that first — this plan builds on its conclusions)
Engine target: Godot 4.6.x (GDScript), Mobile renderer
Platforms: macOS, Windows, Android (desktop-first development)
Base resolution: flexible HD/ultrawide (1280x720 design reference, scaling cleanly to 1920x1080 and 3440x1440), nearest-neighbor filtering, unrestricted palette — see §3.2

---

## 1. Game Vision

A retro-pixel-art-*inspired* (not any specific handheld-accurate) 2D top-down adventure RPG. The player explores a grid-based overworld and dungeons in the structural tradition of classic Zelda games — block-pushing, switches, locked doors, key items that unlock new areas — while recruiting party members ("Dungeon Friends") who fight alongside them in turn-based combat encounters.

Tone: readable, chunky, retro-pixel, rendered natively at flexible HD/ultrawide resolutions rather than a fixed low-res canvas — richer color and more screen real estate than a literal handheld console, but still grid-based and tile-based. Not a hardware recreation — a *modern* small game wearing retro clothes. "Retro" describes the silhouette (chunky pixel sprites, grid movement, tile-based dungeons), not a literal emulation target, a forced color-count limit, or a locked low resolution.

Design pillars (in priority order):
1. **Movement and puzzles must feel precise.** Every action snaps to the grid. No floaty physics.
2. **Combat must be simple to implement and easy to balance.** A small, well-understood turn-based system beats a large, half-finished tactical one.
3. **Party collection should feel rewarding without becoming a second game.** A handful of well-characterized party members beats dozens of shallow ones.
4. **Scope discipline beats feature breadth.** Every system below is written with an MVP version and explicit stretch-goal extensions — build the MVP version first, always.

---

## 2. Core Gameplay Loop

```
Overworld/Dungeon (grid movement)
   |
   |-- Solve spatial puzzle (push block, hit switch, unlock door)
   |-- Find item / party member / key
   |-- Encounter enemy (visible on map, not random)
   |
   v
Combat (turn-based, party vs enemy group)
   |-- Win: return to overworld at pre-combat position, gain rewards
   |-- Lose: return to last save/checkpoint
   |
   v
Back to Overworld/Dungeon -- repeat, progress toward dungeon goal
   |
   v
Dungeon Boss (combat) -> new ability/party member -> unlocks new overworld area
```

This loop is intentionally close to classic Zelda (overworld → dungeon → item/ability → new area) with the JRPG combat layer added at the "enemy encounter" step. Per the audit, enemies are **visible on the map and trigger combat on contact** — no random/invisible encounters (this is both simpler to implement and matches the Lufia II-style design Doc B references favorably).

---

## 3. Technical Architecture

### 3.1 High-level structure

A single persistent **Main** scene hosts a **SceneManager** node, which is the only Autoload. Everything else — Overworld, Dungeon, Combat, Menus — are scenes instantiated/freed by SceneManager. This matches the audit's "SceneManager Context Passing" recommendation (Doc A, confirmed sound architecture) over the "Autoload singleton holds everything" anti-pattern.

```
Main (persistent root)
└── SceneManager (the ONLY autoload/global)
    ├── CurrentMap (Overworld or Dungeon scene, instanced)
    ├── CombatLayer (Combat scene, instanced on encounter, freed after)
    ├── UILayer (HUD, menus, dialogue — CanvasLayer, always present)
    └── TransitionLayer (fade/slide overlay, CanvasLayer)
```

**Why only one Autoload:** the audit confirms Resource-based data (`.tres` files for character/enemy/item stats) decouples data from nodes. With Resources doing the data-decoupling job, SceneManager only needs to hold *transient* state (current map path, player spawn point, active party array reference, pending encounter data) — not become a junk drawer of global variables. `GameState` (party roster, inventory, flags, position) is itself a `Resource` held *by* SceneManager, which makes save/load trivial (see §12).

### 3.2 Rendering configuration (revised 2026-07-05 — supersedes the 2026-06-11 240x160 decision)

The original 240x160/GBA-locked canvas (below, kept for history) has been dropped in favor of flexible HD/ultrawide rendering. Kayden confirmed this switch explicitly; see BLUEPRINT.md → Design Decisions for the full rationale. The retro *sprite-art* direction (chunky pixel art, nearest-neighbor filtering, no anti-aliasing) is unchanged — only the fixed low-resolution canvas is gone.

- Project Settings → Rendering → Renderer: **Mobile**
- Default Texture Filter: **Nearest** (unchanged — this is what keeps sprites crisp/retro at any resolution)
- Stretch Mode: **canvas_items** (renders UI/2D content at the display's native resolution, using the base resolution below as a design-time reference — not a tiny internal framebuffer scaled up)
- Stretch Aspect: **expand** (wider displays show more world horizontally instead of pillarboxing — this is what makes 3440x1440 ultrawide work cleanly)
- Stretch Scale Mode: **fractional** (smooth scaling across arbitrary resolutions; `integer` no longer applies now that the base canvas isn't a tiny fixed grid)
- Base resolution (design reference, not a hard limit): **1280x720** (16:9). Target display cases to validate against: **1280x720**, **1920x1080**, and **3440x1440** (21:9 ultrawide) — see the T-007 display-scaling spike scene (`game/scenes/dev/display_scaling_spike.tscn`) and RUNBOOK.md for how to check each one.
- Palette: **unrestricted**. No forced 4-color palette and **no global `SCREEN_TEXTURE` palette-swap shader in MVP** — this was the source of the Compatibility-renderer bug risk (audit §4.1), and it's no longer needed once the palette isn't artificially constrained. Author sprites/tiles with whatever colors look good. A CRT/scanline-style cosmetic shader remains a possible Stretch Goal (see §17), tested per-platform with a settings toggle.
- Tile grid unit: **TBD when M1.1 art lands** — 16x16 (the old GBA-locked default) would read as tiny at a 1280x720+ canvas; the T-007 spike uses 64px placeholder tiles as a reasonable starting ratio, but the real grid size is an art decision for M1.1, not a rendering-settings one.

<details>
<summary>Superseded 2026-06-11 decision (kept for history — do not follow)</summary>

- Stretch Mode: viewport, Aspect: keep (revisit `expand` only if 240x160 pillarboxes badly on common phone aspect ratios)
- Stretch Scale Mode: integer
- Base resolution: 240x160 (GBA-native, 3:2 aspect ratio). Resolved in favor of "GBA-like, not GBC-like" — 240x160 gives more screen real estate than 160x144 while staying low-res and grid-friendly (240 = 15 × 16px tiles, 160 = 10 × 16px tiles).

</details>

### 3.3 Core engineering patterns (all confirmed sound in the audit)

- **Grid movement:** no `velocity`-based `CharacterBody2D` movement. Compute target cell, raycast/tile-check, `Tween` to interpolate position over ~0.12-0.2s. Entities always rest exactly on grid.
- **Pathfinding:** `AStarGrid2D` with `diagonal_mode = DIAGONAL_MODE_NEVER` and Manhattan heuristic for any NPC/enemy that needs to path toward the player.
- **Combat:** two-layer FSM (Battle FSM + per-Entity FSM) + a `TurnManager` that sorts combatants by Speed and steps through them.
- **Data:** all stats/items/abilities are `Resource` (`.tres`) subclasses (`CharacterStats`, `EnemyStats`, `ItemData`, `AbilityData`). Visual nodes load `.tres` references; never hardcode numbers in scene scripts.
- **Room transitions:** `Area2D` boundary triggers + global `Camera2D` with `Tween`-driven pans, matching the audit's confirmed Zelda-style transition pattern.

---

## 4. Repo Structure Proposal

Resolved (decision #5, 2026-06-11): Godot project lives entirely under `/game`; everything else useful for AI-agent collaboration (planning docs, agent instructions, conventions) lives at repo root, so as much of the project as is reasonably safe is visible on GitHub.

```
Dungeon_Friends_Game/
├── README.md
├── CLAUDE.md                    # Claude-specific entry point (points at AGENTS.md + Gameplan)
├── AGENTS.md                    # canonical agent instructions: stack, conventions, where things live
├── .gitignore                  # Godot-specific (.godot/, exports, keystores/secrets — see note below)
├── docs/
│   ├── README.md                # index (this commit adds it)
│   ├── research/
│   │   └── audited_research.md
│   └── planning/
│       └── Gameplan.md
└── game/                         # Godot project root (project.godot lives here)
    ├── project.godot
    ├── addons/
    │   └── ldtk-importer/        # heygleeson's LDtk importer
    ├── assets/
    │   ├── art/
    │   │   ├── sprites/          # characters, enemies, items
    │   │   ├── tilesets/         # tileset source images (exported from Aseprite/Pixelorama)
    │   │   └── ui/                # menu/HUD art
    │   ├── audio/
    │   │   ├── music/             # .ogg exports from Furnace
    │   │   └── sfx/
    │   └── levels/
    │       └── world.ldtk         # single LDtk project file (multi-level)
    ├── data/                       # .tres Resource files
    │   ├── characters/
    │   ├── enemies/
    │   ├── items/
    │   ├── abilities/
    │   └── encounters/
    ├── scenes/
    │   ├── main.tscn
    │   ├── overworld/
    │   ├── dungeons/
    │   ├── combat/
    │   ├── entities/              # player, party member, enemy base scenes
    │   └── ui/
    ├── scripts/
    │   ├── autoload/
    │   │   └── scene_manager.gd
    │   ├── data/                  # Resource class definitions (CharacterStats.gd, etc.)
    │   ├── combat/                # FSMs, TurnManager, commands
    │   ├── overworld/              # grid movement, pathfinding helpers
    │   ├── puzzles/                # pushable blocks, switches, etc.
    │   └── save/
    └── shaders/
        └── palette_swap.gdshader
```

Rationale: keeping the Godot project in a `game/` subfolder keeps `docs/`, `CLAUDE.md`, and `AGENTS.md` cleanly separate and avoids ever mixing documentation/agent-config with Godot's `.godot/` cache.

**What's safe to commit vs. not:** almost everything here is safe — source code, scenes, resources, art source files, docs, and agent config are all plain text or binary assets with no secrets. The two things that must NOT be committed are: (1) Android release **keystores** (`.jks`/`.keystore` files) and (2) `export_presets.cfg` if it ever has signing passwords pasted directly into it (Godot supports leaving these blank and entering them per-export instead — prefer that). `.gitignore` covers both; see CLAUDE.md/AGENTS.md for the convention once `game/` exists.

---

## 5. Godot Scene Structure Proposal

```
main.tscn
└── Main (Node)
    ├── SceneManager (Node, autoload script attached) -- not actually a separate scene, but logically the root controller
    ├── WorldContainer (Node2D)        -- current Overworld/Dungeon scene instanced here
    ├── CombatContainer (Node2D)       -- Combat scene instanced here on encounter
    ├── UILayer (CanvasLayer)
    │   ├── HUD (party HP/status)
    │   ├── DialogueBox
    │   ├── PauseMenu
    │   └── PartyMenu / Inventory
    └── TransitionLayer (CanvasLayer)
        └── FadeRect (ColorRect, for fades + room-transition slides)
```

### Overworld / Dungeon scene (instanced into WorldContainer)
```
Map (Node2D)  -- one per LDtk level, generated by importer
├── TileMapLayers (from LDtk import: Ground, Walls, Decoration, etc.)
├── CollisionLayer (generated by LDtk importer post-import script)
├── Entities (Node2D)
│   ├── Player (CharacterBody2D)
│   ├── PartyFollowers (CharacterBody2D x N, snake-follow the player)
│   ├── Enemies (Node2D, instances of EnemyOverworld.tscn)
│   ├── PushableBlocks (Node2D, instances of PushableBlock.tscn)
│   ├── Switches / PressurePlates
│   └── NPCs
├── RoomBoundaries (Area2D x N, for camera transitions)
└── CameraRig (Camera2D, decoupled from Player per audit's confirmed pattern)
```

### Combat scene (instanced into CombatContainer)
```
Combat (Node2D)
├── TurnManager (Node)
├── BattleFSM (Node)
├── PartyUnits (Node2D, instances of CombatUnit.tscn x party size)
├── EnemyUnits (Node2D, instances of CombatUnit.tscn x encounter size)
├── CombatUI (CanvasLayer)
│   ├── ActionMenu
│   ├── TurnOrderQueue
│   └── DamagePopups
└── ContextData (the injected Context Object: party refs + enemy team + return position)
```

### Reusable entity scenes
- `entities/CombatUnit.tscn` — generic; loads a `CharacterStats`/`EnemyStats` Resource, runs the Entity FSM (`AwaitingTurn`, `SelectingAction`, `ExecutingCommand`, `TakingDamage`, `Dead`).
- `entities/OverworldActor.tscn` — base for Player/PartyFollower/EnemyOverworld; handles grid-snapped movement + Tween.
- `entities/PushableBlock.tscn`, `entities/PressurePlate.tscn`, `entities/LockedDoor.tscn` — puzzle primitives, instantiated via LDtk entity markers + post-import scripts.

---

## 6. Data Model Proposal

All data lives as `Resource` subclasses (`.tres` files), per the audit's confirmed "Resource paradigm" recommendation. GDScript class definitions live in `scripts/data/`.

### CharacterStats (`extends Resource`)
```
class_name CharacterStats
@export var id: StringName
@export var display_name: String
@export var max_hp: int
@export var max_mp: int
@export var attack: int
@export var defense: int
@export var speed: int
@export var sprite_frames: SpriteFrames
@export var portrait: Texture2D
@export var starting_abilities: Array[AbilityData]
@export var ability_unlock_levels: Dictionary  # {level: AbilityData}
@export var traversal_ability: AbilityData      # e.g. "push", "pull", "freeze" -- Golden Sun-style overworld use (stretch)
```

### EnemyStats (`extends Resource`)
```
class_name EnemyStats
@export var id: StringName
@export var display_name: String
@export var max_hp: int
@export var attack: int
@export var defense: int
@export var speed: int
@export var abilities: Array[AbilityData]
@export var ai_behavior: AIBehaviorType  # enum: RANDOM_WALK, BIASED_TRACKING, PATTERN
@export var xp_reward: int
@export var loot_table: Array[ItemData]
@export var overworld_sprite_frames: SpriteFrames
@export var combat_sprite_frames: SpriteFrames
```

### ItemData (`extends Resource`)
```
class_name ItemData
@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var item_type: ItemType  # enum: KEY_ITEM, CONSUMABLE, EQUIPMENT
@export var equip_slot: EquipSlot  # enum: NONE, WEAPON, ARMOR, ACCESSORY (stretch)
@export var stat_modifiers: Dictionary  # e.g. {"attack": +3}
@export var on_use_ability: AbilityData  # for consumables
```

### AbilityData (`extends Resource`)
```
class_name AbilityData
@export var id: StringName
@export var display_name: String
@export var mp_cost: int
@export var target_type: TargetType  # enum: SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, SELF
@export var element: ElementType  # enum: NONE, FIRE, ICE, etc. (stretch -- elemental counters)
@export var power: int
@export var animation_id: StringName
@export var overworld_use: bool  # can this be used outside combat? (stretch -- traversal abilities)
```

### MapData / Level metadata
LDtk is the source of truth for tile layout, collision, and entity placement (via IntGrid + entity markers + post-import scripts). A small companion `.tres` per level (`MapMeta`) stores non-visual metadata:
```
class_name MapMeta
@export var ldtk_level_id: StringName
@export var display_name: String
@export var music_track: AudioStream
@export var encounter_table: Array[EncounterData]   # which enemies can spawn here
```

(No `default_palette` field — the global palette-swap shader was dropped from MVP, see §3.2. If a per-area cosmetic shader is added later as a Stretch Goal, add the field back then.)

### EncounterData (`extends Resource`)
```
class_name EncounterData
@export var id: StringName
@export var enemy_group: Array[EnemyStats]   # composition of this fight
@export var background_id: StringName        # which combat backdrop to use
```
Note: since enemies are visible on the map (not random), `EncounterData` is referenced by the overworld `EnemyOverworld` instance directly — there's no "random encounter table roll." The `encounter_table` on `MapMeta` is mainly useful for stretch-goal features (e.g., the roguelike postgame's randomized floors).

### SaveData (`extends Resource`)
```
class_name SaveData
@export var current_map: StringName
@export var player_position: Vector2i
@export var party_roster: Array[StringName]      # IDs into CharacterStats library
@export var party_levels: Dictionary             # {character_id: level}
@export var party_xp: Dictionary
@export var party_current_hp_mp: Dictionary
@export var inventory: Dictionary                 # {item_id: quantity}
@export var equipped_items: Dictionary            # (stretch)
@export var flags: Dictionary                     # {flag_name: bool/int} -- switches solved, doors opened, party members recruited, etc.
@export var defeated_enemy_ids: Array[StringName] # so visible overworld enemies don't respawn after being beaten (matches Lufia II pattern from audit)
```

---

## 7. Combat System Architecture

Per the audit (confirmed sound), combat uses **two FSM layers** plus a **TurnManager**:

**Battle FSM (global, one per combat instance):**
`Initialize → CalculateInitiative → PlayerPhase → EnemyPhase → ResolveTurn → (loop) → EncounterEnd`

**Entity FSM (one per combatant):**
`AwaitingTurn → SelectingAction → ExecutingCommand → TakingDamage/Healing → (back to AwaitingTurn or → Dead)`

**TurnManager:**
1. On `Initialize`, builds a flat array of all combatants (party + enemies), reads `speed` from each `CharacterStats`/`EnemyStats`, sorts descending.
2. Steps through the array: signals each entity's FSM to `SelectingAction`.
   - If the entity is player-controlled: open `ActionMenu` (Attack / Ability / Item / Defend / Swap), wait for player input.
   - If AI-controlled: run `ai_behavior` targeting logic (start simple — "always attack lowest-HP party member" — expand later).
3. Selected action becomes a **Command object** (`AttackCommand`, `AbilityCommand`, `ItemCommand`, `DefendCommand`, `SwapCommand`) — each computes its effect independently and emits signals for animation + the target's `TakingDamage`/`Healing` state.
4. On `turn_finished` signal, TurnManager advances to next combatant; at end of array, recompute order (handles speed buffs/deaths) and start next round.
5. `EncounterEnd` triggers when all enemies or all party members are defeated/incapacitated → results screen → SceneManager frees Combat scene, restores Overworld/Dungeon (per §3.1).

**MVP simplifications (deliberate, to control scope):**
- Action menu: **Attack, Ability (1-2 per character), Item, Defend** only. No equipment-driven move sets at MVP.
- AI: single behavior — "attack a random party member," upgraded to "attack lowest-HP" once basic loop works.
- No elemental counter-system at MVP (Doc B's Fire/Ice etc.) — `ElementType.NONE` for everything until Stretch Goal.
- No "perfect information" telegraphing UI at MVP (Doc B's Into the Breach-style preview) — straightforward "select action, then resolve" loop. Telegraphing is a strong stretch goal because it's mostly *additive UI*, not a rearchitecture.

---

## 8. Overworld and Dungeon Architecture

- **Single LDtk project (`world.ldtk`)** containing all levels (overworld regions + each dungeon), imported via `heygleeson/godot-ldtk-importer`.
- **IntGrid layers** define: `Wall` (collision), `Water`/`Pit` (hazards), `PuzzleTrigger` (switches/plates — read by post-import scripts to spawn `PressurePlate.tscn`).
- **Entity layers** in LDtk define: player spawn points, NPCs, enemy spawns (with `EnemyStats` reference + `EncounterData` reference as LDtk entity fields), pushable blocks, locked doors (with required key item field), room-transition triggers.
- **Room transitions:** each "room" is bounded by an `Area2D`. On player overlap, `CameraRig` receives the new room's bounds, `get_tree().paused = true`, `Tween` pans camera to new room center, unpause. (Confirmed-sound pattern from audit, Doc A §"Room Transition Paradigm.")
- **Dungeons vs overworld:** structurally identical (both are LDtk levels with the same IntGrid/entity vocabulary). The only difference is content: dungeons are denser with puzzles/locked doors/a boss room; overworld connects dungeon entrances and town/hub areas.
- **Enemy behavior on the map** (per audit's Lufia II-confirmed pattern): enemies move only when the player moves (synchronized turns), using one of three behaviors defined in `EnemyStats.ai_behavior`:
  - `RANDOM_WALK` — moves to a random adjacent open tile each player turn.
  - `BIASED_TRACKING` — uses `AStarGrid2D` (Manhattan heuristic, `DIAGONAL_MODE_NEVER`) toward the player with some randomness.
  - `PATTERN` — fixed movement pattern (e.g., back-and-forth patrol), useful for puzzle design (lure enemy onto a pressure plate).
- Touching an enemy (or an enemy touching the player) triggers combat via `EncounterData` referenced on that enemy instance. On victory, the enemy's ID is added to `SaveData.defeated_enemy_ids` and the overworld instance is removed/hidden permanently (no respawns within that save).

---

## 9. Puzzle System Architecture

Built entirely from a small set of reusable, LDtk-driven primitives (per audit's confirmed approach):

- **PushableBlock**: grid-aligned `CharacterBody2D` (or `StaticBody2D` + manual move). On player-push input toward it, raycast the next cell; if clear, `Tween`-slide both player and block one cell. If a `PressurePlate` occupies the destination cell, fire `plate_activated` signal.
- **PressurePlate**: `Area2D`, fires `plate_activated`/`plate_deactivated` signals when a `PushableBlock` (or party member, depending on puzzle) enters/exits. Wired in the editor (or via LDtk entity field referencing a target ID) to a `LockedDoor` or `Switch`.
- **Switch / Lever**: toggled by direct player interaction (interact button), fires a signal.
- **LockedDoor**: `StaticBody2D` with collision enabled by default; listens for its linked switch/plate/key-item signal and disables collision + plays an animation when unlocked. Key-item-locked doors check `SaveData.inventory` for a required `ItemData.id`.
- **Linking mechanism:** LDtk entity custom fields carry string IDs (e.g., `plate_01` → `door_01`). The post-import script wires these into Godot signal connections at scene-build time, OR (simpler for MVP) a small `PuzzleController` node per room reads the IDs at `_ready()` and connects signals via `Callable`. **Recommendation: start with the per-room `PuzzleController` script** — it's easier to debug than auto-wired signals and is a reasonable MVP-first choice; migrate to fully automatic wiring only if you find yourself writing the same controller repeatedly.
- **Traversal abilities** (Golden Sun-style "Move/Freeze/Whirlwind", Doc B) are an explicit **Stretch Goal** (see §16) — they require party-ability-to-overworld-object interaction, which is a clean *addition* on top of the puzzle primitives above (an ability checks for a tagged object in front of the player and calls a method on it), not a rearchitecture. Don't build this for MVP.

---

## 10. Party/Team System Architecture

> **Revision note (2026-07-06):** the **overworld is a single party avatar** —
> the "snake formation" of `OverworldActor` followers described below is
> **superseded and will not be built**. The party's multiple characters appear
> only inside **Fire-Emblem-Sacred-Stones-style tactical combat** (select a
> character, WASD picks its destination cell). Roster/recruitment/reserve model
> below is unchanged. See `BLUEPRINT.md` → Party And Combat Model and the
> 2026-07-06 Design Decisions row.

- `SaveData.party_roster` is an ordered array of character IDs (max active party size — recommend **3** for MVP, a common small-party-JRPG size that keeps combat UI simple).
- A separate **reserve roster** (recruited but not active) is just "any character ID not in `party_roster`" — no separate data structure needed.
- **Recruitment**: an NPC/event in the overworld adds a character ID to the reserve roster (and `SaveData.flags`) when triggered. No combat/recruitment minigame at MVP — recruitment is a dialogue/cutscene event.
- **Party management UI** (Stretch beyond absolute MVP, but cheap): a menu screen listing all recruited characters, allowing the player to swap which 3 are active. Active party members' `OverworldActor` instances follow the player in a "snake" formation (each follower targets the previous unit's position-N-frames-ago — simple and well-documented Godot pattern).
- **Scope guardrail**: the audit flags Doc B's full vision (Djinn-style equip-and-unleash creatures that alter class, IP/Ikari gauges tied to gear, etc.) as multi-month stretch content. The MVP party system is: **recruit characters → pick 3 active → each has a fixed small ability set → level up via XP from combat**. Equipment, class-altering mechanics, and resource-gauge systems are Stretch Goals 2-3 (see §16), built as additive layers on `CharacterStats`/`AbilityData` once the base loop is fun.

---

## 11. Input Plan (Keyboard, Controller, Mobile Touch)

Use Godot's **Input Map** (Project Settings → Input Map) as the single source of truth — every gameplay action is a named action (`move_up`, `move_down`, `move_left`, `move_right`, `interact`, `cancel`, `menu`, `confirm`), bound to multiple physical inputs:

| Action | Keyboard | Controller | Touch (mobile) |
|---|---|---|---|
| `move_*` | Arrow keys / WASD | D-pad / left stick | Virtual D-pad (on-screen, `TouchScreenButton` mapped to input actions) |
| `interact` / `confirm` | Z / Enter | A button (Xbox) / Cross (PS) | On-screen "A" button |
| `cancel` / `back` | X / Escape | B button / Circle | On-screen "B" button |
| `menu` | Enter / Tab | Start / Options | On-screen menu icon |

**Implementation notes:**
- Godot's `TouchScreenButton` nodes map directly to Input Map actions — no separate "mobile input" code path needed. All gameplay code reads `Input.is_action_pressed("move_up")` etc. regardless of source.
- Touch UI lives on its own `CanvasLayer`, drawn with pixel-art buttons, and is **only visible/active when `OS.has_feature("mobile")` or the export is Android** — desktop builds simply don't show it.
- Controller support in Godot 4 is largely "free" once the Input Map is set up correctly (Godot auto-detects most standard gamepads). Test with at least one real controller (e.g., an Xbox or 8BitDo pad) during Milestone development, not just at the end.
- For touch, anchor the D-pad/buttons to screen corners using `Control` anchors so they adapt to different Android aspect ratios/notches, independent of the fixed low-res game viewport (this is the `SubViewport` + `canvas_items`-for-UI hybrid pattern the audit confirmed as a legitimate modern technique, Doc B).

---

## 12. Save/Load Plan

- `SaveData` (Resource, §6) is serialized via Godot's `ResourceSaver.save()` / `ResourceLoader.load()` to `user://saves/slot_N.tres`, OR via `FileAccess` + `JSON.stringify()`/`JSON.parse()` to `user://saves/slot_N.json` if you'd rather have human-readable saves for debugging (recommended for MVP — easier to inspect/hand-edit while testing).
- **Save points**: physical objects in the overworld/dungeons (e.g., a "save crystal" tile/entity). Touching one + confirming writes `SaveData` to the current slot. No mid-dungeon autosave at MVP (matches genre convention and avoids edge cases with saving mid-puzzle).
- **What gets saved**: current map ID + player grid position, party roster + levels/XP/HP/MP, inventory, `flags` dictionary (puzzle states, doors opened, NPCs recruited), `defeated_enemy_ids` (so cleared overworld enemies stay cleared).
- **What does NOT get saved mid-combat**: combat is never saved mid-fight — if the player quits during combat, on relaunch they resume from their last save point (standard, simple, avoids serializing FSM state).
- **Load flow**: `SceneManager` reads `SaveData`, instances the correct map scene, sets player position, restores `flags` (which puzzle objects read on `_ready()` to set their solved/unsolved visual state), restores party data into the in-memory `GameState`.
- **Multiple save slots**: trivial extension (just a different filename) — recommend supporting 3 slots from the start since it's near-zero extra cost.

---

## 13. Art and Audio Pipeline

### Art
1. Author sprites/tiles in **Aseprite** (resolved primary tool, decision #3 — see audit §8.1 for the pros/cons table), against the 1280x720 flexible HD/ultrawide design reference (§3.2, revised 2026-07-05), on a grid unit TBD at M1.1 (larger than the old 16x16 GBA-locked default — see §3.2), with no palette restriction.
2. Use Aseprite's **Lua scripting + CLI batch mode** (`aseprite -b script.lua`) to script repetitive asset-pipeline work — slicing sprite sheets, batch-exporting animation frames, regenerating exports after edits — so Claude/Codex can drive the art pipeline without manual GUI steps. Keep these scripts in `game/assets/art/_scripts/`.
3. Export tilesets as PNG sprite sheets, sized as exact multiples of the grid unit (per audit's confirmed best practice — prevents sub-pixel artifacting).
4. Import tilesets into **LDtk**, build levels there (IntGrid for collision/logic, AutoLayers for visual tiling).
5. Export `.ldtk` → import into Godot via `heygleeson/godot-ldtk-importer` → `TileMapLayer` nodes + entity scenes generated automatically.
6. Character/enemy sprite sheets import directly into Godot as `SpriteFrames` resources for `AnimatedSprite2D`.
7. Project Settings: Default Texture Filter = Nearest (locked in §3.2).
8. Pixelorama remains available as a free fallback for quick edits if Aseprite isn't on hand.

### Audio
1. Compose music/SFX in **Furnace Tracker** for a chiptune *sound* (resolved decision #4 — authenticity of *sound*, not of *engine architecture*).
2. Render/export tracks as `.ogg` (good compression, low CPU decode cost — confirmed sensible for Android per audit).
3. Import into Godot as `AudioStream` resources; play via `AudioStreamPlayer` (music) and `AudioStreamPlayer2D` (positional SFX, if any).
4. Audio manager: a single `MusicPlayer` node (owned by `SceneManager`) that crossfades between tracks on map change, plus a simple `SFXPlayer` pool for one-shot sounds. **This is the permanent design, not a placeholder** — the literal "4-channel hardware engine with channel-stealing" architecture from Doc B has been dropped entirely (decision #4), not deferred. Revisit only if a specific authenticity itch comes up later, and even then treat it as a low-priority "nice to have," not a planned item.

---

## 14. Build/Export Plan (macOS, Windows, Android)

Set this up **early** (Milestone 2-3), not at the end — confirming all three export targets work with a trivial scene avoids discovering platform-specific blockers late.

### macOS
- Export `.app` via Godot's macOS export preset.
- For local testing/sharing with friends: ad-hoc signing is sufficient.
- For any distribution beyond direct file-sharing (e.g., a website download): requires an Apple Developer ID ($99/year) + notarization via Godot's export dialog (Apple ID/app-specific password or App Store Connect API key). **Budget the $99/year decision explicitly** — it's not required to *develop and test* the game, only to distribute it without Gatekeeper warnings.

### Windows
- Export `.exe` directly from macOS — Godot 4.6 cross-compiles natively.
- **Do not** follow the Wine/rcedit instructions in Doc B — confirmed outdated as of Godot 4.5+. Icon embedding works out of the box.
- Code signing for Windows is optional for personal/shared builds; only relevant for Microsoft Store distribution (not in scope now).

### Android
- Install **OpenJDK 17** + **Android SDK** (Platform-Tools ≥35.0.0) + NDK on the Mac Mini (confirmed current requirement).
- Configure Godot Editor Settings → Export → Android with the SDK/JDK paths.
- Generate a debug build first (uses Godot's debug keystore automatically) to validate the export pipeline works end-to-end.
- For any release build: generate a release keystore via `keytool`, configure in the Android export preset.
- **Test on a real Android device early** (Milestone 2-3) — this is also when you validate the touch input layer (§11) and confirm Mobile renderer performance on real hardware (the `SCREEN_TEXTURE`/Compatibility-renderer concern from audit §4.1 no longer applies since the MVP doesn't use a global palette shader, §3.2).

---

## 15. Development Milestones (2-3 Hour Chunks)

Each milestone is sized for a single AI-assisted working session. Milestones are grouped into phases; phases build on each other.

### Phase 0 — Foundation (this audit's deliverables + project skeleton)
- **M0.1** (this work): Audit research docs, create branch, write Gameplan — *done by this commit*.
- **M0.2**: Create Godot 4.6 project in `game/`, set Mobile renderer, Nearest filtering, flexible HD/ultrawide stretch settings (§3.2, revised 2026-07-05). Commit empty project that runs and shows a colored background.
- **M0.3**: Set up export presets for macOS, Windows, Android (debug). Produce one trivial build per platform to confirm the pipeline works end-to-end. Test on real Android device if available.

### Phase 1 — Movement & World Skeleton

> **Revision note (2026-07-06):** M1.3 landed early via the walking skeleton
> (TASKBOARD T-010). Kayden added two Phase 1 requirements: movement *feel*
> polish to the Zelda/Pokemon grid-but-seamless bar (T-021), and a room
> transition through the boss-unlocked door (T-022, pulling M2.3's mechanism
> forward). See `BLUEPRINT.md` → Movement-State Roadmap and the 2026-07-06
> Design Decisions rows.

- **M1.1**: Draw a tiny test tileset (floor, wall, 1 character) in Aseprite against the flexible HD/ultrawide design reference, grid unit decided at this milestone (per revised §3.2 settings). Set up the Aseprite batch-export script (`game/assets/art/_scripts/`).
- **M1.2**: Build a minimal LDtk project (one small room) with a Wall IntGrid layer; install `heygleeson/godot-ldtk-importer`; import into Godot, confirm `TileMapLayer` + collision generate correctly.
- **M1.3**: Implement grid-snapped player movement (Tween-based, raycast-checked) per §3.3. Player can walk around the test room and collide with walls.
- **M1.4**: Confirm the flexible HD/ultrawide `canvas_items`/`expand` stretch settings look correct with the real M1.1 test tileset at 1280x720, 1920x1080, and 3440x1440 (the T-007 spike already validated this with placeholder tiles — this milestone re-validates with real art). No palette shader work needed here — that's been removed from MVP (§3.2).

### Phase 2 — Puzzle Primitives & Room Transitions

> **Revision note (2026-07-06):** Phase 2's deliverable is now a concrete
> 3-room **tutorial dungeon** behind the boss door (hub room: block+plate
> puzzle + a visible locked chest → 2-wide-pit room crossed by
> block-into-pit + a grid-snapped **jump** of the remaining cell → key-drop
> fight room, loop back, open chest, shield reward), replacing the abstract
> test rooms below as the integration target — the M2.x primitives underneath
> are unchanged, plus jump/pits and a death/respawn system (new to MVP).
> Full spec: `BLUEPRINT.md` → Phase 2 Target: Tutorial Dungeon; tasks:
> TASKBOARD T-023..T-027 + T-029.

- **M2.1**: Implement `PushableBlock` + `PressurePlate` + simple `PuzzleController` wiring (§9). Build one test puzzle room.
- **M2.2**: Implement `LockedDoor` + key-item check against `SaveData.inventory`.
- **M2.3**: Implement room-transition system (`Area2D` boundaries + `CameraRig` Tween pan, §8). Build a 2-3 room connected test area.
- **M2.4**: Build out `SceneManager` properly (§3.1): single autoload, holds `GameState`/`SaveData`, handles map loading and player spawn positioning.

### Phase 3 — Data Model & Save/Load
- **M3.1**: Define `CharacterStats`, `EnemyStats`, `ItemData`, `AbilityData`, `SaveData` Resource classes (§6). Create 1-2 sample `.tres` instances of each.
- **M3.2**: Implement save/load to `user://saves/` (§12) with one save point object in the test area. Verify a full save → quit → relaunch → load → correct position/flags cycle.
- **M3.3**: Implement `flags` dictionary usage: one puzzle's solved-state persists across save/load.

### Phase 4 — Combat MVP
- **M4.1**: Build the Combat scene skeleton (§5/§7): `TurnManager`, Battle FSM, Entity FSM, static test party (1-2 characters) vs static test enemy (1).
- **M4.2**: Implement turn ordering by Speed, `AttackCommand` (damage math from `attack`/`defense` stats), HP depletion, win/loss detection.
- **M4.3**: Build Combat UI: action menu (Attack/Item/Defend only at this stage), turn order display, HP bars, damage popups.
- **M4.4**: Implement `SceneManager` context-passing transition (§3.1/§7): touching a visible overworld enemy pauses the overworld, instances Combat with the right party/enemy data, and on victory/defeat returns cleanly to the exact overworld position.

### Phase 5 — Party System & Progression
- **M5.1**: ~~snake-following `PartyFollower` actors in the overworld~~ — **superseded 2026-07-06: overworld stays a single avatar** (see §10 revision note). M5.1 is instead the party-management menu (swap which characters are active); multi-character positioning lives in tactical combat (§7), not the overworld.
- **M5.2**: Add 1 ability per character (`AbilityCommand`), MP cost, and a simple AI behavior (`RANDOM_WALK` first, then `BIASED_TRACKING` via `AStarGrid2D`).
- **M5.3**: Implement XP/leveling: combat victory grants XP, level-up increases stats per a simple curve, persisted in `SaveData`.
- **M5.4**: Implement one recruitment event: an NPC/scene that adds a new character to the reserve roster + a basic party-management menu to swap active members.

### Phase 6 — First Playable Slice
- **M6.1-6.4**: Build one complete small dungeon (3-5 rooms, 1-2 puzzles, 2-3 enemy encounters, 1 key item, 1 boss) using everything from Phases 1-5. This is the **first playable build** — a vertical slice proving the full loop (§2) works start to finish.
- **M6.5**: Polish pass on this slice: music (Furnace tracks for overworld/dungeon/combat), SFX for attack/menu/footsteps, basic transition fades.

At this point you have a real MVP (see §16) and a much better-informed basis for sequencing Stretch Goals.

---

## 16. MVP Scope

The MVP is **everything in Phases 0-6 above**, summarized:

- One connected overworld area + one small dungeon (3-5 rooms) with a boss.
- Grid movement, 2-3 puzzle types (pushable block, pressure plate, locked door + key item).
- Visible overworld enemies with at least 2 AI behaviors (random walk, biased tracking), no random encounters.
- Turn-based combat: 3-character active party, 1-2 abilities each, Attack/Ability/Item/Defend, Speed-based turn order, win/loss handling.
- XP/leveling, 1 recruitable additional party member, basic party-swap menu.
- Save/load with multiple slots, persisted flags and defeated-enemy state.
- Keyboard + controller + Android touch input all working.
- Builds run on macOS, Windows, and Android.
- Retro pixel-art visuals rendered at flexible HD/ultrawide resolution (1280x720 design reference, `canvas_items`/`expand` scaling, unrestricted palette — revised 2026-07-05, see §3.2) and Furnace-composed music/SFX for this one dungeon.

**Explicitly NOT in MVP** (see Stretch Goals): equipment system, elemental counters, traversal/Psynergy-style abilities, Ikari/Djinn-style resource mechanics, telegraphed "perfect information" combat UI, roguelike postgame, multiple dungeons/full overworld, any global palette/CRT shader.

**Explicitly dropped, not just deferred**: the literal 4-channel hardware-emulation audio engine (channel-stealing for SFX) — see decision #4 in the audit, §8.

---

## 17. Stretch Goals (Sequenced)

Ordered roughly by "smallest addition for the value" — each builds additively on the MVP architecture without requiring rearchitecture, addressing the audit's concern that Doc B's full feature list was presented with no sequencing.

1. **Equipment system**: extend `ItemData` (`equip_slot`, `stat_modifiers` already in the data model) + an equipment menu. Pure UI + data work on top of existing `CharacterStats`.
2. **Elemental counter-system**: populate `AbilityData.element` and `EnemyStats` with elemental weaknesses; `AttackCommand`/`AbilityCommand` check element matchups for damage multipliers. Additive to the existing damage formula.
3. **Telegraphed combat UI** ("perfect information," Into the Breach-style, Doc B): show enemy intended target/action before the player commits. Mostly UI + an extra "decide enemy actions" sub-phase before `PlayerPhase` in the Battle FSM — doesn't change the FSM's shape, just adds a phase.
4. **Traversal/Psynergy-style abilities** (Golden Sun-inspired, Doc B): mark certain `AbilityData` as `overworld_use = true`; player can trigger them outside combat to interact with tagged overworld objects (push pillar, freeze water, clear debris). Builds on the puzzle primitives in §9.
5. **Ikari/Djinn-style resource mechanics** (Doc B): a secondary combat resource gauge tied to equipment or party-collection mechanics, enabling a powerful "unleash" action with a temporary stat penalty. This is the most architecturally involved stretch item — tackle only after 1-4 are stable.
6. **More dungeons + full overworld map**: pure content work using the established pipeline — each new dungeon is "more of Phase 6," not new systems.
7. **Cosmetic CRT/scanline/color-grading shader** (optional, replaces the dropped global palette-swap shader): a `CanvasLayer` + `ColorRect` + `ShaderMaterial` post-process for screen-space visual flavor. Test per-platform with a settings toggle to disable if it misbehaves on any device — this was the source of the original `SCREEN_TEXTURE`/Compatibility-renderer concern (audit §4.1), so treat it as purely optional polish, never load-bearing.
8. **Roguelike postgame** ("Ancient Cave," Doc B): randomized dungeon generator + stripped-stats mode. Large, separate system — only attempt once the core game is feature-complete and you want a long-tail replayability feature.

Note: the "literal 4-channel hardware audio engine" item from the original sequencing has been **removed** (decision #4, audit §8) — not deferred, dropped.

---

## 18. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Scope creep from Doc B's full feature list | High | High | This Gameplan's MVP/Stretch split (§16/§17) is the guardrail — revisit it before adding any new system, and resist adding stretch features mid-Phase. |
| Solo + AI-assisted dev underestimates UI work (menus, inventory, party management) | Medium | Medium | UI-heavy phases (4, 5) are scheduled with dedicated milestones rather than bundled into "just add combat" — UI is consistently the most underestimated part of RPGs. |
| Android export friction (SDK/JDK setup, device-specific quirks) | Medium | Medium | Address in Phase 0 (M0.3), not deferred to the end — surface problems while the codebase is still trivial. |
| LDtk importer (`heygleeson/godot-ldtk-importer`) is a community plugin — could have breaking changes on Godot updates | Low-Medium | Medium | Pin the Godot version per project (4.6.x) and the importer version; check the importer's GitHub issues before any Godot engine upgrade. |
| Ultrawide (21:9) or unusual aspect ratios show too much/too little world at the screen edges under `expand` | Low-Medium | Low | Validated by the T-007 display-scaling spike at 1280x720/1920x1080/3440x1440 before this change landed; re-validate in Milestone 1.4 with the real M1.1 test tileset. `expand` is the current default; `keep`+letterbox is the fallback if it reads poorly with real art. |
| "Authentic hardware constraint" scope creep (audit §5.3) — spending time on GB/GBA-accuracy that doesn't serve gameplay | Low (mostly resolved by dropping hardware-accuracy targets, decisions #1/#2/#4, and by dropping the fixed low-res canvas entirely on 2026-07-05) | Low | Any remaining literal-hardware ideas (e.g., the CRT shader, §17 #7) are optional cosmetic Stretch Goals only, never load-bearing. |
| Aseprite CLI/Lua automation has a learning curve before it pays off | Low | Low | Start with simple batch-export scripts in Milestone 1.1; expand only as repetitive tasks emerge. Pixelorama remains a no-cost manual fallback. |

---

## 19. Concrete Next Steps

1. All 5 open decisions from `audited_research.md` §8 are resolved (2026-06-11) — no remaining blockers to starting Phase 0.
2. Merge or review this branch (`research-audit-and-gameplan`) — see PR/branch info at the end of this work's summary.
3. Start **Phase 0** (M0.2/M0.3): create the Godot 4.6 project skeleton inside `game/`, configure rendering settings per §3.2 (flexible HD/ultrawide, Mobile renderer, `canvas_items`/`expand` scaling, no palette shader), and get a trivial build running on all three target platforms.
4. Once Phase 0 is green, proceed through Phases 1-6 in order — each milestone is sized to be a self-contained AI-assisted session with a clear "done" condition (stated in §15).
5. Set up `CLAUDE.md`/`AGENTS.md` conventions (repo root) before Phase 0 so Claude/Codex sessions start with consistent project context from the first commit.
