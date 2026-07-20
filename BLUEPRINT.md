# Dungeon Friends - Blueprint

> Generated from LLM Workbench v2.3. See `RUNBOOK.md` -> Upgrading The
> Harness.

**Last reviewed:** 2026-07-17
**Status:** active - **v2 vision pivot (controlled reboot), canon reset 2026-07-11.**
Docs now describe the v2 canon; the code on disk is still the v1 build. The
stable specs project the active migration sequence into `TASKBOARD.md`.
Superseded v1 decisions are recorded in Design Decisions (D-024..D-037), never
silently contradicted.
**Source root:** `/Users/kayden/GPT_OS/Projects/Dungeon_Friends_Game`

This is the stable reference for what the project is. This file is the
canonical design doc and the summary a future agent should read first; the
toolchain research behind its decisions is in [`docs/research/audited_research.md`](docs/research/audited_research.md).
Ongoing world/story details live in [`docs/WORLD_LORE.md`](docs/WORLD_LORE.md).
Shared product and Workbench terms live in [`LEXICON.md`](LEXICON.md).
(The former `docs/planning/Gameplan.md` was retired 2026-07-08 - its stable
content is absorbed here and in `RUNBOOK.md`; current execution lives in
`specs/`.)

## Capability Catalog

This generated catalog is the durable index. Load only the assigned spec during
normal execution.

<!-- spec-catalog:start -->
| Spec | Description | Status |
|---|---|---|
| [S-001 - Unified Party And Intent Foundation](specs/S-001-unified-party-intent-foundation/SPEC.md) | Prove same-room encounters, a visible formed party, deterministic intent rounds, and exact previews on the orthogonal grid. | complete |
| [S-002 - Shared Material Reaction Vocabulary](specs/S-002-shared-material-reaction-vocabulary/SPEC.md) | Prove one preview-first material and effect vocabulary across exploration and encounters, then pass the owner fun gate. | complete |
| [S-003 - Persistent World Resolution](specs/S-003-persistent-world-resolution/SPEC.md) | Persist resolved encounters and environmental changes across leave, save, quit, relaunch, and load without losing soft-lock recovery. | complete |
| [S-004 - V2 Thesis Slice](specs/S-004-thesis-slice/SPEC.md) | Build one authored recruit, non-combat resolution, shared-vocabulary puzzle, tactical fight, and persistent world change as a playable v2 loop. | planned |
| [S-005 - External Thesis Playtest](specs/S-005-external-playtest/SPEC.md) | Test the v2 thesis slice with at least two new players and convert observed confusion and fun into evidence-backed follow-up specs. | planned |
| [S-006 - Workbench v2.3 Upgrade](specs/S-006-workbench-v2-3-upgrade/SPEC.md) | Migrate Dungeon Friends from the v2.1 proof-heavy board to the v2.3 stable-spec lifecycle without losing project truth or verification. | complete |
| [S-007 - Canon-To-Spec Conversion](specs/S-007-canon-to-spec-conversion/SPEC.md) | Reconcile the settled unified-world canon, live source, legacy queue, owner gates, and release proof into complete stable capability specs. | complete |
| [S-008 - Reaction Gate Readability](specs/S-008-reaction-gate-readability/SPEC.md) | Make the reaction-room payoff legible and prove the recut with repeatable two-resolution tours. | complete |
| [S-009 - Unified World Runtime](specs/S-009-unified-world-runtime/SPEC.md) | Replace the split production world/battle spine with one neutral room-state and party/encounter lifecycle without deleting the green v1 fallback early. | complete |
| [S-010 - Production Party Formations](specs/S-010-production-party-formations/SPEC.md) | Graduate line, square, and spaced party formations into production exploration, leader switching, save state, and legal encounter deployment. | active |
| [S-011 - Production Reaction Vocabulary](specs/S-011-production-reaction-vocabulary/SPEC.md) | Graduate the accepted preview-first material/effect engine into production world cells, authored data, friend verbs, and encounter callers. | active |
| [S-012 - Production Deterministic Combat](specs/S-012-production-deterministic-combat/SPEC.md) | Replace v1 d10 arena combat with production same-room intent rounds, exact previews, four-unit any-order actions, and environmental resolution. | active |
| [S-013 - Finite Progression And Recruitment](specs/S-013-finite-progression-and-recruitment/SPEC.md) | Define and implement finite no-grind progression, defeat/revive rules, one real recruit, equipment/economy seams, and the character surface. | planned |
| [S-014 - Opening Player Experience](specs/S-014-opening-player-experience/SPEC.md) | Make the opening unified-world journey readable, controllable, recoverable, controller-complete, and understandable without coaching. | planned |
| [S-015 - Steam Release Proof](specs/S-015-steam-release-proof/SPEC.md) | Produce a reproducible, license-safe, controller-checked Steam-first release candidate and owner approval without authorizing publication. | planned |
<!-- spec-catalog:end -->

## What This Project Is

> **Controlled reboot (2026-07-11, D-024).** Kayden's research pass (Horizon's
> Gate, Into the Breach, and the deterministic-tactics lineage) replaced the
> original "Zelda meets BG3" split-mode design. The organizing principle is
> now: **one persistent world, one shared environmental vocabulary, a visible
> party of Dungeon Friends, and encounters that permanently resolve problems.**

The pitch:

> A party-based 2D adventure RPG where the goddess Selena sends you to recruit
> Dungeon Friends and prepare an expedition against the dragon looming over
> the city. Explore a three-quarter-view world, combine your friends'
> abilities to manipulate its terrain, and resolve deterministic tactical
> encounters directly where they begin.

The core loop:

1. **Adventure:** explore, discover routes, meet people, identify problems.
2. **Party progression:** recruit friends, choose an active team of four,
   improve their abilities.
3. **Encounters:** resolve combat, environmental problems, deliveries, and
   NPC requests.
4. **World change:** the resolved problem stays resolved and opens a new
   route, relationship, or resource.

Step 4 is essential: combat accomplishes something - it is never only XP.

What fundamentally changed at the pivot (quick reference for agents; each row
has a superseding decision in Design Decisions):

| v1 direction | v2 direction |
|---|---|
| Single overworld avatar | Entire active party visible (D-029) |
| Separate combat scene and arena | Combat happens in the current room (D-025) |
| Top-down presentation | Orthogonal grid rendered in three-quarter perspective with integer elevation (D-030) |
| d10 hit rolls | Deterministic damage and effects (D-026) |
| Enemies respawn on room rebuild | Resolved encounters stay resolved (D-028) |
| Enemy action chosen on its turn | Enemy intentions telegraphed beforehand (D-027) |
| Combat abilities separate from puzzles | One shared material/effect vocabulary everywhere (D-031) |
| Personal/friends-and-family audience | Steam-first commercial project (D-032) |
| Android as an early platform | Mobile reconsidered after the PC game proves itself (D-032) |

Visually it's retro-pixel-art *inspired*, not any specific handheld-accurate:
a flexible HD/ultrawide base resolution (1280x720 design reference, scaling
cleanly up through 1920x1080 and 3440x1440), nearest-neighbor filtering,
unrestricted palette. The world is an **orthogonal square logic grid rendered
in three-quarter perspective** (vertical wall faces, stronger ground-plane
depth, small integer cell elevation with ramps/stairs) - not true
diamond-isometric rendering (D-030). See Visual Language below.

On the D&D question: the D&D *shape* (roles, abilities, a small stat block,
party builds) remains the target; this is **not** a literal D&D
implementation - no 5e rules-as-written or SRD/OGL content. Combat resolution
is fully deterministic (see Deterministic Combat Contract below), not dice.

Core promise:

> Walk a hand-built three-quarter-view world with your whole party visible,
> combine your friends' verbs to reshape the terrain - the same verbs inside
> and outside combat - get pulled into a deterministic, telegraphed tactical
> encounter right where you stand, resolve it permanently, and watch the world
> open in response, all the way up the mountain to the dragon.

Primary users:

- Steam players on PC (keyboard and controller) - the commercial audience
  this project now targets (D-032).
- Kayden - designer, solo developer, and first tester.
- External playtesters before roster/world scale-up (pivot step T-095).
- A future AI agent (Claude, Codex, or other) picking this repo up cold.

Mobile (Google Play) is postponed until the PC interface and market fit are
proven - postponed, not abandoned; keep the Android export knowledge.

## Design Pillars

The five v2 product pillars, in priority order (revised 2026-07-11 at the
pivot, D-024 - these supersede the 2026-07-08 pillar set; "Adventure First"
and the compact-authored-world idea survive, the separate-battle-mode pillar
does not):

1. **One Grid, One Vocabulary.** Exploration, puzzles, and combat share the
   same environment, rules, and material/effect system. A verb that burns a
   vine in exploration burns it in combat; there is no separate battlefield
   and no separate ruleset. This is the pivot's load-bearing pillar - the
   riskiest assumption lives here, and the pivot sequence prototypes it first.
2. **Adventure First.** The player should always feel like they are on a clear
   fantasy adventure: walk the world, find secrets, enter dungeons, solve
   problems, open new paths. Regions are dense, authored, and interconnected -
   hand-built, never procedurally generated.
3. **Party of Dungeon Friends.** The whole active party is visible in the
   world. Each friend changes how the player fights, explores, and solves
   problems through their world verb and combat kit. Choosing four from a
   roster of approximately 10-12 excellent friends is the collection fantasy -
   discovery and anticipation, not hundreds of characters.
4. **Deterministic, Telegraphed Tactics.** The preview and the result always
   agree. Enemies declare their intentions before they act; the player's
   answer is positioning, verbs, and combinations - never dice. Readability
   (small parties, clear stats, visible outcomes, a legible board) remains the
   constraint that keeps depth honest.
5. **Encounters Resolve The World.** A resolved problem stays resolved and
   changes the world - a new route, relationship, or resource. Encounters are
   broader than combat (deliver, escort, persuade, manipulate the
   environment), combat is avoidable, and grinding is neither required nor
   expected.

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
| Camera | Three-quarter perspective on an orthogonal grid (revised 2026-07-11, D-030): vertical wall faces, visible height, integer cell elevation with ramps/stairs - the player still reads space like a board, now with readable depth. Not true diamond-isometric |
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
  SRD/OGL content. Combat resolution is deterministic (D-026), not dice of
  any kind. Inspiration, not rules-as-written.
- Support multiplayer or any online/networked play.
- Use 3D or photorealistic visuals - committed to a retro pixel-art aesthetic.
  The three-quarter perspective (D-030) is drawn perspective on a 2D
  orthogonal grid, not a 3D engine and not true diamond-isometric rendering.
- Use random or invisible encounters - enemies are always visible on the map,
  threats are readable, and combat is avoidable.
- Use random hit rolls anywhere - no d10, no percent-to-hit, no crit RNG
  (D-026). Critical effects come from positioning and combinations.
- Respawn routinely defeated enemies or build a grind-based progression
  economy (D-028) - XP comes from finite authored encounters, quests, and
  discoveries.
- Implement bespoke pairwise code for friend-ability interactions - every
  interaction routes through the shared material/effect vocabulary (D-031).
  That vocabulary is the scope-explosion guardrail.
- Hardware-accurately emulate any specific handheld console - no forced
  palette limit, no fixed low-res canvas, no literal 4-channel hardware audio
  engine (see Design Decisions).

Superseded non-goal (2026-07-11, D-032): "not a commercial or monetized
product" is retired. The project is now **Steam-first commercial**; mobile
(Google Play) is postponed until the PC release proves itself. Practical
near-term effects are limited: controller-glyph prompts and UI coherence
become launch requirements rather than optional polish, and the art identity
must survive a store page. Keystore/signing safety rules stand unchanged.

## V2 Systems (2026-07-11 Canon)

These sections define the v2 design. Where they conflict with older sections
below (kept for history and because they describe the code still on disk),
these win - see the Authority Order in `AGENTS.md` and the superseding
decisions D-024..D-037.

### Shared World Vocabulary (D-031)

Do not implement bespoke code for every pair of Dungeon Friends - that is
exactly the scope explosion Kayden flagged. Instead, build a small
material-and-effect vocabulary: friends apply effects; objects, surfaces, and
units react according to tags. The same rules operate during exploration and
combat - that is the Horizon's Gate lesson the game is built around.

| World state | Useful reactions |
|---|---|
| Flammable vegetation | Ignites from fire; extinguished by water |
| Grown vines | Climbable, usable as a bridge or restraint; burnable |
| Water | Fills channels, extinguishes fire, can be frozen, conducts electricity |
| Ice | Walkable or usable as cover; melts from fire; breaks from force |
| Fire | Damages, lights, melts, and creates smoke |
| Smoke/gas | Obscures vision; cleared by air; possibly ignited |
| Heavy object | Carried or pushed by strength; holds plates; breaks weak floors or walls |
| Plate/switch | Activated by people, weight, projectiles, or elemental states |
| Fragile/blocked route | Broken, burned, flooded, frozen, grown over, or bypassed |
| Delivery target | Resolved through inventory, escorting, or the appropriate friend |

Reusable interactions this yields (each is a test case for the reaction
prototype, T-093): grow vines then burn them; flood a channel then freeze it;
wet enemies then conduct electricity through them; spread fire with air or
clear its smoke; lift a heavy object onto a plate; freeze water into
battlefield cover, then melt it to remove that cover.

The existing puzzle primitives (`PushableBlock`, `PressurePlate`, `Lever`,
`LockedDoor`, `Chest`) survive as vocabulary entries, not as a separate
system.

### Party Movement Outside Combat (D-029)

Everyone is visible without exploration becoming four-character
micromanagement:

- The player directly controls a selected leader.
- Other active friends follow a recorded breadcrumb path or loose formation.
- Followers do not block the leader or puzzle objects during normal
  exploration; the leader can move through their rendered positions.
- The player can choose a grouping/deployment posture. The first prototype
  exposes **line, square, and spaced** formations; names and final UI are
  tunable, but selectable spacing is part of the party contract.
- A one-cell choke temporarily compresses any selected formation into
  breadcrumb single-file movement; the party reforms afterward.
- The player can switch the leader for dialogue or field abilities.
- When an encounter begins, followers use the selected formation as their
  preferred deterministic deployment, fall back to the nearest legal reachable
  cells when terrain requires it, and become real occupying tactical units.
- During combat, every unit obeys normal collision and positioning rules
  (D-020's intentional ally-blocking survives inside encounters).

Outside combat, friend actions come from a quick ability wheel or compact
party bar - never by individually marching every friend onto every switch.

### Deterministic Combat Contract (D-026, D-027)

Core rules:

- Attacks hit if their target remains in the affected cells.
- Damage is shown before the action is committed; **the preview and the
  result always agree** - that is the tested contract.
- Status durations and forced movement are exact.
- Critical effects come from positioning or combinations, never random
  chance.
- High ground, cover, and hazards have explicit visible effects (elevation
  bonuses land only after basic elevation feels good - see Perspective).
- Enemies show their intended movement, target area, damage, and status
  effect. Moving, blocking, stunning, freezing, pushing, or obscuring the
  enemy can change or cancel that intention.

First-cut damage formula (tunable; the contract is preview=result, not the
numbers): `damage = max(1, ability_power + attacker_stat - target_defense)`.

**Turn structure (resolved, D-027; Kayden's T-092 verdict 2026-07-11):**
combat uses **intent rounds**:

1. Enemies move or declare their plans.
2. The player sees every enemy target and effect.
3. Party members act in any order.
4. Enemy actions resolve.
5. Environmental reactions resolve.

Each enemy maintains a rolling forecast of upcoming verbs. The prototype
default horizon is three, but the exact count remains tunable. Previously shown
future verbs stay stable during an ordinary refill; if the plan becomes invalid
(for example, its internal target is defeated or the current verb is no longer
legal), the enemy replans the full horizon from the new state. Future steps
expose the **verb only** - move, attack, fire, guard, and so on - never the
hidden target or destination. Only the current action reveals exact movement,
affected cells, damage, and status. The party then acts in any order before the
enemy action and environmental reactions resolve.

Same-room continuity does not mean an invisible mode change (D-036). When an
encounter begins, exploration input freezes briefly, an original audio/visual
stinger announces the encounter, and the turn-based controls/intent surface
appear before the first player action. The camera, room, positions, puzzle
state, and shared rules remain continuous - no separate arena or scene swap.

Body blocking is a tactical promise, not incidental congestion (D-037).
Formation/deployment gives the player deliberate starting spacing, and combat
abilities may create exact protected cells. The first gray-box acceptance case
is a directional guard field covering the cell in front plus the adjacent left
and right cells for an exact duration, capable of intercepting a line-shaped
breath attack. This proves the spatial contract without locking a specific
friend or dragon ability before T-093's shared vocabulary exists.

### Perspective And Elevation (D-030)

Three-quarter perspective without an engine restart - no true
diamond-isometric rendering:

- Keep the orthogonal square logic grid, `TileMapLayer`, `AStarGrid2D`, and
  grid-snapped Tween movement exactly as built.
- Render characters, props, cliffs, and walls in three-quarter perspective;
  add vertical wall faces and stronger ground-plane depth.
- Give cells a small integer elevation; connect elevations with ramps,
  stairs, and climbable transitions.
- Preserve Manhattan grid movement initially.
- Add high-ground bonuses and line-of-sight only after basic elevation feels
  good in play - they are explicitly out of the first visual spike (T-089).
- Kayden accepted the T-089 elevation read without explanatory labels on
  2026-07-11. The remaining issue is palette/color separation, not projection,
  grid logic, or elevation architecture.

### Roster And Recruitment (D-033)

Scope targets:

- **Thesis prototype:** Hero plus 2 real Dungeon Friends.
- **Steam demo / vertical slice:** 5-6 recruitable friends, active party of 4.
- **Full game:** approximately 10-12 excellent friends before considering
  more.

Each friend needs only: one primary world verb; a small deterministic combat
kit; one passive or reaction; one personality hook and recruitment story; and
one meaningful interaction with another friend's verb. Friends may share a
verb without feeling identical (ranged flame projector vs. self-igniting
melee).

The critical path must never require predicting the correct roster hours in
advance. Safeguards (use one or more): party swapping at Goddess shrines,
camps, or save points; multiple solutions for major puzzles; roster-specific
puzzles reserved for optional secrets; a limited baseline toolset on the
hero; clear telegraphing of upcoming requirements before the player commits
to a dungeon.

### Progression Economy And Persistence (D-028)

A resolved enemy remains defeated. Therefore:

- XP comes from finite authored encounters, quests, and discoveries.
- Major abilities unlock through recruitment and story milestones.
- Equipment comes from treasure, crafting, shops, and resolved problems.
- Grinding is neither required nor expected.
- Save data records resolved encounter IDs and persistent environmental
  changes (this reverses D-009's `no defeated_enemy_ids` schema rule).

An `Encounter` is broader than combat. Its resolution might be: defeat the
threat; deliver an object; escort someone; manipulate the environment;
satisfy an NPC; intimidate, persuade, or assist; or discover an alternate
route. This gives the adventure variety without a separate dialogue-RPG
ruleset.

Auto-resolve is a later feature (D-034): because encounters are finite, it
should unlock only when the party clearly outclasses an optional encounter or
has already mastered that enemy family.

### Story Spine (D-035)

The dragon is visible or repeatedly foreshadowed from very early in the game.
The structure is assembling the expedition capable of reaching and defeating
it - party-building IS the story, not its progression menu:

- The dragon's arrival disrupts the region's natural systems.
- Selena chooses the protagonist because they can unite incompatible people
  and powers.
- Each region contains a local consequence of the dragon's presence.
- Solving that regional problem reveals or recruits a Dungeon Friend.
- Friends who initially distrust one another learn to combine their
  abilities.
- The mountain route is the final examination of the same environmental
  vocabulary learned throughout the game.

This supersedes the four-legendary-item errand structure (2026-07-09 row);
the regional geography (forest, river valley, mountain, city, dragon lair)
survives, with the city leaning toward hub status. `docs/WORLD_LORE.md` is
realigned to that spine; intentionally open character and region details remain
future authored-content decisions.

### Reuse, Rework, Retire

| Fate | What |
|---|---|
| **Keep** | Godot 4.7/GDScript; LDtk import + entity placement; `RoomGrid` + `AStarGrid2D`; grid-snapped Tween movement; Resource-backed characters/abilities/items/encounters; pushable blocks, plates, levers, doors, chests; save/load infrastructure + `MapRegistry`; input-mode prompts, dialogue, debug tooling; the first-party test harness; Kenney assets as temporary scaffolding |
| **Rework** | `Player` into party-leader + follower control; `RoomGrid` to understand elevation, material tags, and environmental states; `AbilityData` around deterministic effects and world verbs; `OverworldEnemy` into a persistent, avoidable encounter actor; `TurnManager` into the selected deterministic round model; `SaveData` to store resolved encounters and altered environmental states; character resources around field ability, combat role, and reactions |
| **Retire** | The separate `CombatScene` battlefield model; arena generation/selection and the combat zoom transition; d10 hit thresholds and random attack rolls; the always-respawn rule; the single-overworld-avatar contract; the purely top-down art contract; tests that exist only to prove those superseded rules |

Retirement is staged through the linked stable specs - do not delete working v1
code before its v2 replacement exists and is verified.

## Current Product Shape

> **Pivot note (2026-07-11):** this section describes the v1 build - which is
> still what the code on disk does - and its Phase 0-6 targets. It remains
> accurate as a description of the working software and stays until the pivot
> sequence replaces each piece. Where it conflicts with V2 Systems above
> (separate battle mode, d10, single avatar, zoom transition, respawns), V2
> is canon.

**Moment-to-moment loop (confirmed 2026-07-05):** explore -> interact with an
object/NPC/enemy -> take an action -> see the consequence of that action ->
continue exploring. Everything below is this same loop playing out at a
different scale - a single NPC conversation, a single puzzle switch, or a full
combat encounter.

The v1 target shape below is retained as verified implementation context; use
the capability catalog and linked specs for current v2 state. When that build
is running, a user can:

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

**Status (2026-07-11): Phase 2's puzzle recut is built and the Phase 4
tactical-combat core is playable.** The latest playthrough retired
jumping from the current dungeon: standing still and pressing jump reads as a
janky hop rather than a believable gap crossing. Jump stays benched until a
future Zelda-style traversal item gives it a clear rule. The tutorial's second
room now teaches one idea on one continuous floor: player weight opens a
momentary pressure-plate gate, stepping off closes it, and a pushable block
holds it open. There are no pits or latching lever in that room; its remaining
lever is only the block-reset escape valve.

Touching a visible enemy now starts a near-full-screen 17x7 tactical battle.
D-018's authored, biome-consistent weighted arena pool has replaced the
literal local-terrain generator: seven editable forest LDtk templates (2
`empty`, 3 `mid`, 2 `hard`) use the initial 5/2/1 per-template weights,
biome/tags, deterministic no-repeat shuffle bags, save-safe selection state,
and contact-side deployment orientation. T-087 adds the first dungeon-biome
template, `dungeon_stone_hall`, and wires FightRoom's guardian through a
`dungeon_guardian` encounter so dungeon combat cannot silently use forest
terrain. The imported `TileMapLayer` terrain,
not copied nearby walls, reaches the live combat renderer. Hero plus the temporary Buddy test
companion (D-013), interleaved initiative, move/attack highlights, and
Attack/Ability/Item/Defend. LDtk EncounterData now supplies the regular
forest's two-enemy party and full XP/loot reward total; encounters zoom in
before their short hand-off fade and zoom back to the unchanged overworld
position. The combat HUD shows live turn order, party HP/MP, action prompts,
and damage/heal feedback. T-085 gives round/arena, current event, party status,
turn order, prompt, and command rows separate bounded regions; result text
replaces setup text instead of stacking, and short field popups clamp below
the header. The combat field is text-free: legal movement is marked by filled
blue cells with bright blue borders, while a four-sided yellow outline marks
the exact destination cell. The completed authored-arena/UI battery is
green at 32 suites / 200 tests / 958 checks, with the slice smoke at 134/134
on 5/5 runs.
Item now opens a named consumable list showing quantity and acting unit before
confirmation; Back consumes nothing. Phase 4 now needs only final T-069
windowed acceptance. After that pass,
Phase 5 (party/progression and character menu) is the next development phase.
The first runtime character/enemy art pass is now wired; broader environment,
object, UI/effect, directional, and enemy-variant art remains phase-timed.

The most important quality bar is:

- Movement and puzzle feel (precise, grid-snapped, no floaty physics) over
  feature breadth - see Design Pillars above (the canonical five, 2026-07-08),
  which replace the retired Gameplan's four dev-discipline pillars.

## Direction And Build Order

The v1 foundation, movement, puzzle, save/load, and tactical-combat phases are
implemented history. They remain useful source and proof, but they no longer
select future work. The v2 dependency chain is:

1. **Prototype risk gate (`S-001`, `S-002`, `S-008`):** preserve the accepted
   foundation, recut the fire/smoke readability failures, then obtain Kayden's
   explicit fun, revise, or stop verdict.
2. **Production runtime (`S-009`, `S-010`, `S-011`):** establish one production
   world, graduate the visible party and formations, and route exploration and
   encounters through the same material/reaction vocabulary.
3. **Production combat and persistence (`S-012`, `S-003`):** retire separate
   random battle truth only after deterministic in-room combat is proven, then
   persist resolved encounters and intentional environment state.
4. **Progression and first experience (`S-013`, `S-014`):** lock the finite
   roster/progression contract and produce a readable, tutorialized opening.
5. **Thesis and player proof (`S-004`, `S-005`):** prove the full authored loop,
   then run at least two neutral external first sessions.
6. **Release proof (`S-015`):** close platform, packaging, accessibility,
   performance, and release evidence; Kayden alone approves publication.

The archived v2.1 Taskboard preserves the detailed v1 phase ledger, backlog,
asset lanes, bugs, and proof history. Future work promotes a coherent capability
from that evidence into a stable spec instead of reviving the old queue.

### Movement-State Roadmap (2026-07-06, Kayden)

Kayden's priority ordering for movement/traversal capability. Rows 1-3 are
implemented v1 history; rows 4-5 remain deferred evidence in the archived v2.1
Taskboard and require a new stable spec before implementation.

| Priority | Movement type | Why | Where it lands |
|---:|---|---|---|
| 1 | Walk, face, act lock-in | Core feel | Phase 1 - T-021 (walk exists; feel polish + turn-in-place is the open work) |
| 2 | Door transitions, ledges, stairs | Room/world structure | T-022 (door transition, Phase 1); manual jumping is benched until a future traversal item gives it a coherent rule |
| 3 | Push/pull objects | Zelda puzzle baseline | Phase 2 - T-023 (PushableBlock) |
| 4 | Dash/roll | Makes overworld feel better | Legacy stretch S-009, cold; reassess only through a linked future capability |
| 5 | Swim (or similar) | First major traversal upgrade | Legacy stretch S-010, cold; reassess only through a linked future capability |

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

#### 2026-07-10 revision (Kayden's latest playthrough)

The prior jump/chasm lesson is no longer accepted. A standing, facing-based hop
made the character appear to jump vertically while crossing a horizontal gap;
requiring forward+jump would add timing complexity that fights the precise
grid-movement quality bar. Manual jumping is therefore **benched**, not retuned,
until a future traversal item (a Zelda-style item is the reference) defines a
clear authored use case.

The replacement Phase 2 tutorial vocabulary is:

- **On/off lever:** a deliberate interaction toggles and visibly latches linked
  state until the lever is used again. The existing reset-only lever does not
  satisfy this role.
- **Pressure plate:** visibly active only while the player or a block occupies
  it; linked state releases on vacate. Room geometry must make the cause/effect
  readable and allow a block to hold it without a softlock.
- **Pushable blocks:** the reusable object that changes the state of the room,
  including holding plates. Fixed bricks may remain for boundaries, but the
  tutorial must not hide its entire puzzle behind guessing which wall moves.

T-078 owns the smallest LDtk room recut that teaches all three without requiring
jump. Pit falls may remain environmental hazards, but no required route assumes
the player can cross a pit manually.

## Architecture

| Layer | Choice | Source / Notes |
|---|---|---|
| Engine/Runtime | Godot 4.7.x, GDScript | Upgraded from 4.6.x on 2026-07-07 (Kayden's call); installed and verified: `4.7.stable.official.5b4e0cb0f` (full clean reimport + unit/smoke suites all green on 4.7) |
| Renderer | Mobile | Locked (audit §4.1) |
| UI | Godot `Control` nodes + `CanvasLayer` (HUD, dialogue, menus) | `game/scenes/ui/` |
| Backend | None - fully local, no server, no accounts | |
| Storage | `Resource` (`.tres`) files for game data; `SaveData` (JSON) to `user://saves/` | `game/data/`; save format per D-006 (see Core Logic) |
| Levels | LDtk, imported via `heygleeson/godot-ldtk-importer`, entities all-in per D-002 | **Importer v2.0 + entity post-import pipeline live 2026-07-06** (T-004/T-031): each `.ldtk` sets `entities_post_import` to `scripts/ldtk/entities_post_import.gd`, which instantiates the matching game object per entity (conventions documented in that script); `LdtkRoom` adopts them into the runtime grid. Current worlds: `forest.ldtk` (T-011), `tutorial_dungeon.ldtk` (4 levels, T-027 + 2026-07-07 rework), `entity_test_room.ldtk` (pipeline test fixture), `test_room.ldtk` (T-004 fixture) - consolidation into one `world.ldtk` can wait for real LDtk-app authoring. The LDtk desktop app is installed (Gatekeeper cleared); the `.ldtk` files are still bootstrap-generated JSON (`assets/levels/_scripts/generate_levels.py`) until Kayden starts hand-authoring |
| Art | Aseprite (primary, Lua/CLI-scriptable, **not yet installed** - purchase is Kayden's call), Pixelorama (fallback), normalized generated-source pipeline | 1280x720 design-reference base, flexible HD/ultrawide scaling (see Design Decisions); **grid unit decided at M1.1 (2026-07-06): 16x16 art pixels rendered at 4x = the 64px runtime cell** (`RoomGrid.TILE`). The first runtime character pass is wired (2026-07-10): four-frame transparent Hero knight, Buddy wizard, and red-ooze animations use shared scale/bottom-center anchors in overworld and combat. Raw edits, runtime atlases, prompt provenance, and the checkerboard-cleanup script live under `assets/art/` and `docs/assets/`; the Aseprite exporter remains ready for hand-authored replacements. |
| Audio | Furnace Tracker -> `.ogg` -> `AudioStreamPlayer`/`AudioStreamPlayer2D` | No hardware-channel-emulation engine (dropped, not deferred) |
| Testing | First-party headless GDScript unit harness + import/boot checks + end-to-end slice smoke + manual play-check | `game/tests/` (38 suites / 280 tests / 1781 checks at the 2026-07-17 canon-conversion baseline); exact commands and coverage policy in `RUNBOOK.md` |
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
│   ├── archive/                      <- cold queues and historical proof
│   └── LEGACY_HARNESS.md            <- archived pre-v2 AGENTS.md/CLAUDE.md
├── specs/                            <- stable capability packets and proof
├── tools/spec-workbench.mjs          <- spec selection, lifecycle, render, doctor
├── AGENTS.md                        <- agent behavior and read/edit scope
├── BLUEPRINT.md                     <- this file
├── LEXICON.md                       <- shared project and Workbench terms
├── TASKBOARD.md                     <- generated hot execution projection
└── RUNBOOK.md                       <- setup, operation, verification, recovery
```

## Main Contracts

> **Pivot note (2026-07-11):** these contracts describe the v1 code on disk
> and stay authoritative for it until the pivot sequence reworks each piece.
> The Combat row's scene, arena selection, zoom transition, and d10 math are
> retired by D-025/D-026 once their v2 replacements exist (see V2 Systems ->
> Reuse, Rework, Retire).

### Scenes

| Scene | Purpose | Status | Source |
|---|---|---|---|
| `game/scenes/main.tscn` | Root: `SceneManager` wiring, `WorldContainer`/`CombatContainer`/`UILayer`/`TransitionLayer` | working - `scripts/main.gd` registers the containers with `SceneManager` and boots the forest slice into `WorldContainer` | `game/scenes/main.tscn`, `game/scripts/main.gd` |
| Overworld / Dungeon (LDtk-instanced) | Grid movement, puzzles, visible enemies | working through the LDtk pipeline: `RoomGrid` runtime grid model + `LdtkRoom` base (imports the level, feeds Wall/Pit IntGrids into the grid, adopts post-import-spawned entities) + `ForestRoom` (`forest.ldtk`) | `game/scripts/overworld/`, `game/scripts/ldtk/entities_post_import.gd`, `game/assets/levels/` |
| Combat | Turn-based tactical party-vs-enemy battle (BG3 turn-based mode) | **Built through T-087 (2026-07-11):** two-layer FSM (Battle FSM in `CombatScene`, per-entity FSM on `CombatUnit`) + `TurnManager` interleaved initiative; party from the GameState roster (Hero knight + D-013 wizard test companion) vs LDtk-authored `EncounterData` enemy parties. D-018 selects seven editable forest arenas plus one dungeon stone hall through deterministic biome/tag-filtered bags; authored zones orient deployment from contact side and a shared validator protects 4v4 starts. FE-style move/attack presentation; Attack/Ability/Item/Defend; d10 math; AI; zoom transition; bounded turn-order/party-status/event HUD, full-cell destination cursor, and clamped feedback. | `game/scripts/combat/`, `game/scripts/data/arena_*.gd`, `game/assets/levels/battle_arenas.ldtk`, `game/data/arenas/` |
| UI (HUD, dialogue, pause, party menu) | Player-facing menus and status | dialogue box exists (`DialogueBox`, code-built); HUD/pause/party menus missing | `game/scripts/ui/dialogue_box.gd` |
| `game/scenes/dev/display_scaling_spike.tscn` | Throwaway diagnostic - proves the new flexible HD/ultrawide stretch settings render an undistorted tile grid at 1280x720/1920x1080/3440x1440 | working (placeholder ColorRect tiles, no real art yet) | `game/scenes/dev/display_scaling_spike.tscn`, `game/scripts/dev/display_scaling_spike.gd` |
| Tutorial dungeon (behind the boss door) | Four LDtk-authored rooms (`tutorial_dungeon.ldtk` levels HubRoom/ChestRoom/PitRoom/FightRoom, scripts `tutorial_*_room.gd`) navigated via `SceneManager.boot_room/enter_room/exit_room(s)`. T-078's second room is one continuous floor with a visible momentary plate, one heavy block, one plate-driven north gate, and a reset lever; no pits or required jump. | playable; automated puzzle acceptance green, windowed readability re-check pending | `game/scripts/overworld/tutorial_*_room.gd`, `game/assets/levels/tutorial_dungeon.ldtk` |

### Commands

Godot Input Map actions (single source of truth for all gameplay input across
keyboard, controller, and mobile touch - per-device bindings below):

| Command | Purpose | Required for done? |
|---|---|---|
| `move_up` / `move_down` / `move_left` / `move_right` | Grid movement | yes |
| `interact` / `confirm` | Interact with objects/NPCs; confirm menu selection | yes |
| `cancel` / `back` | Cancel or back out of a menu | yes |
| `menu` | Open pause/party menu | yes |
| `character_menu` | Open the character menu (UI not built yet) | no - future UI |
| `jump` | Reserved traversal action; benched until a future traversal item defines it | no - dormant |

Per-device bindings (Godot Input Map is the single binding source; migrated
from the retired Gameplan §11):

| Action | Keyboard | Controller | Touch (mobile) |
|---|---|---|---|
| `move_*` | Arrow keys / WASD | D-pad | On-screen virtual D-pad |
| `interact` / `confirm` | E | A | On-screen "A" |
| `cancel` / `back` | Q | X | On-screen "X" |
| `menu` | Tab | Start / Options | On-screen menu icon |
| `jump` | Space | B | On-screen "B" |
| `character_menu` | F | Y | On-screen "Y" |

**Keyboard/controller anchor (locked by Kayden 2026-07-10):** keyboard and
controller controls map 1:1: E/A interact and confirm, Space/B is the reserved
traversal action, Q/X cancels or goes back, F/Y opens the future character menu,
Tab/Start opens the broader menu, and WASD/D-pad moves. The `character_menu`
action is bound now, but its UI does not exist yet. **Current on-screen prompts
show keyboard keys only.** Mixed labels such as `E / A` were confusing; replace
keyboard labels with controller glyphs as one coherent UI pass later (T-079),
not as slash-separated text now.

`TouchScreenButton` nodes map directly to Input Map actions, so gameplay code
reads `Input.is_action_pressed(...)` regardless of source; the touch UI is only
shown on mobile exports; Godot 4 auto-detects most standard gamepads.

### Data Model

| Entity | Key fields | Stored where | Notes |
|---|---|---|---|
| `CharacterStats` | `id, display_name, max_hp, max_mp, attack, defense, speed, move_range, attack_range, sprite_frames, starting_abilities, portrait, combat_sprite` | `game/data/characters/*.tres` | Party member stat block; T-063 range shape is built |
| `EnemyStats` | `id, display_name, max_hp, attack, defense, speed, move_range, attack_range, abilities, ai_behavior, xp_reward, loot_table, portrait, combat_sprite, sprite_frames` | `game/data/enemies/*.tres` | `ai_behavior`: `RANDOM_WALK` / `BIASED_TRACKING` / `PATTERN`; loot stays string ids through `ItemLibrary`; SpriteFrames now drive shared overworld/combat art |
| `ItemData` | `id, display_name, item_type, stat_modifiers, on_use_ability` | `game/data/items/*.tres` | `item_type`: `KEY_ITEM` / `CONSUMABLE` / `EQUIPMENT` |
| `AbilityData` | `id, display_name, mp_cost, target_type, power, attack_range, element, overworld_use` | `game/data/abilities/*.tres` | Each ability owns its Manhattan reach; `element`/`overworld_use` remain unused stretch fields |
| `MapMeta` | `ldtk_level_id, display_name, music_track, encounter_table` | one companion `.tres` per level | LDtk is the source of truth for layout; this covers non-visual metadata |
| `EncounterData` | `id, enemy_group, biome, arena_tags, fixed_arena_id, background_id` | `game/data/encounters/*.tres` | Referenced directly by overworld enemy instances; biome/tags filter D-018 arenas and a boss can pin one; no random encounters |
| `ArenaData` | `id, biome, tags, tier, weight, ldtk_path, level_id, mirror_safe` | `game/data/arenas/*.tres` + `game/assets/levels/battle_arenas.ldtk` | Topology and deployment slots stay in LDtk; data selects the editable template |
| `SaveData` | `schema_version, current_map, player_position, party_roster, party_levels/xp/hp/mp, inventory, flags, arena_selector_state` | `user://saves/slot_N.json` (JSON - D-006, 2026-07-07) | Never saved mid-combat; 3 slots from the start; selector state is optional for v1 compatibility and prevents reload rerolls; no `defeated_enemy_ids` - enemies always respawn (D-009) |

*Status (2026-07-09):* `CharacterStats`, `EnemyStats`, `ItemData`,
`AbilityData`, `MapMeta`, and `EncounterData` exist with shipped sample
resources. T-063 resolved the range shape: stats own `move_range` and the
basic `attack_range`; each ability owns its own `attack_range`. `ItemLibrary`
resolves ids, session inventory is `{item_id: qty}`, and
`SceneManager.add_item()/remove_item()` are the only write paths.
`EncounterData.enemy_group` is loaded from each regular forest Enemy's LDtk
`EncounterId`, consumed by combat, and rewarded as a full group. T-072..T-075
add `ArenaData`/registry/selector, the seven-level editable forest pool, and a
shared loader/validator/gallery; selector state survives JSON save/load without
breaking existing v1 saves. `SaveData` is built (2026-07-10, T-037): JSON
snapshots via `SaveManager` with atomic writes and tolerant loads. `EnemyStats.loot_table` deliberately
remains a `PackedStringArray` of item ids resolved through the library (T-043).

**Enemy archetypes and variants (2026-07-10):** LDtk Enemy instances stay
lightweight placement records. Their `StatsId` selects one shared
`EnemyStats` resource under `game/data/enemies/`; changing that `.tres`
updates every placed enemy with the same id. Instance-only map behavior
(spawn cell, patrol `LeashRadius`, boss flag, encounter group, unique id)
stays in LDtk. New tiers/elements are new explicit resources and ids rather
than copied per-instance numbers (for example `slime_1`, `slime_1_boss`,
`slime_1_miniboss`, `slime_2_fire`, `slime_2_ice`). Display names remain
player-facing and may change without changing the stable id.

## Party And Combat Model

> **SUPERSEDED (2026-07-11, D-025/D-026/D-027/D-029):** this entire section
> describes the v1 model (single overworld avatar, separate zoomed battle
> mode, d10, per-unit interleaved initiative). It is kept because it
> documents the code still on disk. The v2 model - whole party visible,
> encounters in the current room, deterministic effects, telegraphed intents -
> lives in V2 Systems above.

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
- **Allied units occupy and block cells.** The player cannot walk through a
  teammate. That positioning friction is an intentional combat-balancing rule,
  not a bug to solve with ally pass-through. Arena/deployment design must still
  avoid unavoidable starting softlocks; the counterplay is planning movement
  order and routes.
- This keeps the overworld simple and readable while concentrating the
  positioning depth in the tactical battles, and is consistent with the
  already-locked grid-based, per-unit-initiative, d10 combat below (it names the
  *control scheme, framing, and genre* - tactics-RPG, not JRPG - not new combat
  math).

## Core Logic And Invariants

> **Pivot note (2026-07-11):** the movement, pathfinding, data, architecture,
> level, puzzle, and save rules below survive the v2 pivot unchanged. The
> **Combat**, **Combat transition**, and **Enemy respawns** rules are
> superseded (D-025/D-026/D-027/D-028) and are marked inline; they describe
> the v1 code still on disk. The **Enemies** rule survives with one revision:
> contact still begins the encounter, but the encounter happens in place with
> readable detection/avoidance, not in a separate scene.

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
- **Jump/traversal (benched 2026-07-10 - Kayden):** the `jump` action and its
  Space/B anchor may remain in the Input Map, but current rooms must not require
  or advertise manual jumping. The facing-only standing hop looked vertical
  while moving across a gap; adding a forward+jump timing chord would make the
  grid controls jankier. Reintroduce traversal only with a future Zelda-style
  item and a new explicit movement contract; do not silently reactivate the old
  one-cell hop.
- **Pathfinding**: `AStarGrid2D`, `diagonal_mode = DIAGONAL_MODE_NEVER`,
  Manhattan heuristic.
- **Combat (SUPERSEDED 2026-07-11 by D-025/D-026/D-027 - v1 description of
  the code on disk; v2 contract is in V2 Systems -> Deterministic Combat
  Contract)**: a **tactics-RPG battle** (BG3 turn-based mode as the model, Fire
  Emblem-style range highlighting as presentation - **not a JRPG**), grid-based
  and turn-based, with a party of up to four units the player selects and moves
  within a highlighted move range. Resolved with a **d10 percentage system** -
  roll 1-10 against a stat-derived success threshold, so success chances map
  directly to clean percentages (e.g. a threshold of 7 reads as a 70% chance).
  **T-060 formula:** hit tier = `clamp(5 + attack - defense - defend_bonus,
  1, 9)`, where defending subtracts 2; roll-high succeeds on
  `d10 >= 11 - tier`. Hit damage is
  `max(1, attack + ability_power - floor(defense / 2))`, then defending halves
  it again with a minimum of 1. Support healing is flat ability/item power,
  minimum 1. These numbers are first-cut T-069 tunables; the clamped 10%-90%
  band, roll-high shape, and minimum-1 damage are the tested contract.
  Two-layer FSM - Battle FSM
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
- **Combat transition (SUPERSEDED 2026-07-11 by D-025 - v2 has no separate
  combat scene and no zoom transition; encounters begin in place)**: touching an enemy pauses the overworld, instances
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
  - Transitional source state (2026-07-10): the four existing 1.5.3 projects
    under `game/assets/levels/` are repaired as editor-openable sources while
    the planned `world.ldtk` consolidation remains future work. Saving in
    LDtk requires a Godot reimport before play. Forest regular slimes use
    `StatsId=forest_slime` and patrol within `LeashRadius=3`; the boss keeps
    its authored radius of 2.
- **Puzzle primitives**: `PushableBlock`, `PressurePlate`, `Switch`/`Lever`,
  `LockedDoor` - LDtk entity custom fields carry linking IDs; a per-room
  `PuzzleController` wires signals at `_ready()` (MVP choice - simpler to
  debug than fully-automatic wiring). Semantics confirmed 2026-07-06 (Kayden):
  - **PressurePlate is active Phase 2 vocabulary again (2026-07-10):** it is
    momentary while any grid occupant - player or block - stands on it and
    releases on vacate. The original implementation read as broken because the
    room did not communicate cause/effect. T-078 must add visible pressed/
    released state, a clearly linked result, and geometry where a block can
    hold the plate without a softlock.
  - **Lever is latching on/off:** interact toggles its linked state and the
    lever visibly remains on or off until used again. A reset-only escape lever
    is a dev/safety affordance, not the tutorial's on/off lever mechanic.
  - **PushableBlock.movable (added 2026-07-07)**: `Movable=false` makes a
    fixed brick - identical placeholder look, occupies and blocks its cell,
    refuses every push. This is the hub brick-wall primitive ("wall where
    you can only push some bricks, so we don't soft lock ourselves"); the
    2026-07-06 3x3-plate geometry note is retired with the plate hold.
  - **Pits (revised 2026-07-10)**: manual pit jumping is benched. A
    `PushableBlock` pushed into a pit may **fill it**, permanently converting
    that cell to walkable floor (classic Zelda). **Walking into a pit is a
    Zelda-style fall** (T-047): **10 HP to every party member** (Kayden's
    2026-07-10 windowed-playtest correction, superseding D-016's 10%-of-max
    first tuning) and
    respawn at the last entrance the player came through into that room; a
    fall that reaches 0 HP triggers the defeat flow. Enemies and pathfinding
    still treat pits as blocked. No required route may assume manual jumping.
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
  never touches save files. **Built 2026-07-10 (T-041/T-047), tuned same day
  by Kayden (D-014/D-015/D-016):** the restart-from-the-beginning rule is
  retired (`restart_game()` remains a dev tool);
  `Progression.xp_after_defeat` owns the floor-clamped penalty - **lose 25%
  of above-floor progress** ("some % of how much you have left to lose so it
  never feels too harsh"; `DEFEAT_XP_LOSS`, tunable); the party **respawns
  at 80% of max HP** ("like Zelda's three hearts, but 80% - eat a meal to
  get back to full"; MP restores in full, an agent interpretation until an
  MP/food economy exists); pit falls cost a flat **10 HP party-wide**
  (`FALL_DAMAGE`) and respawn at `RoomGrid.entry_cell`.
- **Enemy respawns (SUPERSEDED 2026-07-11 by D-028 - v2: resolved encounters
  stay resolved; SaveData will record resolved encounter IDs and persistent
  environmental changes. The v1 rule below describes the code on disk)**:
  **enemies respawn every time
  a room is left and rebuilt** - the same reset that un-wedges puzzles
  applies to enemies, uniques and bosses included (duplicate key drops are
  prevented by loot dedup; opened doors/chests stay open via flags).
  Suspended-and-restored rooms (mid-trip) keep their in-visit state.
  Deliberate deviation from the original Lufia-II defeated-enemies-stay-dead
  pattern (retired Gameplan §12); `SaveData` carries no `defeated_enemy_ids`.
  **Built 2026-07-10 (T-048)**: no `defeated_*` flags are written at all.
- **Save (revised 2026-07-07, D-006/D-011)**: save points are physical map
  objects (SaveCrystal); `SaveData` serializes to **JSON** at
  `user://saves/slot_N.json` (authored data stays `.tres` under `res://`);
  never saved mid-combat; defeat/checkpoints never write saves; 3 slots in
  the format, slot 1 via the crystal at MVP; a minimal Continue/New Game
  prompt when a save exists at boot. **Built 2026-07-10
  (T-037/T-039/T-040/T-042)**: `SaveManager` (atomic temp+rename writes,
  tolerant loads), the forest SaveCrystal beside the healer's campfire,
  `BootPrompt`, and the two-process `saveload_battery` acceptance proof;
  map ids resolve through `MapRegistry` (T-038), which also feeds the F1
  warp list (T-049).

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
| Scope creep from an oversized feature wishlist | High | Non-Goals plus explicit stable-spec activation are the guardrail; deferred legacy ideas stay cold until promoted into a reviewed spec |
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
| ~~Combat framed as a camera zoom into the encounter point, not a hard scene cut~~ - **superseded 2026-07-11 by D-025 (no separate combat scene at all)** | Founding vision calls for an early-Final-Fantasy-style transition so the overworld reads as bigger than its grid; layers onto the existing SceneManager context-passing pattern rather than replacing it | 2026-07-05 / this session's founding prompt |
| ~~World authored in this order: forest (Kokiri-Forest mood) -> castle city -> mountains -> rivers -> surrounding wilderness~~ - **superseded 2026-07-09, see the world/story spine row below** | Founding vision's explicit world-progression arc; tied a creative goal to the concrete post-MVP content milestones | 2026-07-05 / this session's founding prompt |
| ~~World/story spine: Forest Village -> Forest Dungeon -> River Valley village/dungeon -> Mountain village/dungeon -> City region -> final Dragon Lair; the party gathers four working-name legendary items (Sword of Slaying, Shield of Protecting, Ring of Magic, Circlet of Strength) before fighting the dragon~~ - **superseded 2026-07-11 by D-035 (dragon-expedition spine; geography survives, legendary-item errands do not)** | Kayden's story pass clarified the regional loop: each main region has a village hub, a local problem, a dungeon, and a legendary item or clue that points to the next region. The four-item count matches the four-hero/player party shape. Details and open lore questions live in `docs/WORLD_LORE.md` | 2026-07-09 / Kayden story pass |
| Equipment (weapon variety) and elemental/magic systems are the highest-priority Stretch Goals after MVP | Founding vision emphasizes magic and weapon variety; the plan already licensed building these "once the base loop is fun" - this reprioritizes within the existing Stretch sequencing rather than reopening MVP scope | 2026-07-05 / this session's founding prompt (Stretch sequencing; see `TASKBOARD.md` Deferred) |
~~No separate integration branch; branch-per-milestone -> PR directly into `main`~~ - **superseded 2026-07-05 (second session), see the `integration` staging-branch row below** | Solo hobby project - matches how Kayden's other personal-scale projects (e.g. DigitalTome) actually run day to day; the workbench's own 3-tier convention is calibrated for the shared harness repo, not every downstream product | 2026-07-05 / this Adoption run |
| `integration` branch as staging before `main` - work accumulates on `integration`; Kayden explicitly syncs `integration` -> `main` when ready, rather than every task PRing straight to `main` | Kayden's call once the first-playable slice was working and felt worth protecting - gives a reviewable, shippable line separate from in-progress work, at the cost of one extra branch for a solo project | 2026-07-05 (second session) / this session |
| Concrete first-playable scenario: forest test area, grid-snapped walk, talk to one NPC, touch a visible enemy, win a simple turn-based battle, return to the same forest position, get a key/reward, open a blocked path | Kayden gave this as the smallest testable slice to build toward - smaller than the full Phase 6 finish line (no boss/save/party depth required), useful as an early integration smoke test once combat exists (see TASKBOARD.md T-013, deferred) | 2026-07-05 / this session |
| GBA-fantasy-adventure visual language: bright, readable, toy-like overworlds with chunky silhouettes, dense environmental texture, clean top-down camera; tiles built from 8x8/16x16 units | Kayden's explicit visual-reference table (GBA-era fantasy-adventure art direction as the touchstone, not any one licensed title); narrows rather than contradicts the flexible-HD/ultrawide rendering decision above - the canvas renders natively at 1280x720+, the art itself is built from small GBA-style tile units | 2026-07-05 / this session, see Visual Language section |
| General moment-to-moment loop confirmed as explore -> interact with an object/NPC/enemy -> take an action -> see the consequence -> continue exploring | Kayden's explicit framing for what "first playable" should feel like at every scale; confirms rather than changes the existing concrete first-playable scenario (row above) | 2026-07-05 / this session |
| Combat is grid-based (units occupy cells, check move/attack range, can move each turn); turn order is strict per-character initiative (speed), never a whole-team phase | Kayden's explicit combat-loop framing: check ranges -> move -> attack phase -> results, repeated per unit in initiative order, not team-by-team; the `TurnManager` design already sorted all combatants together by speed - only the Battle FSM's stale `PlayerPhase`/`EnemyPhase` state names implied team-phasing, and those are retired | 2026-07-05 / this session |
| ~~Combat resolution uses a d10 percentage system (roll 1-10 against a stat-derived success threshold) instead of flat deterministic damage-only math~~ - **superseded 2026-07-11 by D-026 (fully deterministic)** | Kayden's explicit request for a system where success chances read as clean percentages. T-060 resolved the concrete first-cut formula under red/green; see Core Logic above. Numbers remain tunable at T-069 without changing the d10/clamp/minimum-damage contract | 2026-07-05; resolved 2026-07-08 / T-060 |
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
| Jump is a **player-pressed button** (Space), not automatic/contextual | Kayden: "I don't want to trust that my character will jump the right way"; adds a `jump` input action (the map's first addition beyond the original 8). Superseded by the locked 2026-07-07 keyboard scheme: Space only, with no Alt/C fallback. | 2026-07-06 round 3 / this session; binding revised 2026-07-07 |
| Phase 2 death = restart from the beginning of the game; the richer old-man/room-reset respawn moves to Phase 3 | Kayden: "I agree this is starting to be phase 3" - the dungeon-puzzle-state reset a mid-dungeon respawn needs is the same serialization `SaveData` provides, so it belongs with save/load, not Phase 2 | 2026-07-06 round 3 / this session, supersedes the round-2 respawn row |
| Overworld is a **single party avatar** (no snake-follow); the party's characters appear only in **Fire-Emblem-Sacred-Stones-style tactical combat** (select a character, WASD picks its destination cell, mini action menu below) | Kayden: "I kinda imagined one character in this overworld being your party... These are party encounters, not character encounters"; concentrates positioning depth in the tactical battles and keeps the overworld simple - **supersedes the snake-follow-formation decision** (retired Gameplan §10) | 2026-07-06 round 3 / this session |
| Puzzle geometry primitive: plate at the center of a 3x3 pushing space, block in a corner, 2-cell walking margin around it (the margin enables the around-the-block L-shaped push, since pushing needs the opposite side and there are no diagonals) | Kayden's sketch-in-words for Room 1; exact cells/push-count finalized at build against his drawing | 2026-07-06 round 3 / this session |
| Placeholder art through Phase 2, one art pass afterward; invest in dev tools (room warp, puzzle reset, grant item, skip combat) as early as possible instead | Kayden: "Lets do art at the end, but build out some dev tools like your suggesting as soon as we can" - Phase 2 validates mechanics, and puzzle iteration is playtest-heavy, so tooling pays back faster than art now | 2026-07-06 round 3 / this session |
| Tutorial-dungeon build interpretations (T-027, **agent interpretation - confirm in windowed play**): (a) the hub gets a reset **Lever** as the soft-lock escape valve; (b) blocks can never be pushed onto doorway cells or their approach cells; (c) opening the chest is the dungeon's completion beat - it unbolts the locked entry door; (d) the hub's west door is one-way (opens permanently when the player loops back through it from Room 3); (e) the Room 3 key-carrier is a new `dungeon_slime.tres` (10 HP / atk 3, `unique_id key_guardian` so it stays dead); (f) hub -> pit -> fight rooms suspend on the way in and are freed/rebuilt when backed out of, with chest/door/unique-enemy state persisted in `SceneManager.flags` | Fills the gaps Kayden's room spec left open, biased toward classic-Zelda readings and the Known Risks soft-lock mitigation; none of it touches a locked decision. Flag anything that plays wrong and it can be re-cut cheaply - rooms are LDtk data + thin room scripts | 2026-07-06 / this session (Phase 2 build) |
| **PressurePlate ON HOLD**; dungeon rescoped to four rooms: hub brick wall (13 bricks, one movable - Oracle-style, per Kayden's reference screenshot), new chest room behind a north **locked door** (`dungeon_key`; "I like having the door locked instead" of the chest), pit room gains two 1-wide jumpable ledges before the 2-wide chasm, fight room's guardian drops `dungeon_key` | Kayden's first windowed playthrough (T-032): the plate's momentary re-lock read as broken, so it's shelved rather than debugged mid-tutorial; the brick wall is wedge-proof by construction and keeps Room 1 focused on pushing | 2026-07-07 / playtest-feedback rework |
| Forest fixes from the same playthrough: every Wall cell now draws its tree tile (colliders were rendering as plain grass - the "random places I run into" bug), stray pit under the spawn cell removed, extra tree clusters added in the open stretch between spawn and the dungeon entry | Kayden: "I would like for there to be more things out in the open between me and the entry like there was. Maybe not a maze, but at least trees or something" | 2026-07-07 / playtest-feedback rework |
| **Phase 3 round (D-006..D-011, all resolved)**: (a) saves are **JSON** at `user://saves/slot_N.json` - Kayden delegated the pick; agent chose JSON per the retired Gameplan's own MVP JSON recommendation plus the `.tres`-from-`user://` script-execution risk; (b) **the shield unlocks Defend** - the command is absent from the combat menu until the shield is in inventory (D-001's answer); (c) **checkpoint respawns + XP-as-punishment** - keep inventory, lose XP never-below-level, dungeon-entrance/healer respawn, and walking into pits = Zelda fall back to the room's last-used entrance (supersedes pits-impassable); (d) **enemies respawn every time a room is left-and-rebuilt**, uniques included - the puzzle escape valve applies to enemies too (supersedes the Lufia-II stay-dead pattern; `defeated_enemy_ids` dropped from SaveData); (e) EncounterData/MapMeta built now as stubs, wired Phase 4; (f) minimal Continue/New Game boot prompt; dev warps expand to every built room via the map registry | Kayden's 2026-07-07 planning answers, verbatim rationale on the TASKBOARD Pending Decisions table; agent interpretations flagged there (full-HP respawn, suspended-room semantics, fall damage + XP penalty amounts as tunables) | 2026-07-07 / Phase 3 planning round |
| **Phase 4 (Combat MVP) starts ahead of Phase 3's save/load half**; Phase 3's M3.1 data classes move with it as combat prerequisites, and the M3.2/M3.3 save/load work stays planned and ready, resumed after combat | Kayden accepted Phase 2 in windowed play (2026-07-08) and named combat the priority: "my main complaint right now is combat, which is phase 4. So I think that is a good next place to work." A build-order re-sequencing, not a scope change - the D-006..D-011 save/load resolutions all stand; combat has no dependency on saves, but does need the M3.1 data classes (abilities, items, encounters, XP shape), which is why they ride along | 2026-07-08 / this session |
| ~~**Phase 4 D-012: copy local overworld terrain into the combat grid**~~ - **superseded by D-018 after the second 2026-07-10 windowed pass** | The original intent was biome/context fidelity, not literal wall-for-wall copying. Even after widening the board and clearing deployment lanes, copied forest topology produced an unfightable arena and gave Kayden no editable battle-map collection. | 2026-07-08; superseded 2026-07-10 / Kayden |
| **D-018 authored weighted battle arenas:** battle context filters a pool of editable LDtk templates by biome/tags; contact side orients deployment; a deterministic weighted shuffle bag selects among 2 `empty` templates (weight 5 each), 3 `mid` templates (weight 2 each), and 2 `hard` templates (weight 1 each), with no immediate repeat. Enemy number/strength varies independently. Boss encounters may pin a dedicated arena. Every arena imports to `TileMapLayer` and must pass deployment/connectivity validation. | Preserves the useful meaning of D-012 (a forest fight looks like a forest fight; a dry dungeon does not invent a river) while making every topology visible, editable, testable, and reliably fightable. The 5/2/1 tickets yield an initial approximately 56% empty / 33% mid / 11% hard mix and remain tunable. | 2026-07-10 / Kayden second T-069 pass |
| **Combat is a tactics-RPG, not a JRPG**: BG3's turn-based mode is the functional model (select a unit, move it within a highlighted range on a zoomed-in grid, act via abilities, strict per-unit initiative); Fire Emblem is the *visual* reference only (range highlighting, a dedicated battle mode). Active party size is **four**. The "quick decisions matter more than tactical depth" pillar is retired - the game leans into strategic, tactical combat | Kayden clarified the founding combat vision: "top down tactical BG3 style... control my party of 4 people around this new mini map." Fire Emblem was his closest GBA touchstone for the *look* (range highlights, separate mode), not the mechanics; the engine isn't as limited as first assumed, so depth is now in-scope. Reframes the JRPG/menu language and the earlier readable-over-deep pillar; the locked grid/d10/per-unit-initiative decisions are unchanged | 2026-07-08 / this session |
| **Phase 3 tuning round (D-014..D-017, resolved 2026-07-10; pit tuning superseded after playtest)**: defeat costs **25% of above-floor XP progress**; respawn at **80% of max HP**; pit falls now cost **10 HP party-wide** because the initial 10%-of-max implementation was too soft and incorrectly left Buddy untouched; **consumables come from every source** - enemy loot, chests, and later shops | Kayden's windowed pass superseded only D-016's first number. Because the overworld avatar represents the party, environmental damage now persists to every member and two early-game falls defeat a full-health Hero. | 2026-07-10 / Kayden |
| **D-019 keyboard/controller anchor, prompt policy revised:** E/A interact+confirm, Space/B traversal, Q/X cancel/back, F/Y character menu, Tab/Start broader menu, WASD/D-pad movement. Until controller glyphs are implemented, on-screen prompts show keyboard keys only rather than confusing slash-separated keyboard/controller text. | Preserves the 1:1 physical layout while keeping each prompt immediately readable. T-079 owns the later coherent controller-glyph pass. | 2026-07-10 / Kayden latest playthrough |
| **D-020 ally collision is intentional combat balance:** allied units occupy cells and cannot move through each other. | Kayden's repeated teammate blocking felt like meaningful positioning pressure. Arena safety prevents unavoidable spawn traps, but movement order and lane management remain part of combat. | 2026-07-10 / Kayden latest playthrough |
| **D-021 Item command must identify the item before use.** Phase 4 needs a minimal named item selection/confirmation surface; the full inventory/character-menu system remains Phase 5. | Pressing a generic Item command and consuming an unidentified item violates the Readable Tactical Combat pillar even if only one potion exists. | 2026-07-10 / Kayden latest playthrough |
| **D-022 manual jumping benched until a traversal item.** Current dungeon progression cannot require the standing facing-hop or a forward+jump timing chord. | The old implementation was mechanically understandable but visually and physically incoherent. A future Zelda-style item can reintroduce traversal under a clearer contract. | 2026-07-10 / Kayden latest playthrough |
| **D-023 first puzzle vocabulary:** latching on/off lever, momentary pressure plate, and pushable blocks. **Playtest clarification:** do not teach them all in one room. T-078's second room isolates the plate/block lesson on a pit-free continuous floor; latching levers can appear in a later dedicated room. | The first recut mixed two mechanisms with pit-like visual bands and obscured the lesson. The ALTTP reference works because stepping on/off the floor switch produces one immediately visible gate response before the block becomes the lasting weight. | 2026-07-10 / Kayden screenshot playtest |
| **D-024 v2 vision pivot (controlled reboot).** New organizing principle: one persistent world, one shared environmental vocabulary, a visible party of Dungeon Friends, and encounters that permanently resolve problems. New pillar set (see Design Pillars); docs-only canon reset first, then the T-089..T-095 pivot sequence; no v1 code deleted before its v2 replacement is verified | Kayden's research pass (Horizon's Gate, Into the Breach, deterministic tactics) plus a ChatGPT design review he endorsed. The unified model is more distinctive than "Zelda exploration + separate BG3 battle" and merges combat with the puzzle system instead of maintaining two rulesets | 2026-07-11 / Kayden pivot notes + review |
| **D-025 unified in-room encounters.** Combat happens in the current room using the same grid, camera vocabulary, and environmental state - no separate `CombatScene`, no arena selection, no zoom transition. Followers snap to valid cells and become tactical units when an encounter begins. **Supersedes D-012 and D-018 as the production combat path** (the seven authored arenas + stone hall are salvage: their layouts can become in-world authored encounter spaces), and retires the 2026-07-05 camera-zoom-transition decision | The Horizon's Gate lesson: one environment and one vocabulary make the world feel continuous and let terrain manipulation matter everywhere. The just-built arena lane was the thinnest layer of Phase 4; the math/data/turn infrastructure carries over | 2026-07-11 / Kayden pivot |
| **D-026 deterministic combat - no random hit rolls.** Attacks hit if the target remains in the affected cells; damage previews always match results; status durations and forced movement are exact; crits come from positioning/combinations. First-cut formula `damage = max(1, ability_power + attacker_stat - target_defense)` (numbers tunable; preview=result is the contract). **Supersedes the 2026-07-05 d10 percentage decision and the T-060 formula** | Elemental combinations and telegraphed intentions are only satisfying when results are dependable; none of the reference games use hit RNG. Removes a whole class of feel complaints ("the 70% missed twice") before a commercial audience sees it | 2026-07-11 / Kayden pivot |
| **D-027 telegraphed intent rounds - RESOLVED.** Enemies move or declare; the player sees every current target/effect; party members act in any order; enemy actions resolve; environmental reactions resolve. Enemies keep a trustworthy rolling verb forecast (prototype default: 3): ordinary refills preserve already-shown verbs, invalid plans rebuild from the new state, future steps reveal verb only, and the current action reveals exact cells/damage/status. Moving/blocking/stunning/freezing/pushing/obscuring can change or cancel it. Alternating per-unit initiative is retired as the v2 production direction | Kayden's played T-092 verdict confirmed the intended structure and restated the exact deterministic/telegraph contract. Stable future verbs reward planning while invalidation-driven replans keep enemies responsive without leaking targets | 2026-07-11 / Kayden T-092 verdict |
| **D-028 persistent encounter resolution.** Resolved encounters stay resolved; defeated enemies do not return; the world change (route, relationship, resource) persists. `SaveData` gains resolved-encounter IDs and persistent environmental state. Progression economy: finite authored XP, ability unlocks via recruitment/story, equipment via treasure/craft/shops; no grind. **Supersedes D-009** (always-respawn) and reverses its `no defeated_enemy_ids` schema rule; D-008's defeat/XP-penalty flow needs a follow-up review against finite XP (flagged, not yet redesigned) | "Combat should resolve the issue" is a founding note of the pivot; respawning enemies made combat a toll, not a resolution. The soft-lock escape valve D-009 provided must be re-provided by puzzle-state reset alone, which T-091 (persistence proof) must prove | 2026-07-11 / Kayden pivot |
| **D-029 whole active party visible in exploration.** Leader directly controlled; others follow breadcrumb/loose formation; followers never block the leader or puzzle objects outside encounters; leader switchable for dialogue/field verbs; field abilities via a quick wheel/party bar. **Supersedes D-005** (single avatar) and un-retires the party-visible idea the old Gameplan §10 snake-follow gestured at, with better collision rules | The party fantasy is core to the collection appeal; one avatar representing four friends undercut it. Non-blocking followers avoid the corridor-wedging that killed snake-follow | 2026-07-11 / Kayden pivot |
| **D-030 three-quarter perspective on the orthogonal grid.** Keep the square logic grid, `TileMapLayer`, `AStarGrid2D`, and grid-snapped Tween movement; render in 3/4 with vertical wall faces; add small integer cell elevation with ramps/stairs; Manhattan movement preserved; high-ground/LoS bonuses deferred until basic elevation feels good. **No true diamond-isometric rendering.** Narrows, does not break, the flexible HD/ultrawide rendering decision; supersedes the "clean top-down camera" visual-language row | Horizon's Gate itself fakes height this way. True isometric would rework level authoring, movement, art, collision, and pathfinding for little near-term gameplay return; elevation-as-integer gets the height readability at art-pass cost | 2026-07-11 / Kayden pivot (perspective fork: "Faked 3/4, flat grid") |
| **D-031 shared material/effect vocabulary.** One tag-driven material-and-effect system (see V2 Systems table) powers exploration, puzzles, and combat; friends apply effects, world reacts by tags; **never bespoke pairwise friend-interaction code**. Promotes the old S-002 (elemental) and S-004 (overworld abilities) stretch goals into the core loop | The scope-explosion guardrail for "lots of friends": a new friend is a sprite + stat block + verb reference, not a new mechanic. Also the riskiest assumption of the pivot - T-093 proves it is fun before roster/world scale-up | 2026-07-11 / Kayden pivot |
| **D-032 Steam-first commercial; mobile postponed.** Publishing on Steam is the goal; Google Play is reconsidered after the PC game proves itself. Supersedes the "not commercial" non-goal and the Android-early platform stance (M0.3/T-002 export work and B-21 touch input stay deferred; keystore rules unchanged). Near-term effect: controller glyphs (T-079 shipped) and UI coherence are launch requirements, not polish | Kayden: the audience is no longer "me and my friends" - "this is gonna be published on Steam or maybe Google Play one day." PC-first keeps the input/UI surface small while the design is still moving | 2026-07-11 / Kayden pivot |
| **D-033 roster targets and friend template.** Thesis prototype: Hero + 2 real friends. Steam demo/vertical slice: 5-6 recruitable, active party of 4. Full game: ~10-12 excellent friends before considering more. Each friend = one primary world verb + small deterministic combat kit + one passive/reaction + one personality hook/recruitment story + one meaningful verb interaction with another friend. Critical path never requires predicting the roster hours ahead (shrine/camp swapping, multi-solution puzzles, roster-specific puzzles optional-only, hero baseline toolset, telegraphed requirements). **Supersedes D-013's temporary-companion contract** - the first real recruit arrives with the thesis slice (T-094) | The Pokemon feel comes from discovery, anticipation, and choosing 4 from a roster - not from hundreds of characters. Kayden himself flagged the many-friends scope creep; the verb system plus this cap is the answer | 2026-07-11 / Kayden pivot (roster fork: "10-12 friends") |
| **D-034 encounters beyond combat; auto-resolve later.** An `Encounter`'s resolution may be defeat, delivery, escort, environmental manipulation, satisfying/persuading/intimidating/assisting an NPC, or discovering an alternate route - one resolution framework, no separate dialogue-RPG ruleset. Combat is avoidable by design. Auto-resolve unlocks only when the party clearly outclasses an optional encounter or has mastered that enemy family | "Encounters are mainly combat but not only combat" is Kayden's founding pivot note; finite encounters make indiscriminate auto-resolve an economy leak, so it is gated, not general | 2026-07-11 / Kayden pivot |
| **D-035 story spine: the dragon expedition.** A dragon lands on the mountain overlooking the city; the goddess Selena chooses the protagonist to unite incompatible people and powers; each region carries a local consequence of the dragon's presence whose solution reveals or recruits a Dungeon Friend; distrustful friends learn to combine verbs; the mountain route is the final exam of the environmental vocabulary. Dragon visible/foreshadowed from very early; the city leans toward hub status. **Supersedes the 2026-07-09 four-legendary-items spine**; regional geography survives. `docs/WORLD_LORE.md` realignment is follow-up work | Assembling the expedition is a stronger structure than four item errands, and it makes party-building the story itself. The existing forest -> river valley -> mountain -> city -> lair region plan needed almost no change | 2026-07-11 / Kayden pivot |
| **D-036 encounter-mode cue inside the continuous room.** Detection/contact immediately gates exploration input, then a short original audio/visual stinger and turn-based UI announce the encounter before the first player action. The room, camera, positions, puzzle state, and rules do not swap. **Clarifies D-025:** continuous means one world/ruleset, not an imperceptible transition | Fable's spike felt too seamless: combat appeared without the BG3-like “you entered turn-based mode” beat Kayden expected. A local cue gives the state change weight without rebuilding the retired arena/scene split | 2026-07-11 / Kayden consolidation playtest |
| **D-038 owner-approval consolidation: agents build to the thesis slice without intermediate verdicts.** The intermediate owner gates inside the production chain (S-010 formation feel, S-011 production-vocabulary replay, S-012 combat feel and v1 retirement, S-013 progression fork and balance, S-014 opening journey) are delegated: agents make the flagged product calls per this Blueprint's recorded canon, capture the same demo artifacts, and proceed. All owner acceptance batches into one playthrough at the S-004 thesis-slice replay (TK-004). S-005 external playtest and S-015 release approval remain human gates, and any change that would contradict a Locked Technical Decision still stops for Kayden first. | Kayden 2026-07-19: the intermediate approval gates were self-imposed process, not product need - "you dont need my approval until the end. that is why we have the blueprint." One consolidated review of the finished vertical iteration replaces five mid-chain sign-offs; demo artifacts still accumulate per ticket so that batch review stays under a minute per capability. | 2026-07-19 / Kayden chat directive |
| **D-039 (flagged per D-038) world-authoring contract for the unified runtime.** Rooms author v2 world state in LDtk beside the existing Wall/Pit layers: an optional `Elevation` IntGrid layer (values declared ascending from 1; integer cell elevation per D-030, capped at 8) and an optional `Material` IntGrid layer whose values are declared in the fixed order vine, flammable, channel, smoke - the authorable *initial* subset of the D-031 reaction vocabulary (transient states like wet/fire/ice are never authored). Every overworld Enemy carries a stable encounter identity: its authored `UniqueId`, else a deterministic authored-cell id (`enc_x_y`). Invalid authored data fails closed - the room records named `authoring_errors`, the WorldState adapter refuses the snapshot, and the v1 route keeps running. Rooms without the new layers snapshot at elevation 0 with no tags: no invented data. | S-009/TK-002 needed one authoring path for elevation, materials, and encounter identity before S-010..S-012 and S-003 consume the seam. IntGrid painting matches the existing D-002 all-in-LDtk pipeline; deriving stable ids from authored data (not runtime order) is what lets resolved encounters stay resolved (D-028) across rebuilds and saves. Agent product call under D-038; batch review lands at S-004. | 2026-07-19 / S-009 TK-002 (claude-engineer, flagged) |
| **D-040 (flagged per D-038) the production exploration party is the live roster, not a fixed four.** The visible pass-through party (D-029) graduates to production sized by `party_roster` - today Hero (leader) + Buddy - and grows to four as friends are recruited (D-035's expedition is the recruitment arc; S-014 owns the opening roster). Followers are render-only breadcrumb actors (never occupancy, plates, or pushes); the world snapshot keys party actors by roster ids with deterministic distinct cells. Formation selection (line/square/spaced) stays owned by S-010. | Spawning four visible members before the story recruits them would invent content and contradict the D-013 Hero+Buddy production pair; roster-driven sizing keeps the seam correct at any party size, so the S-010 formation work and S-014 roster growth land without rewiring. Agent product call under D-038; batch review at S-004. | 2026-07-19 / S-009 TK-003 (claude-engineer, flagged) |
| **D-041 (flagged per D-038) interim party controls: F/Y switches the leader, G/L1 cycles formations.** The D-019 `character_menu` action (F keyboard, Y controller) triggers leader switching until the real Phase-5 character menu exists - matching the accepted T-096 dev-spike control - and a new `formation_cycle` action (G keyboard, L1 controller) cycles line -> square -> spaced with a transient confirmation toast as the smallest production selector. Formation identity persists in session state and saves (older saves default to line); leader authority persists for the session only. | S-010/TK-003 needed a player-reachable control surface without inventing menu UI ahead of Phase 5; riding the reserved character action keeps the D-019 physical layout intact, and the toast keeps selection readable without permanent HUD chrome. Agent product call under D-038; feel verdict batches at the S-004 replay. | 2026-07-19 / S-010 TK-003 (claude-engineer, flagged) |
| **D-042 (flagged per D-038) staged v1 combat retirement: unified in-room intent combat is the production default.** `SceneManager.unified_encounters` now defaults true: bumping an enemy enters the D-025/D-036 in-room encounter (deployment, exact intents, verbs-only forecast, any-order party actions, environment ticks, in-place victory/defeat with HP write-back and the v1 reward/defeat rules). The v1 d10/arena/zoom route stays code-reachable behind the flag - the slice smoke test pins it false as the living v1-fallback proof - and fully git-recoverable; physical deletion of CombatScene/arena/zoom code waits for the S-004 owner replay verdict (TK-006). Dev skip-combat now short-circuits before the seam so the overlay toggle works on both routes. | S-012 TK-001..TK-004 replaced every v1 combat responsibility with tested v2 equivalents; keeping the old route as default would contradict accepted canon while the new route is the thing S-004 must judge. Staged (flag + git) retirement honors "no v1 code deleted before its v2 replacement is verified". Agent product call under D-038. | 2026-07-19 / S-012 TK-004 (claude-engineer, flagged) |
| **D-037 selectable party formation plus tactical combat occupancy.** Exploration followers remain visible but pass-through/non-interacting. The player selects a preferred line, square, or spaced posture; chokes compress temporarily and the party reforms afterward. Encounter start deterministically deploys toward that posture on legal reachable cells, then all allies occupy cells and body-block normally. Directional protection/guarded cells are a valid combat tactic; exact friend kits remain future content | Both four-follower demos felt good, especially Fable's pass-through leader movement. Kayden wants spacing to be chosen deliberately so ally collision creates positioning tactics rather than accidental congestion; the shield-vs-breath example is the first acceptance case, not a locked roster ability | 2026-07-11 / Kayden consolidation playtest |

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

Verification commands live in `RUNBOOK.md`. Hot execution state projects into
`TASKBOARD.md`; durable status and proof live in the linked stable specs.
